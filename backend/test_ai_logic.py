import os
import sys

# Ajouter le dossier backend au path pour pouvoir importer app
sys.path.append(os.path.join(os.path.dirname(__file__)))

from app.db.session import Base
from app.models.domain import User, Product, Client, Transaction, TransactionType
from app.api.v1.ai_voice import process_parsed_action
from app.services.ai_parser import parse_text_to_transaction

def setup_db():
    # S'assurer de nettoyer la base de données de test locale
    db_file = "test_dev_database.db"
    if os.path.exists(db_file):
        try:
            os.remove(db_file)
        except Exception:
            pass
        
    # Modifier l'URL de connexion pour pointer vers notre DB de test
    import app.db.session as session_module
    session_module.SQLALCHEMY_DATABASE_URL = f"sqlite:///./{db_file}"
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    
    test_engine = create_engine(session_module.SQLALCHEMY_DATABASE_URL)
    session_module.engine = test_engine
    session_module.SessionLocal = sessionmaker(autocommit=False, autoflush=False, bind=test_engine)
    
    Base.metadata.create_all(bind=test_engine)
    return session_module.SessionLocal()

def test_nlu_flow():
    db = setup_db()
    try:
        # 1. Créer un utilisateur et un produit
        default_user = User(
            id=1,
            phone_number="+221770000000",
            full_name="Test Commercant",
            hashed_password="hashed"
        )
        db.add(default_user)
        
        coca = Product(
            user_id=1,
            name="Coca Cola",
            quantity=10.0,
            unit_price=1000.0,
            cost_price=700.0,
            min_stock_alert=2.0
        )
        db.add(coca)
        db.commit()
        
        print("--- Etape 1 : Donnees initiales creees ---")
        print(f"Produit en stock : {coca.name}, Quantite : {coca.quantity}")

        # 2. Phrase d'entrée
        phrase = "J'ai vendu 3 Coca Cola pour 3000 FCFA"
        print(f"\n--- Etape 2 : Phrase recue : '{phrase}' ---")
        
        # 3. Parser la phrase
        parsed = parse_text_to_transaction(phrase)
        print("Resultat du parsing :")
        print(parsed)
        
        # Le parser regex trouve Coca Cola et 3000
        # Forçons la simulation de client Aminata pour tester la création automatique de client
        parsed["_guessed_client_name"] = "Aminata"
        
        # 4. Traiter l'action en DB
        print("\n--- Etape 3 : Traitement de la transaction ---")
        result = process_parsed_action(parsed, db, user_id=1)
        print("Resultat de process_parsed_action :")
        print(result)
        
        # 5. Vérifier les effets de bord
        db.refresh(coca)
        print("\n--- Etape 4 : Verification des effets de bord ---")
        print(f"Nouvelle quantite de Coca Cola (devrait etre 7.0) : {coca.quantity}")
        assert coca.quantity == 7.0
        
        client = db.query(Client).filter(Client.user_id == 1).first()
        print(f"Client cree automatiquement : {client.name}, Dette (devrait etre 3000.0) : {client.debt_amount}")
        assert client.name == "Aminata"
        assert client.debt_amount == 3000.0
        
        txn = db.query(Transaction).filter(Transaction.user_id == 1).first()
        print(f"Transaction enregistree : ID={txn.id}, Type={txn.type.value}, Montant={txn.amount}")
        assert txn.amount == 3000.0
        assert txn.type == TransactionType.SALE
        
        print("\n[OK] TOUS LES TESTS D'INTEGRATION IA SONT PASSES AVEC SUCCES !")
        
    finally:
        db.close()
        if os.path.exists("test_dev_database.db"):
            try:
                os.remove("test_dev_database.db")
            except Exception:
                pass

if __name__ == "__main__":
    test_nlu_flow()
