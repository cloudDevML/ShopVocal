"""
Script de test des chaînes de fallback STT + NLU.
Exécuter depuis le dossier backend/ avec le .venv activé :
  python test_fallback.py
"""
import os
import sys

# Charger le .env
from dotenv import load_dotenv
load_dotenv(".env")

print("=" * 60)
print("TEST DES CHAÎNES DE FALLBACK STT + NLU")
print("=" * 60)

# Afficher les clés disponibles (tronquées pour sécurité)
def show_key(name):
    val = os.getenv(name, "")
    if val:
        print(f"  [OK] {name}: {val[:15]}...")
    else:
        print(f"  [--] {name}: non defini")

print("\n[CONFIG] Clés API disponibles :")
show_key("GROQ_API_KEY")
show_key("GOOGLE_API_KEY")
show_key("OPENAI_API_KEY")
print(f"  Mock mode: {os.getenv('OPENAI_TRANSCRIPTION_MOCK', 'non')}")

# ---------------------------------------------------------------------------
# Test NLU (ne nécessite pas de fichier audio)
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("TEST NLU — Parsing de phrases")
print("=" * 60)

# Ajouter le parent dans le path pour les imports app.*
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from app.services.ai_parser import (
    _try_groq_llm, _try_gemini_llm, _try_openai_llm, _regex_fallback,
    parse_text_to_transaction
)

test_phrases = [
    "J'ai vendu 3 Coca-Cola à 1500 FCFA",
    "Achat de 50 kg de riz à 25000 FCFA",
    "Dépense loyer 80000 francs",
    "Vente 2 bouteilles d'huile à Aminata pour 2000 FCFA",
]

for phrase in test_phrases:
    print(f"\nPhrase : '{phrase}'")
    result = parse_text_to_transaction(phrase)
    source = result.pop("_source", "?")
    print(f"  Source : {source}")
    print(f"  type={result['type']}  amount={result['amount']}  "
          f"product={result['_guessed_product_name']}  qty={result['quantity']}")

# ---------------------------------------------------------------------------
# Test individuel de chaque moteur NLU
# ---------------------------------------------------------------------------
print("\n" + "=" * 60)
print("TEST INDIVIDUEL — Chaque moteur NLU")
print("=" * 60)

phrase = "J'ai vendu 5 Coca-Cola à 2500 FCFA"
print(f"\nPhrase de test : '{phrase}'\n")

print("1. Groq LLaMA :")
r = _try_groq_llm(phrase)
print(f"   → {r}\n" if r else "   → ✗ Non disponible\n")

print("2. Gemini Flash :")
r = _try_gemini_llm(phrase)
print(f"   → {r}\n" if r else "   → ✗ Non disponible\n")

print("3. OpenAI GPT :")
r = _try_openai_llm(phrase)
print(f"   → {r}\n" if r else "   → ✗ Non disponible\n")

print("4. Regex (toujours disponible) :")
r = _regex_fallback(phrase)
print(f"   → type={r['type']} amount={r['amount']} product={r['_guessed_product_name']}\n")

print("=" * 60)
print("TEST TERMINÉ")
print("=" * 60)
