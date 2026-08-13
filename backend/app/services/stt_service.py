"""
STT Service — Chaîne de fallback automatique

Ordre de priorité :
  1. Mock      (si OPENAI_TRANSCRIPTION_MOCK=1)  — développement uniquement
  2. Groq      (si GROQ_API_KEY défini)           — cloud, gratuit, ultra-rapide
  3. OpenAI    (si OPENAI_API_KEY défini)          — cloud, si crédits disponibles
  4. faster-whisper (local)                        — toujours disponible, hors-ligne
"""

import os
import logging
import time
import random
from fastapi import HTTPException

logger = logging.getLogger("backend.stt")


# ---------------------------------------------------------------------------
# Utilitaires
# ---------------------------------------------------------------------------

def _parse_retry_after_from_exception(exc) -> float | None:
    try:
        resp = getattr(exc, "response", None) or getattr(exc, "_response", None)
        if resp is not None:
            headers = getattr(resp, "headers", None)
            if headers:
                ra = headers.get("retry-after") or headers.get("Retry-After")
                if ra:
                    try:
                        return float(ra)
                    except Exception:
                        return None
    except Exception:
        pass
    import re
    msg = str(exc)
    if "Retry-After" in msg:
        m = re.search(r"Retry-After\D*(\d+)", msg)
        if m:
            try:
                return float(m.group(1))
            except Exception:
                return None
    return None


def _is_quota_error(msg: str) -> bool:
    """Détecte les erreurs de quota/billing (pas la peine de retenter)."""
    return any(k in msg for k in [
        "credit_balance_exhausted",
        "insufficient_quota",
        "you exceeded your current quota",
        "quota exhausted",
        "billing",
    ])


# ---------------------------------------------------------------------------
# Fallback 1 — Groq Whisper (cloud, gratuit, ultra-rapide)
# ---------------------------------------------------------------------------

def _try_groq_whisper(path: str) -> str | None:
    """
    Tente la transcription via l'API Groq (whisper-large-v3-turbo).
    Retourne le texte transcrit ou None si indisponible/erreur.
    """
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        return None

    try:
        from groq import Groq
        client = Groq(api_key=api_key)
        with open(path, "rb") as f:
            resp = client.audio.transcriptions.create(
                file=(os.path.basename(path), f),
                model="whisper-large-v3-turbo",
                language="fr",
                response_format="text",
            )
        # resp est directement le texte (response_format="text")
        text = resp if isinstance(resp, str) else getattr(resp, "text", str(resp))
        logger.info("[STT] ✓ Groq Whisper — texte: %s", text[:80])
        return text.strip()
    except Exception as e:
        msg = str(e).lower()
        if _is_quota_error(msg):
            logger.warning("[STT] Groq quota épuisé : %s", e)
        else:
            logger.warning("[STT] Groq indisponible (%s), passage au fallback suivant", e)
        return None


# ---------------------------------------------------------------------------
# Fallback 2 — OpenAI Whisper (cloud, si crédits disponibles)
# ---------------------------------------------------------------------------

def _try_openai_whisper(path: str) -> str | None:
    """
    Tente la transcription via l'API OpenAI Whisper-1.
    Retourne le texte ou None si erreur/quota épuisé.
    """
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None

    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)
        with open(path, "rb") as f:
            resp = client.audio.transcriptions.create(model="whisper-1", file=f)
        text = getattr(resp, "text", None) or (resp.get("text") if isinstance(resp, dict) else None)
        logger.info("[STT] ✓ OpenAI Whisper — texte: %s", (text or "")[:80])
        return (text or "").strip()
    except Exception as e:
        msg = str(e).lower()
        if _is_quota_error(msg):
            logger.warning("[STT] OpenAI quota épuisé : %s", e)
        else:
            logger.warning("[STT] OpenAI Whisper indisponible (%s), passage au fallback suivant", e)
        return None


# ---------------------------------------------------------------------------
# Fallback 3 — faster-whisper (local, hors-ligne, toujours disponible)
# ---------------------------------------------------------------------------

_faster_whisper_model = None  # cache du modèle chargé

def _try_faster_whisper(path: str) -> str | None:
    """
    Tente la transcription via faster-whisper en local (modèle 'small').
    Télécharge le modèle au premier appel (~250 MB), puis le met en cache.
    """
    global _faster_whisper_model
    try:
        from faster_whisper import WhisperModel
        if _faster_whisper_model is None:
            logger.info("[STT] Chargement du modèle faster-whisper 'small' (premier appel)...")
            _faster_whisper_model = WhisperModel("small", device="cpu", compute_type="int8")
            logger.info("[STT] Modèle faster-whisper chargé.")

        segments, info = _faster_whisper_model.transcribe(path, language="fr")
        text = " ".join(seg.text.strip() for seg in segments)
        logger.info("[STT] ✓ faster-whisper local — lang=%s texte: %s", info.language, text[:80])
        return text.strip()
    except ImportError:
        logger.warning("[STT] faster-whisper non installé (pip install faster-whisper)")
        return None
    except Exception as e:
        logger.error("[STT] faster-whisper erreur locale : %s", e)
        return None


# ---------------------------------------------------------------------------
# Point d'entrée principal avec chaîne de fallback
# ---------------------------------------------------------------------------

def transcribe_audio_file(path: str) -> str:
    """
    Transcrit un fichier audio en texte via la chaîne de fallback :
      Mock → Groq Whisper → OpenAI Whisper → faster-whisper (local)

    Lève HTTPException 503 si aucune méthode ne fonctionne.
    """
    # 0. Mode mock (développement / tests sans API)
    mock_mode = str(os.getenv("OPENAI_TRANSCRIPTION_MOCK", "")).lower() in ("1", "true", "yes")
    if mock_mode:
        logger.warning("[STT] Mode mock actif — transcription fictive pour %s", path)
        return f"[MOCK] J'ai vendu 3 Coca-Cola à 1500 FCFA"

    logger.info("[STT] Démarrage de la chaîne de fallback pour %s", os.path.basename(path))

    # 1. Groq Whisper (priorité 1 — gratuit, ultra-rapide)
    result = _try_groq_whisper(path)
    if result:
        return result

    # 2. OpenAI Whisper (priorité 2 — si crédits disponibles)
    result = _try_openai_whisper(path)
    if result:
        return result

    # 3. faster-whisper local (priorité 3 — hors-ligne, toujours disponible)
    result = _try_faster_whisper(path)
    if result:
        return result

    # Toutes les méthodes ont échoué
    logger.error("[STT] ❌ Toutes les méthodes de transcription ont échoué pour %s", path)
    raise HTTPException(
        status_code=503,
        detail=(
            "Service de transcription indisponible. "
            "Vérifiez GROQ_API_KEY ou OPENAI_API_KEY dans le .env, "
            "ou installez faster-whisper pour le mode hors-ligne."
        ),
    )
