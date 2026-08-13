from fastapi import APIRouter, Depends, HTTPException, status
from sqlalchemy.orm import Session
from typing import List
from pydantic import BaseModel

from app.db.session import get_db
from app.models.domain import Client, User
from app.api.v1.auth import get_current_user

router = APIRouter(prefix="/clients", tags=["Clients & Dettes"])

class ClientCreate(BaseModel):
    name: str
    phone: str | None = None
    debt_amount: float = 0.0

class ClientResponse(ClientCreate):
    id: int
    user_id: int

    class Config:
        from_attributes = True

@router.post("/", response_model=ClientResponse, status_code=status.HTTP_201_CREATED)
def create_client(client_in: ClientCreate, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Ajouter un client à la fiche des dettes/crédits."""
    db_client = Client(
        user_id=current_user.id,
        name=client_in.name,
        phone=client_in.phone,
        debt_amount=client_in.debt_amount
    )
    db.add(db_client)
    db.commit()
    db.refresh(db_client)
    return db_client

@router.get("/", response_model=List[ClientResponse])
def list_clients(db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Obtenir la liste des clients et le suivi des dettes."""
    return db.query(Client).filter(Client.user_id == current_user.id).all()

@router.put("/{client_id}/pay")
def pay_debt(client_id: int, amount_paid: float, db: Session = Depends(get_db), current_user: User = Depends(get_current_user)):
    """Enregistrer un remboursement partiel ou total d'une dette client."""
    client = db.query(Client).filter(
        Client.id == client_id, 
        Client.user_id == current_user.id
    ).first()
    if not client:
        raise HTTPException(status_code=404, detail="Client non trouvé")

    client.debt_amount = max(0.0, client.debt_amount - amount_paid)
    db.commit()
    db.refresh(client)
    return {
        "message": "Paiement enregistré avec succès",
        "dette_restante": client.debt_amount
    }