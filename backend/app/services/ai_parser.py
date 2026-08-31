"""
NLU Parser — Chaîne de fallback automatique

Ordre de priorité :
  1. Groq LLaMA 3.1-8b  (si GROQ_API_KEY)    — cloud, gratuit, ultra-rapide (~300ms)
  2. Google Gemini Flash (si GOOGLE_API_KEY)   — cloud, gratuit, 15 RPM
  3. OpenAI GPT-3.5     (si OPENAI_API_KEY)   — cloud, si crédits disponibles
  4. Regex rule-based                          — local, toujours disponible
"""

import re
import os
import json
import logging
from typing import Optional, Dict, Any

from app.schemas.domain import TransactionCreate
from app.models.domain import TransactionType

logger = logging.getLogger("backend.ai")

# ---------------------------------------------------------------------------
# Prompt partagé par tous les LLM
# ---------------------------------------------------------------------------
_SYSTEM_PROMPT = (
    "Tu es un assistant qui extrait des informations de transactions commerciales "
    "depuis des phrases en français (contexte : commerce informel sénégalais). "
    "Retourne UNIQUEMENT un objet JSON valide, sans aucun autre texte."
)

_USER_PROMPT_TEMPLATE = (
    'Extrais un JSON depuis cette phrase de commerçant :\n'
    'Champs :\n'
    '- type: "SALE" | "PURCHASE" | "EXPENSE"\n'
    '- amount: nombre (montant TOTAL de la transaction en FCFA, pas le prix unitaire)\n'
    '- description: texte original\n'
    '- product_name: string ou null (nom du produit seulement, sans quantité)\n'
    '- quantity: nombre ou null (quantité vendue/achetée)\n'
    '- client_name: string ou null (prénom du client si mentionné)\n\n'
    'IMPORTANT: amount = prix_unitaire × quantité (ex: "3 Coca à 500 FCFA" → amount=1500, quantity=3)\n'
    'Phrase : "{text}"\n'
    'Réponds UNIQUEMENT avec le JSON.'
)


def _normalize_llm_result(j: dict, txt: str) -> Dict[str, Any]:
    """Normalise un résultat JSON brut d'un LLM vers le format interne."""
    if "type" in j and isinstance(j["type"], str):
        j["type"] = j["type"].upper()
    if j.get("type") not in ("SALE", "PURCHASE", "EXPENSE"):
        j["type"] = "SALE"
    if "amount" in j and j["amount"] is not None:
        try:
            j["amount"] = float(j["amount"])
        except Exception:
            j["amount"] = 0.0
    if "quantity" in j and j["quantity"] is not None:
        try:
            j["quantity"] = float(j["quantity"])
        except Exception:
            j["quantity"] = None
    return {
        "type": j.get("type", "SALE"),
        "amount": j.get("amount", 0.0),
        "description": j.get("description", txt),
        "product_id": None,
        "quantity": j.get("quantity"),
        "client_id": None,
        "_guessed_product_name": j.get("product_name") or None,
        "_guessed_client_name": j.get("client_name") or None,
        "_source": j.get("_source", "llm"),
    }


def _extract_json_from_text(content: str) -> Optional[dict]:
    """Extrait le premier objet JSON trouvé dans un texte."""
    m = re.search(r"\{[\s\S]*\}", content)
    if m:
        try:
            return json.loads(m.group(0))
        except Exception:
            return None
    return None


def _is_quota_error(msg: str) -> bool:
    return any(k in msg for k in [
        "quota", "insufficient_quota", "credit_balance_exhausted",
        "billing", "exceeded", "rate_limit_exceeded",
    ])


# ---------------------------------------------------------------------------
# Fallback 1 — Groq LLaMA 3.1-8b-instant (cloud, gratuit, ultra-rapide)
# ---------------------------------------------------------------------------

def _try_groq_llm(text: str) -> Optional[Dict[str, Any]]:
    api_key = os.getenv("GROQ_API_KEY")
    if not api_key:
        return None
    try:
        from groq import Groq
        client = Groq(api_key=api_key)
        candidate_models = [os.getenv("GROQ_MODEL", "groq/compound-mini"), "llama-3.1-8b-instant"]
        # Dédupliquer tout en préservant l'ordre
        models_to_try = list(dict.fromkeys(candidate_models))
        
        last_error = None
        for model in models_to_try:
            try:
                resp = client.chat.completions.create(
                    model=model,
                    messages=[
                        {"role": "system", "content": _SYSTEM_PROMPT},
                        {"role": "user", "content": _USER_PROMPT_TEMPLATE.format(text=text)},
                    ],
                    max_tokens=300,
                    temperature=0.0,
                )
                content = resp.choices[0].message.content
                j = _extract_json_from_text(content)
                if j:
                    j["_source"] = f"groq-{model}"
                    result = _normalize_llm_result(j, text)
                    logger.info("[NLU] ✓ Groq (%s) — type=%s amount=%s product=%s",
                                model, result["type"], result["amount"], result["_guessed_product_name"])
                    return result
            except Exception as ex:
                last_error = ex
                if _is_quota_error(str(ex).lower()):
                    logger.warning("[NLU] Groq quota/rate-limit sur %s : %s", model, ex)
                    break
                continue
        if last_error:
            logger.warning("[NLU] Groq indisponible (%s), passage au fallback suivant", last_error)
    except Exception as e:
        logger.warning("[NLU] Erreur Groq globale (%s), passage au fallback suivant", e)
    return None


# ---------------------------------------------------------------------------
# Fallback 2 — Google Gemini Flash (cloud, gratuit)
# ---------------------------------------------------------------------------

def _try_gemini_llm(text: str) -> Optional[Dict[str, Any]]:
    api_key = os.getenv("GOOGLE_API_KEY")
    if not api_key:
        return None
    try:
        # Nouveau SDK google-genai (l'ancien google-generativeai est déprécié)
        try:
            from google import genai
            client = genai.Client(api_key=api_key)
            prompt = f"{_SYSTEM_PROMPT}\n\n{_USER_PROMPT_TEMPLATE.format(text=text)}"
            resp = client.models.generate_content(
                model="gemini-flash-lite-latest",
                contents=prompt,
            )
            content = resp.text
        except ImportError:
            # Fallback sur l'ancien SDK si nouveau non dispo
            import google.generativeai as genai  # noqa
            genai.configure(api_key=api_key)
            model = genai.GenerativeModel("gemini-1.5-flash")
            prompt = f"{_SYSTEM_PROMPT}\n\n{_USER_PROMPT_TEMPLATE.format(text=text)}"
            resp = model.generate_content(prompt)
            content = resp.text

        j = _extract_json_from_text(content)
        if j:
            j["_source"] = "gemini-flash"
            result = _normalize_llm_result(j, text)
            logger.info("[NLU] ✓ Gemini Flash — type=%s amount=%s product=%s",
                        result["type"], result["amount"], result["_guessed_product_name"])
            return result
    except Exception as e:
        msg = str(e).lower()
        if _is_quota_error(msg):
            logger.warning("[NLU] Gemini quota/rate-limit : %s", e)
        else:
            logger.warning("[NLU] Gemini indisponible (%s), passage au fallback suivant", e)
    return None


# ---------------------------------------------------------------------------
# Fallback 3 — OpenAI GPT-3.5 (cloud, si crédits disponibles)
# ---------------------------------------------------------------------------

def _try_openai_llm(text: str) -> Optional[Dict[str, Any]]:
    api_key = os.getenv("OPENAI_API_KEY")
    if not api_key:
        return None
    try:
        from openai import OpenAI
        client = OpenAI(api_key=api_key)
        resp = client.chat.completions.create(
            model="gpt-3.5-turbo",
            messages=[
                {"role": "system", "content": _SYSTEM_PROMPT},
                {"role": "user", "content": _USER_PROMPT_TEMPLATE.format(text=text)},
            ],
            max_tokens=300,
            temperature=0.0,
        )
        content = resp.choices[0].message.content
        j = _extract_json_from_text(content)
        if j:
            j["_source"] = "openai-gpt"
            result = _normalize_llm_result(j, text)
            logger.info("[NLU] ✓ OpenAI GPT — type=%s amount=%s product=%s",
                        result["type"], result["amount"], result["_guessed_product_name"])
            return result
    except Exception as e:
        msg = str(e).lower()
        if _is_quota_error(msg):
            logger.warning("[NLU] OpenAI quota épuisé : %s", e)
        else:
            logger.warning("[NLU] OpenAI GPT indisponible (%s), passage au fallback suivant", e)
    return None


# ---------------------------------------------------------------------------
# Fallback 4 — Regex rule-based (local, toujours disponible)
# ---------------------------------------------------------------------------

def _parse_amount(text: str) -> Optional[float]:
    matches = re.findall(r"(\d[\d\s,.]*)[\s]*(?:fcfa|cfa|xof|francs|f)?", text, flags=re.IGNORECASE)
    if not matches:
        return None
    candidate = max(matches, key=len)
    numeric = re.sub(r"[\s,]", "", candidate)
    numeric = numeric.replace(".", "") if numeric.count('.') > 1 else numeric.replace(',', '.')
    try:
        return float(numeric)
    except Exception:
        return None


def _parse_quantity(text: str) -> Optional[float]:
    m = re.search(
        r"(\d+(?:[.,]\d+)?)\s*(?:bouteilles?|sacs?|kg|kilos|litres?|unit(?:és|es)?|pcs|pièces?)",
        text, flags=re.IGNORECASE
    )
    if m:
        try:
            return float(m.group(1).replace(',', '.'))
        except Exception:
            return None
    nums = re.findall(r"\d+(?:[.,]\d+)?", text)
    if len(nums) >= 2:
        try:
            return float(nums[0].replace(',', '.'))
        except Exception:
            return None
    return None


def _parse_type(text: str) -> TransactionType:
    t = text.lower()
    if any(k in t for k in ["vend", "vente", "vendre", "sold"]):
        return TransactionType.SALE
    if any(k in t for k in ["achete", "achat", "acheter", "purchase"]):
        return TransactionType.PURCHASE
    if any(k in t for k in ["depens", "dépens", "depenser", "dépense", "expense"]):
        return TransactionType.EXPENSE
    return TransactionType.SALE


def _parse_product_name(text: str) -> Optional[str]:
    m = re.search(
        r"vend(?:u|e|es)?(?:.*?)(?:\d+[\d\s,.]*)?[\s]+([.\w\s'\-éèêàùîôûç]+?)[\s]+(?:à|au|chez|pour)",
        text, flags=re.IGNORECASE
    )
    if m:
        name = m.group(1).strip()
        name = re.sub(r"\b(bouteilles?|sacs?|kg|kilos|litres?|unit(?:és|es)?|pcs|pièces?)\b",
                      "", name, flags=re.IGNORECASE).strip()
        return name[:120] if name else None
    m2 = re.search(
        r"(\d+)\s+([\w\s'\-éèêàùîôûç]+?)\s*(?:à|au|chez|pour)\s*(?:\d|fcfa|cfa)",
        text, flags=re.IGNORECASE
    )
    if m2:
        return m2.group(2).strip()
    return None


def _regex_fallback(text: str) -> Dict[str, Any]:
    txn_type = _parse_type(text)
    amount = _parse_amount(text) or 0.0
    quantity = _parse_quantity(text)
    product_name = _parse_product_name(text)
    logger.info("[NLU] ✓ Regex fallback — type=%s amount=%s product=%s",
                txn_type.value, amount, product_name)
    return {
        "type": txn_type.value,
        "amount": float(amount),
        "description": text,
        "product_id": None,
        "quantity": quantity,
        "client_id": None,
        "_guessed_product_name": product_name,
        "_guessed_client_name": None,
        "_source": "regex",
    }


# ---------------------------------------------------------------------------
# Point d'entrée principal
# ---------------------------------------------------------------------------

def parse_text_to_transaction(text: str) -> Dict[str, Any]:
    """
    Convertit une phrase en langage naturel en un dict TransactionCreate.
    Chaîne : Groq LLaMA → Gemini Flash → OpenAI GPT → Regex
    """
    txt = text.strip()
    logger.info("[NLU] Parsing : %s", txt[:100])

    # 1. Groq LLaMA 3.1 (priorité 1 — gratuit, ultra-rapide)
    result = _try_groq_llm(txt)
    if result:
        return result

    # 2. Google Gemini Flash (priorité 2 — gratuit)
    result = _try_gemini_llm(txt)
    if result:
        return result

    # 3. OpenAI GPT-3.5 (priorité 3 — si crédits disponibles)
    result = _try_openai_llm(txt)
    if result:
        return result

    # 4. Regex rule-based (toujours disponible)
    return _regex_fallback(txt)


# ---------------------------------------------------------------------------
# Conversion Pydantic
# ---------------------------------------------------------------------------

def parse_text_to_transaction_model(text: str) -> TransactionCreate:
    parsed = parse_text_to_transaction(text)
    return TransactionCreate(
        type=TransactionType(parsed["type"]),
        amount=parsed["amount"],
        description=parsed.get("description"),
        product_id=None,
        quantity=parsed.get("quantity"),
        client_id=None,
    )
