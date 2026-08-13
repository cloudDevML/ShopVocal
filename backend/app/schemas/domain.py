from pydantic import BaseModel
from typing import Optional
from datetime import datetime
from app.models.domain import TransactionType

# Schemas Produit
class ProductBase(BaseModel):
    name: str
    quantity: float
    unit_price: float
    cost_price: Optional[float] = 0.0

class ProductCreate(ProductBase):
    pass

class ProductResponse(ProductBase):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True

# Schemas Transaction
class TransactionCreate(BaseModel):
    type: TransactionType
    amount: float
    description: Optional[str] = None
    product_id: Optional[int] = None
    quantity: Optional[float] = None
    client_id: Optional[int] = None

class TransactionResponse(TransactionCreate):
    id: int
    user_id: int
    created_at: datetime

    class Config:
        from_attributes = True