from sqlalchemy import create_engine
from sqlalchemy.orm import declarative_base, sessionmaker
import os
from dotenv import load_dotenv

# Charger .env pour s'assurer que DATABASE_URL est bien lu même en import isolé
_ENV_PATH = os.path.join(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))), ".env")
load_dotenv(dotenv_path=_ENV_PATH)

# URL de connexion à la base de données.
# En test/prod : définir DATABASE_URL=postgresql://dev_user:dev_password@localhost:5432/commercant_db
# En dev local sans Docker : fallback SQLite avec chemin ABSOLU (évite la création de bases multiples)
_BASE_DIR = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
_SQLITE_FALLBACK = f"sqlite:///{_BASE_DIR}/dev_database.db"
SQLALCHEMY_DATABASE_URL = os.getenv("DATABASE_URL", _SQLITE_FALLBACK)

# Arguments de connexion adaptés selon le moteur
_connect_args = {}
if SQLALCHEMY_DATABASE_URL.startswith("sqlite"):
    _connect_args = {"check_same_thread": False}

engine = create_engine(SQLALCHEMY_DATABASE_URL, connect_args=_connect_args)
SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=engine)

Base = declarative_base()


# Dépendance FastAPI pour obtenir une session de DB par requête
def get_db():
    db = SessionLocal()
    try:
        yield db
    finally:
        db.close()
