import os
import sys
from fastapi.testclient import TestClient

# Monkeypatch bcrypt pour éviter l'erreur ValueError: password cannot be longer than 72 bytes sous Python 3.12+ avec passlib
import bcrypt
original_hashpw = bcrypt.hashpw
def patched_hashpw(password, salt):
    if isinstance(password, str):
        password = password.encode('utf-8')
    if len(password) > 72:
        password = password[:72]
    return original_hashpw(password, salt)
bcrypt.hashpw = patched_hashpw

# Ajouter le dossier backend au path
sys.path.append(os.path.join(os.path.dirname(__file__)))

from main import app
from app.db.session import Base

def setup_test_db():
    db_file = "test_auth_database.db"
    if os.path.exists(db_file):
        try: os.remove(db_file)
        except Exception: pass
        
    import app.db.session as session_module
    session_module.SQLALCHEMY_DATABASE_URL = f"sqlite:///./{db_file}"
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    
    test_engine = create_engine(session_module.SQLALCHEMY_DATABASE_URL)
    session_module.engine = test_engine
    session_module.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    
    Base.metadata.create_all(bind=test_engine)
    return db_file

def test_jwt_authentication_flow():
    db_file = setup_test_db()
    client = TestClient(app)
    
    try:
        # 1. Tester la route publique "/"
        resp = client.get("/")
        assert resp.status_code == 200
        assert resp.json()["status"] == "ok"

        # 2. Tester l'accès non authentifié à /products (doit renvoyer 401)
        resp = client.get("/products/")
        assert resp.status_code == 401
        
        # 3. Créer deux utilisateurs différents
        # Utilisateur 1
        payload_u1 = {"phone_number": "+221771111111", "password": "password123", "full_name": "Merchant One"}
        resp = client.post("/auth/register", json=payload_u1)
        assert resp.status_code == 200
        token_u1 = resp.json()["access_token"]
        
        # Utilisateur 2
        payload_u2 = {"phone_number": "+221772222222", "password": "password123", "full_name": "Merchant Two"}
        resp = client.post("/auth/register", json=payload_u2)
        assert resp.status_code == 200
        token_u2 = resp.json()["access_token"]
        
        # En-têtes d'authentification
        headers_u1 = {"Authorization": f"Bearer {token_u1}"}
        headers_u2 = {"Authorization": f"Bearer {token_u2}"}
        
        # 4. Créer un produit pour l'Utilisateur 1
        prod_payload = {"name": "Banane", "quantity": 50.0, "unit_price": 100.0, "cost_price": 70.0}
        resp = client.post("/products/", json=prod_payload, headers=headers_u1)
        assert resp.status_code == 201
        assert resp.json()["name"] == "Banane"
        
        # 5. Vérifier que l'Utilisateur 1 voit son produit
        resp = client.get("/products/", headers=headers_u1)
        assert resp.status_code == 200
        assert len(resp.json()) == 1
        assert resp.json()[0]["name"] == "Banane"
        
        # 6. Vérifier que l'Utilisateur 2 ne voit PAS le produit de l'Utilisateur 1 (Isolation)
        resp = client.get("/products/", headers=headers_u2)
        assert resp.status_code == 200
        assert len(resp.json()) == 0
        
        print("\n[OK] TOUS LES TESTS D'AUTHENTIFICATION JWT ET D'ISOLATION SONT PASSES !")
        
    finally:
        if os.path.exists(db_file):
            try: os.remove(db_file)
            except Exception: pass

if __name__ == "__main__":
    test_jwt_authentication_flow()
