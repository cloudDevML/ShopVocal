# Patch de compatibilité bcrypt/passlib sous Python 3.12+
try:
    import bcrypt
    original_hashpw = bcrypt.hashpw
    def patched_hashpw(password, salt):
        if isinstance(password, str):
            password = password.encode('utf-8')
        if len(password) > 72:
            password = password[:72]
        return original_hashpw(password, salt)
    bcrypt.hashpw = patched_hashpw
except ImportError:
    pass

# Chargement des variables d'environnement depuis le fichier .env (DATABASE_URL, OPENAI_API_KEY, etc.)
import os
from dotenv import load_dotenv
load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), '.env'))

import logging
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

# Configure basic logging for the application (DEBUG during development)
logging.basicConfig(level=logging.INFO, format='%(asctime)s %(levelname)s [%(name)s] %(message)s')
logger = logging.getLogger('backend')
logger.info('Starting Assistant Intelligent Commerçant API')
from app.db.session import engine, Base, SessionLocal
from app.models import domain
from app.models.domain import User

# Importation des routeurs
from app.api.products import router as products_router
from app.api.transactions import router as transactions_router
from app.api.clients import router as clients_router

# Importation des routeurs v1 (AI & Auth)
from app.api.v1.ai_voice import router as ai_router
from app.api.v1.auth import router as auth_router

# Création des tables dans la base de données
Base.metadata.create_all(bind=engine)

app = FastAPI(
    title="Assistant Intelligent Commerçant API",
    version="1.0.0",
    description="Backend de gestion commerciale et assistant vocal IA"
)

# Configuration CORS pour autoriser Flutter Web et clients navigateurs
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

@app.on_event("startup")
def startup_event():
    logger.info("Starting Assistant Intelligent Commerçant API")

# Enregistrement des routes
app.include_router(products_router)
app.include_router(transactions_router)
app.include_router(clients_router)

# v1 routes
app.include_router(ai_router)
app.include_router(auth_router)

@app.get("/")
def read_root():
    return {"status": "ok", "message": "API de Gestion Commerciale Opérationnelle"}
