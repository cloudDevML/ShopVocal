from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
import logging

from app.db.session import get_db
from app.models.domain import Product, User
from app.schemas.domain import ProductCreate, ProductResponse
from app.api.v1.auth import get_current_user

logger = logging.getLogger("backend.products")
router = APIRouter(prefix="/products", tags=["Produits & Stock"])

# Accept both /products and /products/ to avoid 307 Temporary Redirects from clients
@router.post("", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
@router.post("/", response_model=ProductResponse, status_code=status.HTTP_201_CREATED)
def create_product(product_in: ProductCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Créer un nouveau produit dans le stock."""
    logger.debug("create_product called by user_id=%s payload=%s", getattr(current_user, 'id', None), product_in.dict())
    db_product = Product(
        user_id=current_user.id,
        name=product_in.name,
        quantity=product_in.quantity,
        unit_price=product_in.unit_price,
        cost_price=product_in.cost_price or 0.0
    )
    db.add(db_product)
    db.commit()
    db.refresh(db_product)
    logger.info("Product created id=%s name=%s user_id=%s", db_product.id, db_product.name, current_user.id)
    return db_product

# Accept both /products and /products/ (sans slash = même handler)
@router.get("", response_model=List[ProductResponse])
@router.get("/", response_model=List[ProductResponse])
def list_products(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Obtenir la liste de tous les produits du commerçant."""
    return db.query(Product).filter(Product.user_id == current_user.id).all()

@router.get("/alerts", response_model=List[ProductResponse])
@router.get("/alerts/", response_model=List[ProductResponse])
def get_low_stock_alerts(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Obtenir les produits proches de la rupture de stock."""
    return db.query(Product).filter(
        Product.user_id == current_user.id,
        Product.quantity <= Product.min_stock_alert
    ).all()