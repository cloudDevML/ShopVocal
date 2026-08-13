from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List

from app.db.session import get_db
from app.models.domain import Product
from app.schemas.domain import ProductCreate, ProductResponse

router = APIRouter(prefix="/products", tags=["Produits & Stock"])

# ID utilisateur temporaire en attendant l'authentification JWT
TEMP_USER_ID = 1

@router.post("/", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(product_in: ProductCreate, db: Session = Depends(get_db)):
    """Créer un nouveau produit dans le stock."""
    db_product = Product(
        user_id=TEMP_USER_ID,
        name=product_in.name,
        quantity=product_in.quantity,
        unit_price=product_in.unit_price,
        cost_price=product_in.cost_price or 0.0
    )
    db.add(db_product)
    db.commit()
    db.refresh(db_product)
    return db_product

@router.get("/", response_model=List[ProductResponse])
def list_products(db: Session = Depends(get_db)):
    """Obtenir la liste de tous les produits du commerçant."""
    return db.query(Product).filter(Product.user_id == TEMP_USER_ID).all()

@router.get("/alerts", response_model=List[ProductResponse])
def get_low_stock_alerts(db: Session = Depends(get_db)):
    """Obtenir les produits proches de la rupture de stock."""
    return db.query(Product).filter(
        Product.user_id == TEMP_USER_ID,
        Product.quantity <= Product.min_stock_alert
    ).all()