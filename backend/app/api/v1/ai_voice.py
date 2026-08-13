import os
import shutil
import tempfile
import logging
from fastapi import APIRouter, Depends, HTTPException, UploadFile, File, status
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.domain import Transaction, Product, Client, TransactionType, User
from app.schemas.ai_payload import TextActionPayload
from app.services.ai_parser import parse_text_to_transaction
from app.services.stt_service import transcribe_audio_file
from app.api.v1.auth import get_current_user

logger = logging.getLogger("backend.ai")
router = APIRouter(prefix="/ai", tags=["Intelligence Artificielle"])

def process_parsed_action(parsed: dict, db: Session, user_id: int):
    product_id = None
    guessed_product_name = parsed.get("_guessed_product_name")
    quantity = parsed.get("quantity")
    amount = parsed.get("amount") or 0.0
    txn_type = parsed.get("type")

    # 1. Résolution du Produit avec fuzzy matching multi-passes
    if guessed_product_name:
        import re

        # Nettoyage : enlever chiffres/unités en début de chaîne
        cleaned_name = re.sub(
            r"^\d+\s*(?:bouteilles?|sacs?|kg|kilos|litres?|unit(?:\u00e9s|es)?|pcs|pi[e\u00e8]ces?)?\s*(?:de|d')?\s*",
            "", guessed_product_name, flags=re.IGNORECASE
        ).strip()

        product = None

        # Passe 1 : correspondance directe ilike sur le nom nettoyé complet
        if cleaned_name:
            product = db.query(Product).filter(
                Product.user_id == user_id,
                Product.name.ilike(f"%{cleaned_name}%")
            ).first()

        # Passe 2 : chaque mot significatif (>= 4 lettres) du nom transcrit
        if not product and cleaned_name:
            mots = [m for m in re.split(r"\s+", cleaned_name) if len(m) >= 4]
            for mot in mots:
                product = db.query(Product).filter(
                    Product.user_id == user_id,
                    Product.name.ilike(f"%{mot}%")
                ).first()
                if product:
                    logger.info("[AI] Fuzzy passe-2 : '%s' -> '%s'", mot, product.name)
                    break

        # Passe 3 : chaque mot du nom produit en base contre la transcription
        if not product:
            all_products = db.query(Product).filter(Product.user_id == user_id).all()
            transcription_lower = guessed_product_name.lower()
            for p in all_products:
                mots_produit = [m for m in re.split(r"\s+", p.name.lower()) if len(m) >= 4]
                if any(m in transcription_lower for m in mots_produit):
                    product = p
                    logger.info("[AI] Fuzzy passe-3 : '%s' matche '%s'",
                                transcription_lower, p.name)
                    break

        if product:
            product_id = product.id
        else:
            if txn_type == TransactionType.PURCHASE.value:
                # Création automatique du produit pour un achat
                estimated_unit_price = (amount / quantity) if quantity and quantity > 0 else 0.0
                product = Product(
                    user_id=user_id,
                    name=cleaned_name or guessed_product_name,
                    quantity=0.0,
                    unit_price=round(estimated_unit_price * 1.3, 0),
                    cost_price=estimated_unit_price,
                    min_stock_alert=5.0
                )
                db.add(product)
                db.commit()
                db.refresh(product)
                product_id = product.id
                logger.info("[AI] Nouveau produit cree automatiquement : '%s'", product.name)
            else:
                # SALE/EXPENSE : transaction enregistree sans product_id (pas de 400)
                logger.warning(
                    "[AI] Produit '%s' introuvable — transaction sans product_id",
                    guessed_product_name
                )
                product_id = None

    # 2. Résolution du Client
    client_id = None
    guessed_client_name = parsed.get("_guessed_client_name")
    if guessed_client_name:
        client = db.query(Client).filter(
            Client.user_id == user_id,
            Client.name.ilike(f"%{guessed_client_name}%")
        ).first()

        if client:
            client_id = client.id
        else:
            # Création automatique du client débiteur
            client = Client(
                user_id=user_id,
                name=guessed_client_name,
                debt_amount=0.0
            )
            db.add(client)
            db.commit()
            db.refresh(client)
            client_id = client.id

    # 3. Règles métiers de mise à jour des stocks
    if txn_type == TransactionType.SALE.value and product_id and quantity:
        product = db.query(Product).filter(Product.id == product_id).first()
        if product:
            if product.quantity < quantity:
                raise HTTPException(
                    status_code=status.HTTP_400_BAD_REQUEST,
                    detail=f"Stock insuffisant pour '{product.name}' ! Stock disponible: {product.quantity}"
                )
            product.quantity -= quantity

    elif txn_type == TransactionType.PURCHASE.value and product_id and quantity:
        product = db.query(Product).filter(Product.id == product_id).first()
        if product:
            product.quantity += quantity

    # 4. Règles métiers de mise à jour de la dette client (uniquement pour les ventes)
    if client_id and txn_type == TransactionType.SALE.value:
        client = db.query(Client).filter(Client.id == client_id).first()
        if client:
            client.debt_amount += amount

    # 5. Sauvegarde de la transaction finale
    db_txn = Transaction(
        user_id=user_id,
        type=TransactionType(txn_type),
        amount=amount,
        description=parsed.get("description"),
        product_id=product_id,
        quantity=quantity,
        client_id=client_id
    )
    db.add(db_txn)
    db.commit()
    db.refresh(db_txn)

    # Récupérer les entités rafraîchies pour la réponse
    resolved_product = db.query(Product).filter(Product.id == product_id).first() if product_id else None
    resolved_client = db.query(Client).filter(Client.id == client_id).first() if client_id else None

    return {
        "id": db_txn.id,
        "user_id": db_txn.user_id,
        "type": db_txn.type.value,
        "amount": db_txn.amount,
        "description": db_txn.description,
        "product_id": db_txn.product_id,
        "product_name": resolved_product.name if resolved_product else None,
        "quantity": db_txn.quantity,
        "client_id": db_txn.client_id,
        "client_name": resolved_client.name if resolved_client else None,
        "created_at": db_txn.created_at.isoformat()
    }


@router.post("/text-to-action")
def text_to_action(payload: TextActionPayload, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """
    Analyser une phrase textuelle décrivant une vente, un achat ou une dépense,
    résoudre les entités associées et enregistrer la transaction correspondante.
    """
    logger.debug("text_to_action called by user_id=%s payload=%s", getattr(current_user, 'id', None), getattr(payload, 'text', None))

    if not payload.text or not payload.text.strip():
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail="Le texte de la commande ne peut pas être vide."
        )

    try:
        # Parser la phrase (mistral/openai ou regex de repli)
        parsed = parse_text_to_transaction(payload.text)

        # Traiter et enregistrer l'action
        result = process_parsed_action(parsed, db, current_user.id)
        logger.info("text_to_action processed user_id=%s parsed=%s transaction_id=%s", current_user.id, parsed, result.get('id'))
        return result
    except Exception as e:
        logger.exception("Error in text_to_action for user_id=%s: %s", getattr(current_user, 'id', None), e)
        raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erreur lors du traitement du texte")


@router.post("/voice-to-action")
def voice_to_action(file: UploadFile = File(...), db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """
    Réceptionner un fichier audio, le transcrire via OpenAI Whisper,
    puis parser le texte obtenu pour enregistrer la transaction.
    """
    logger.debug("voice_to_action called by user_id=%s filename=%s content_type=%s", getattr(current_user, 'id', None), getattr(file, 'filename', None), getattr(file, 'content_type', None))

    # Sauvegarde temporaire du fichier audio
    suffix = os.path.splitext(file.filename)[1] if file.filename else ".m4a"
    with tempfile.NamedTemporaryFile(delete=False, suffix=suffix) as tmp:
        try:
            shutil.copyfileobj(file.file, tmp)
            temp_path = tmp.name
        finally:
            file.file.close()

    try:
        # Transcription de l'audio
        try:
            transcribed_text = transcribe_audio_file(temp_path)
        except HTTPException as he:
            # Propagate HTTPExceptions raised by stt_service (e.g., 429)
            logger.warning("Transcription HTTPException for user_id=%s file=%s: %s", getattr(current_user, 'id', None), temp_path, he.detail if hasattr(he, 'detail') else he)
            raise
        except Exception as e:
            logger.exception("Transcription failed for user_id=%s file=%s: %s", getattr(current_user, 'id', None), temp_path, e)
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erreur lors de la transcription audio")

        if not transcribed_text or not transcribed_text.strip():
            logger.warning("Empty transcription for user_id=%s file=%s", getattr(current_user, 'id', None), temp_path)
            raise HTTPException(
                status_code=status.HTTP_400_BAD_REQUEST,
                detail="La transcription audio a échoué ou est vide."
            )

        try:
            # Parser et enregistrer l'action
            parsed = parse_text_to_transaction(transcribed_text)
            result = process_parsed_action(parsed, db, current_user.id)
            # Ajouter le texte transcrit à la réponse pour l'expérience utilisateur
            result["transcribed_text"] = transcribed_text
            logger.info("voice_to_action processed user_id=%s parsed=%s transaction_id=%s", current_user.id, parsed, result.get('id'))
            return result
        except HTTPException:
            raise
        except Exception as e:
            logger.exception("Error parsing/processing transcribed text for user_id=%s: %s", getattr(current_user, 'id', None), e)
            raise HTTPException(status_code=status.HTTP_500_INTERNAL_SERVER_ERROR, detail="Erreur lors du traitement de la transcription")
    finally:
        # Nettoyer le fichier temporaire
        if os.path.exists(temp_path):
            try:
                os.remove(temp_path)
            except Exception:
                logger.warning("Failed to remove temp file %s", temp_path)


@router.get("/transcription-health")
def transcription_health():
    """
    Endpoint léger pour vérifier la disponibilité de l'API OpenAI utilisée pour la transcription.
    Renvoie la version du package openai installé et tente une opération non destructive (liste des modèles)
    pour valider que la clé API est configurée et que le service répond.
    """
    try:
        import openai
    except Exception as e:
        logger.warning("transcription_health: openai import failed: %s", e)
        return {"ok": False, "reason": "openai package not installed"}

    ver = getattr(openai, "__version__", None) or getattr(openai, "version", "unknown")
    try:
        major = int(str(ver).split(".")[0])
    except Exception:
        major = 0

    # Try to make a harmless metadata call to validate the key
    try:
        if major >= 1:
            from openai import OpenAI
            try:
                client = OpenAI(api_key=os.getenv("OPENAI_API_KEY"))
            except TypeError:
                os.environ["OPENAI_API_KEY"] = os.getenv("OPENAI_API_KEY", "")
                client = OpenAI()
            resp = client.models.list()
            sample = None
            try:
                sample = len(resp.data) if hasattr(resp, 'data') else (len(resp.get('data')) if isinstance(resp, dict) and 'data' in resp else None)
            except Exception:
                sample = None
            return {"ok": True, "openai_version": str(ver), "models_sample_count": sample}
        else:
            # legacy
            openai.api_key = os.getenv("OPENAI_API_KEY")
            try:
                resp = openai.Model.list()
            except Exception:
                # older clients might use Engine or Model, tolerate both
                resp = openai.Engine.list()
            sample = None
            try:
                sample = len(resp.data) if hasattr(resp, 'data') else (len(resp.get('data')) if isinstance(resp, dict) and 'data' in resp else None)
            except Exception:
                sample = None
            return {"ok": True, "openai_version": str(ver), "models_sample_count": sample}
    except Exception as e:
        logger.exception("transcription_health check failed: %s", e)
        return {"ok": False, "openai_version": str(ver), "error": str(e)}
