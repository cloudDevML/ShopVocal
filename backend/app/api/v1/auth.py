import os
from datetime import datetime, timedelta
from typing import Optional

from fastapi import APIRouter, Depends, HTTPException, Security
from fastapi import status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from pydantic import BaseModel
from jose import jwt, JWTError
from passlib.context import CryptContext
from passlib.exc import UnknownHashError
from sqlalchemy.orm import Session

from app.db.session import get_db
from app.models.domain import User

SECRET_KEY = os.getenv("SECRET_KEY", "dev-secret-key")
ALGORITHM = "HS256"
ACCESS_TOKEN_EXPIRE_MINUTES = 60 * 24 * 7  # 7 days

pwd_context = CryptContext(schemes=["bcrypt"], deprecated="auto")
security = HTTPBearer()

router = APIRouter(prefix="/auth", tags=["Authentication"])


class RegisterPayload(BaseModel):
    phone_number: str
    password: str
    full_name: Optional[str] = None


class TokenResponse(BaseModel):
    access_token: str
    token_type: str = "bearer"


def create_access_token(data: dict, expires_delta: Optional[timedelta] = None):
    to_encode = data.copy()
    if expires_delta:
        expire = datetime.utcnow() + expires_delta
    else:
        expire = datetime.utcnow() + timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    to_encode.update({"exp": expire})
    encoded_jwt = jwt.encode(to_encode, SECRET_KEY, algorithm=ALGORITHM)
    return encoded_jwt


@router.post("/register", response_model=TokenResponse)
def register(payload: RegisterPayload, db: Session = Depends(get_db)):
    existing = db.query(User).filter(User.phone_number == payload.phone_number).first()
    if existing:
        raise HTTPException(status_code=400, detail="Phone number already registered")
    hashed = pwd_context.hash(payload.password)
    user = User(phone_number=payload.phone_number, full_name=payload.full_name, hashed_password=hashed)
    db.add(user)
    db.commit()
    db.refresh(user)
    token = create_access_token({"sub": str(user.id)})
    return {"access_token": token}


class LoginPayload(BaseModel):
    phone_number: str
    password: str


@router.post("/login", response_model=TokenResponse)
def login(payload: LoginPayload, db: Session = Depends(get_db)):
    user = db.query(User).filter(User.phone_number == payload.phone_number).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    try:
        valid = pwd_context.verify(payload.password, user.hashed_password)
    except UnknownHashError:
        # Stored hash has unknown format — treat as invalid credentials rather than crashing
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")
    except Exception:
        # Any other verification error -> return generic unauthorized
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    if not valid:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid credentials")

    token = create_access_token({"sub": str(user.id)})
    return {"access_token": token}


# Dependency to get current user from Authorization header
def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security), db: Session = Depends(get_db)) -> User:
    token = credentials.credentials
    try:
        payload = jwt.decode(token, SECRET_KEY, algorithms=[ALGORITHM])
        sub = payload.get("sub")
        if sub is None:
            raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication credentials")
    except JWTError:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="Invalid authentication credentials")

    user = db.query(User).filter(User.id == int(sub)).first()
    if not user:
        raise HTTPException(status_code=status.HTTP_401_UNAUTHORIZED, detail="User not found")
    return user
