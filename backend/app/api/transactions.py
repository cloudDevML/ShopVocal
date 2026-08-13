from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.db.session import get_db
from app.models.domain import Transaction, Product, TransactionType, Client, User
from app.schemas.domain import TransactionCreate, TransactionResponse
from app.api.v1.auth import get_current_user

router = APIRouter(prefix="/transactions", tags=["Transactions Financières"])

@router.post("/", response_model=TransactionResponse, status_code=status.HTTP_201_CREATED)
def create_transaction(txn_in: TransactionCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """
    Enregistrer une transaction (Vente, Achat, Dépense) 
    et mettre à jour automatiquement les stocks.
    """
    # 1. Vérification du produit s'il est spécifié
    product = None
    if txn_in.product_id:
        product = db.query(Product).filter(
            Product.id == txn_in.product_id,
            Product.user_id == current_user.id
        ).first()
        if not product:
            raise HTTPException(status_code=404, detail="Produit non trouvé")

    # 2. Vérification du client s'il est spécifié
    client = None
    if txn_in.client_id:
        client = db.query(Client).filter(
            Client.id == txn_in.client_id,
            Client.user_id == current_user.id
        ).first()
        if not client:
            raise HTTPException(status_code=404, detail="Client non trouvé")

    # 3. Gestion des règles métiers selon le type de transaction
    if txn_in.type == TransactionType.SALE:
        if product and txn_in.quantity:
            if product.quantity < txn_in.quantity:
                raise HTTPException(
                    status_code=400, 
                    detail=f"Stock insuffisant ! Stock disponible: {product.quantity}"
                )
            product.quantity -= txn_in.quantity

    elif txn_in.type == TransactionType.PURCHASE:
        if product and txn_in.quantity:
            product.quantity += txn_in.quantity

    # 4. Traitement éventuel d'un crédit client (uniquement pour les ventes)
    if client and txn_in.type == TransactionType.SALE:
        client.debt_amount += txn_in.amount

    # 4. Sauvegarde de la transaction
    db_txn = Transaction(
        user_id=current_user.id,
        type=txn_in.type,
        amount=txn_in.amount,
        description=txn_in.description,
        product_id=txn_in.product_id,
        quantity=txn_in.quantity,
        client_id=txn_in.client_id
    )
    db.add(db_txn)
    db.commit()
    db.refresh(db_txn)
    return db_txn

@router.get("", response_model=List[TransactionResponse])
@router.get("/", response_model=List[TransactionResponse])
def list_transactions(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Obtenir l'historique complet des transactions."""
    return db.query(Transaction).filter(Transaction.user_id == current_user.id).all()

@router.get("/summary")
def get_financial_summary(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """
    Obtenir la synthèse financière (Chiffre d'affaires, Dépenses, Bénéfice estimé).
    """
    transactions = db.query(Transaction).filter(Transaction.user_id == current_user.id).all()

    total_sales = sum(t.amount for t in transactions if t.type == TransactionType.SALE)
    total_purchases = sum(t.amount for t in transactions if t.type == TransactionType.PURCHASE)
    total_expenses = sum(t.amount for t in transactions if t.type == TransactionType.EXPENSE)

    # Calcul estimé du bénéfice brut sur ventes (Prix Vente - Prix Achat)
    cost_of_goods_sold = 0.0
    for t in transactions:
        if t.type == TransactionType.SALE and t.product_id and t.quantity:
            prod = db.query(Product).filter(Product.id == t.product_id, Product.user_id == current_user.id).first()
            if prod:
                cost_of_goods_sold += (prod.cost_price or 0.0) * t.quantity

    gross_profit = total_sales - cost_of_goods_sold
    net_profit = gross_profit - total_expenses

    return {
        "chiffre_d_affaires": total_sales,
        "achats_stock": total_purchases,
        "depenses_ancillaires": total_expenses,
        "cout_des_marchandises_vendues": cost_of_goods_sold,
        "benefice_brut": gross_profit,
        "benefice_net": net_profit
    }