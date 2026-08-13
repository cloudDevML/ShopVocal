"""
Script de création de produits réalistes pour un commerçant sénégalais.

Usage :
    python seed_products.py                    # Via l'API (backend doit tourner)
    python seed_products.py --direct           # Directement en base (backend peut être arrêté)
    python seed_products.py --phone +221XXXXXXX --password votre_mdp

Par défaut, utilise le premier compte trouvé en base via --direct.
"""
import sys
import os
import argparse

# ---------------------------------------------------------------------------
# Catalogue de produits réalistes (commerce sénégalais)
# ---------------------------------------------------------------------------

PRODUITS = [
    # Tissus & Vêtements
    {
        "name": "Basin Riche (5m)",
        "unit_price": 15000,
        "cost_price": 9000,
        "quantity": 30,
        "min_stock_alert": 5,
    },
    {
        "name": "T-shirt Coton",
        "unit_price": 2500,
        "cost_price": 1200,
        "quantity": 100,
        "min_stock_alert": 15,
    },
    {
        "name": "Jean Homme",
        "unit_price": 8000,
        "cost_price": 4500,
        "quantity": 40,
        "min_stock_alert": 8,
    },
    {
        "name": "Boubou Brodé",
        "unit_price": 25000,
        "cost_price": 14000,
        "quantity": 20,
        "min_stock_alert": 3,
    },
    {
        "name": "Pagne Wax (6 yards)",
        "unit_price": 12000,
        "cost_price": 7000,
        "quantity": 50,
        "min_stock_alert": 10,
    },

    # Alimentation
    {
        "name": "Sac de riz (50 kg)",
        "unit_price": 22000,
        "cost_price": 18500,
        "quantity": 20,
        "min_stock_alert": 5,
    },
    {
        "name": "Huile végétale (5 L)",
        "unit_price": 5500,
        "cost_price": 4200,
        "quantity": 60,
        "min_stock_alert": 10,
    },
    {
        "name": "Sucre (1 kg)",
        "unit_price": 800,
        "cost_price": 600,
        "quantity": 150,
        "min_stock_alert": 20,
    },
    {
        "name": "Café Touba (250g)",
        "unit_price": 1500,
        "cost_price": 1000,
        "quantity": 80,
        "min_stock_alert": 15,
    },
    {
        "name": "Coca-Cola (33 cl)",
        "unit_price": 500,
        "cost_price": 300,
        "quantity": 240,
        "min_stock_alert": 24,
    },

    # Téléphonie & Accessoires
    {
        "name": "Crédit téléphonique Orange (500 F)",
        "unit_price": 500,
        "cost_price": 475,
        "quantity": 200,
        "min_stock_alert": 20,
    },
    {
        "name": "Chargeur Téléphone USB-C",
        "unit_price": 3000,
        "cost_price": 1500,
        "quantity": 25,
        "min_stock_alert": 5,
    },
    {
        "name": "Écouteurs intra-auriculaires",
        "unit_price": 2000,
        "cost_price": 900,
        "quantity": 30,
        "min_stock_alert": 5,
    },

    # Cosmétiques & Hygiène
    {
        "name": "Savon Lux (paquet 6)",
        "unit_price": 2400,
        "cost_price": 1800,
        "quantity": 50,
        "min_stock_alert": 10,
    },
    {
        "name": "Crème de beauté Carotone",
        "unit_price": 4500,
        "cost_price": 3000,
        "quantity": 30,
        "min_stock_alert": 5,
    },
    {
        "name": "Parfum Arabes (100 ml)",
        "unit_price": 6000,
        "cost_price": 3500,
        "quantity": 15,
        "min_stock_alert": 3,
    },

    # Chaussures
    {
        "name": "Sandales en cuir",
        "unit_price": 5000,
        "cost_price": 2800,
        "quantity": 35,
        "min_stock_alert": 5,
    },
    {
        "name": "Basket Sport",
        "unit_price": 12000,
        "cost_price": 7000,
        "quantity": 20,
        "min_stock_alert": 4,
    },

    # Divers
    {
        "name": "Bougie (paquet 10)",
        "unit_price": 1000,
        "cost_price": 650,
        "quantity": 100,
        "min_stock_alert": 15,
    },
    {
        "name": "Détergent Ariel (1 kg)",
        "unit_price": 1800,
        "cost_price": 1300,
        "quantity": 70,
        "min_stock_alert": 10,
    },
]


# ---------------------------------------------------------------------------
# Mode 1 : Insertion directe en base (sans backend)
# ---------------------------------------------------------------------------

def seed_direct(user_id: int):
    from dotenv import load_dotenv
    load_dotenv(".env")
    from sqlalchemy import create_engine
    from sqlalchemy.orm import sessionmaker
    import sys
    sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
    from app.models.domain import Product

    engine = create_engine(os.getenv("DATABASE_URL"))
    Session = sessionmaker(bind=engine)
    db = Session()

    try:
        created = 0
        skipped = 0
        for p in PRODUITS:
            existing = db.query(Product).filter(
                Product.name == p["name"],
                Product.user_id == user_id
            ).first()
            if existing:
                print(f"  [SKIP] '{p['name']}' existe déjà (id={existing.id})")
                skipped += 1
                continue
            product = Product(
                user_id=user_id,
                name=p["name"],
                unit_price=p["unit_price"],
                cost_price=p["cost_price"],
                quantity=p["quantity"],
                min_stock_alert=p["min_stock_alert"],
            )
            db.add(product)
            print(f"  [OK]   '{p['name']}' — prix={p['unit_price']} FCFA, stock={p['quantity']}")
            created += 1
        db.commit()
        print(f"\n  {created} produit(s) créé(s), {skipped} ignoré(s) (déjà existant).")
    except Exception as e:
        db.rollback()
        print(f"  ERREUR : {e}")
        raise
    finally:
        db.close()


# ---------------------------------------------------------------------------
# Mode 2 : Via l'API HTTP (backend doit tourner)
# ---------------------------------------------------------------------------

def seed_via_api(phone: str, password: str, base_url: str):
    import requests

    # Login
    print(f"  Connexion en tant que {phone}...")
    resp = requests.post(f"{base_url}/auth/login", json={"phone_number": phone, "password": password})
    if resp.status_code != 200:
        print(f"  ERREUR login : {resp.status_code} — {resp.text}")
        sys.exit(1)
    token = resp.json().get("access_token")
    headers = {"Authorization": f"Bearer {token}"}
    print(f"  Connecté.\n")

    created = 0
    skipped = 0
    errors = 0

    for p in PRODUITS:
        payload = {
            "name": p["name"],
            "unit_price": p["unit_price"],
            "cost_price": p["cost_price"],
            "quantity": p["quantity"],
            "min_stock_alert": p["min_stock_alert"],
        }
        resp = requests.post(f"{base_url}/products", json=payload, headers=headers)
        if resp.status_code == 201:
            data = resp.json()
            print(f"  [OK]   '{p['name']}' — id={data.get('id')} prix={p['unit_price']} FCFA")
            created += 1
        elif resp.status_code == 409:
            print(f"  [SKIP] '{p['name']}' — déjà existant")
            skipped += 1
        else:
            print(f"  [ERR]  '{p['name']}' — {resp.status_code} : {resp.text[:80]}")
            errors += 1

    print(f"\n  {created} créé(s), {skipped} ignoré(s), {errors} erreur(s).")


# ---------------------------------------------------------------------------
# Point d'entrée
# ---------------------------------------------------------------------------

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Création de produits de démonstration")
    parser.add_argument("--direct", action="store_true",
                        help="Insérer directement en base (sans API)")
    parser.add_argument("--user-id", type=int, default=1,
                        help="ID utilisateur cible (mode --direct, défaut: 1)")
    parser.add_argument("--phone", type=str, default="+221770000000",
                        help="Numéro de téléphone pour le login API")
    parser.add_argument("--password", type=str, default="password123",
                        help="Mot de passe pour le login API")
    parser.add_argument("--url", type=str, default="http://localhost:8000",
                        help="URL du backend (défaut: http://localhost:8000)")
    args = parser.parse_args()

    print("=" * 55)
    print("  CRÉATION DES PRODUITS — Assistant Commerçant")
    print("=" * 55)
    print(f"  Nombre de produits à créer : {len(PRODUITS)}")
    print()

    if args.direct:
        print(f"  Mode : insertion directe en base (user_id={args.user_id})")
        print()
        seed_direct(args.user_id)
    else:
        print(f"  Mode : via API ({args.url})")
        print()
        seed_via_api(args.phone, args.password, args.url)

    print()
    print("=" * 55)
    print("  TERMINÉ")
    print("=" * 55)
