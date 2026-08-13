# 🛒 Assistant Intelligent Commerçant

Application mobile de gestion commerciale avec assistant vocal IA pour commerçants sénégalais.

**Stack :** Flutter (mobile) + FastAPI (backend) + PostgreSQL (base de données) + Chaîne de fallback IA multi-fournisseurs (Groq · Gemini · OpenAI · local)

---

## 📁 Structure du Projet

```
Projet_Dev_Mobile/
│
├── docker-compose.yml             # Conteneurs PostgreSQL, PgAdmin
├── README.md                      # Documentation globale
│
├── backend/                       # API Backend (Python / FastAPI)
│   ├── .env                       # ⚙️ Variables d'environnement (clés API, DB…)
│   ├── main.py                    # Point d'entrée FastAPI
│   ├── requirements.txt           # Dépendances Python
│   ├── test_fallback.py           # Script de test des chaînes IA
│   └── app/
│       ├── api/                   # Routes / Endpoints de l'API
│       │   ├── v1/
│       │   │   ├── auth.py        # Connexion / Inscription (JWT)
│       │   │   └── ai_voice.py    # Traitement vocal et IA (NLU)
│       │   ├── products.py        # Gestion du stock
│       │   ├── transactions.py    # Ventes, Achats, Dépenses
│       │   └── clients.py         # Gestion des clients / dettes
│       ├── db/
│       │   └── session.py         # Connexion base de données PostgreSQL
│       ├── models/domain.py       # Modèles SQLAlchemy (User, Product, Transaction…)
│       ├── schemas/               # Validation des données (Pydantic)
│       └── services/
│           ├── ai_parser.py       # NLU : Groq LLaMA → Gemini → OpenAI → Regex
│           └── stt_service.py     # STT : Groq Whisper → OpenAI → faster-whisper local
│
└── mobile/                        # Application Mobile (Flutter)
    ├── android/                   # Configuration native Android
    ├── lib/
    │   ├── core/
    │   │   ├── network/
    │   │   │   ├── api_client.dart    # Client HTTP (Dio + JWT interceptor + logs debug)
    │   │   │   └── api_endpoints.dart # ⚙️ URL de base du backend (adapter selon l'IP)
    │   │   └── storage/
    │   │       └── token_storage.dart # Stockage sécurisé du JWT (flutter_secure_storage)
    │   ├── features/
    │   │   ├── auth/              # Écran connexion / inscription
    │   │   ├── voice_assistant/   # Module vocal (micro, enregistrement, envoi)
    │   │   ├── inventory/         # Gestion du stock (liste, ajout produit)
    │   │   └── dashboard/         # Tableau de bord (CA, bénéfices, alertes stock)
    │   └── main.dart              # Point d'entrée Flutter
    └── pubspec.yaml               # Dépendances Flutter
```

---

## 🤖 Chaînes de Fallback IA (assistant vocal)

L'assistant vocal utilise deux chaînes de fallback automatiques. Si un fournisseur est indisponible ou a épuisé son quota, le suivant prend le relais **sans interruption de service**.

### 🎤 STT — Transcription audio → texte

```
1. Groq Whisper Large V3 Turbo  (cloud, gratuit 2000 req/jour, ~500ms)   ← PRIORITÉ 1
2. OpenAI Whisper-1             (cloud, si crédits disponibles)
3. faster-whisper 'small'       (local hors-ligne, ~3-8s CPU)             ← TOUJOURS DISPO
```

### 🧠 NLU — Texte → Transaction JSON

```
1. Groq LLaMA 3.1-8b-instant   (cloud, gratuit 6K tokens/min, ~300ms)   ← PRIORITÉ 1
2. Google Gemini Flash Lite     (cloud, gratuit)                          ← PRIORITÉ 2
3. OpenAI GPT-3.5               (cloud, si crédits disponibles)
4. Regex rule-based             (local, toujours disponible)              ← TOUJOURS DISPO
```

> **Exemple** : "J'ai vendu 3 Coca-Cola à 500 FCFA"
> → Groq LLaMA extrait : `type=SALE, amount=1500, product=Coca-Cola, qty=3`

---

## 🚀 Guide de Démarrage Complet

### 📋 Prérequis

| Outil | Version minimale | Vérification |
|---|---|---|
| Python | 3.10+ | `python --version` |
| Flutter SDK | 3.x | `flutter --version` |
| Docker Desktop | Dernière version | `docker --version` |
| Git | Toute version | `git --version` |

---

### Étape 1 — Cloner le projet

```bash
git clone <url-du-repo>
cd Projet_Dev_Mobile
```

---

### Étape 2 — Démarrer la base de données PostgreSQL (Docker)

> ⚠️ **Docker Desktop doit être lancé avant cette étape.**

Depuis la **racine du projet** :

```bash
docker-compose up -d db
```

**Vérification :**
```bash
docker ps
# Vous devez voir : assistant_commercant_db   Up ...   0.0.0.0:5432->5432/tcp
```

**Optionnel — Interface web PgAdmin** (inspecter la base visuellement) :
```bash
docker-compose up -d pgadmin
# Accessible sur http://localhost:5050
# Email : admin@admin.com  /  Mot de passe : admin
```

---

### Étape 3 — Configurer et Lancer le Backend

```bash
cd backend
```

#### 3a. Créer l'environnement virtuel Python

```powershell
# Windows (PowerShell)
python -m venv .venv
.venv\Scripts\Activate.ps1
```

```bash
# macOS / Linux
python -m venv .venv
source .venv/bin/activate
```

#### 3b. Installer les dépendances

```bash
pip install -r requirements.txt
```

Les dépendances incluent notamment :
- `groq` — Whisper STT + LLaMA NLU (priorité 1)
- `google-genai` — Gemini Flash NLU (priorité 2)
- `faster-whisper` — STT local hors-ligne (fallback final)

#### 3c. Configurer le fichier `.env`

Le fichier `backend/.env` doit contenir les variables suivantes :

```env
# --- Base de données PostgreSQL (Docker) ---
DATABASE_URL=postgresql://dev_user:dev_password@localhost:5432/commercant_db

# --- Clé API Groq (STT priorité 1 + NLU priorité 1) ---
# Gratuit, sans CB — https://console.groq.com
GROQ_API_KEY=gsk_VOTRE_CLE_GROQ

# --- Clé API Google Gemini (NLU priorité 2) ---
# Gratuit — https://aistudio.google.com/apikey
GOOGLE_API_KEY=AQ.VOTRE_CLE_GEMINI

# --- Clé API OpenAI (STT + NLU fallback) ---
# Optionnel si Groq est configuré — https://platform.openai.com/api-keys
OPENAI_API_KEY=sk-VOTRE_CLE_OPENAI

# --- Sécurité JWT ---
SECRET_KEY=dev-secret-key

# --- Mode mock transcription (développement sans API) ---
# Décommenter pour activer : retourne une transcription fictive instantanément
# OPENAI_TRANSCRIPTION_MOCK=1
```

> **Minimum requis pour l'assistant vocal :** `GROQ_API_KEY` suffit (gratuit).
> Sans aucune clé cloud, `faster-whisper` local prend le relais (plus lent mais toujours fonctionnel).

#### 3d. Lancer le serveur backend

```powershell
# Depuis le dossier backend/ (avec le .venv activé)
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

> ✅ L'option `--host 0.0.0.0` est **obligatoire** pour que le téléphone physique puisse joindre le serveur.

**URLs disponibles :**
- API : `http://<IP_DE_VOTRE_MACHINE>:8000`
- Documentation Swagger : `http://<IP_DE_VOTRE_MACHINE>:8000/docs`

> **Premier démarrage :** Aucun compte n'est pré-créé. Utilisez l'écran **Inscription** de l'application mobile pour créer votre compte commerçant.

**Logs attendus au démarrage :**
```
INFO  Starting Assistant Intelligent Commerçant API
INFO  Application startup complete.
```

**Logs attendus lors d'une commande vocale :**
```
INFO [backend.stt] [STT] ✓ Groq Whisper — texte: J'ai vendu 3 Coca-Cola...
INFO [backend.ai]  [NLU] ✓ Groq LLaMA  — type=SALE amount=1500 product=Coca-Cola
```

---

### Étape 4 — Configurer l'application Mobile (Flutter)

```bash
cd mobile
```

#### 4a. Trouver l'IP Wi-Fi de votre machine

```powershell
# Windows
ipconfig
# Cherchez "Adresse IPv4" sous "Carte réseau sans fil Wi-Fi" → ex: 192.168.X.X
```

```bash
# macOS / Linux
ip route get 1 | awk '{print $7}'
```

#### 4b. Mettre à jour l'URL du backend

Ouvrez `lib/core/network/api_endpoints.dart` et mettez à jour `baseUrl` :

```dart
// Pour un appareil physique : IP Wi-Fi de votre machine
static const String baseUrl = 'http://192.168.X.X:8000';  // ← Remplacez par votre IP

// Pour l'émulateur Android uniquement :
// static const String baseUrl = 'http://10.0.2.2:8000';
```

> ⚠️ **L'IP change si vous changez de réseau Wi-Fi.** Mettez-la à jour à chaque changement de réseau.

#### 4c. Installer les dépendances Flutter

```bash
flutter pub get
```

#### 4d. Lancer l'application sur un appareil physique

Connectez votre téléphone Android en USB (débogage USB activé), puis :

```bash
flutter devices          # Vérifier que le téléphone est détecté
flutter run              # Lancer l'application
```

**Hot Reload / Hot Restart (sans rebranchement USB) :**
- `r` — Hot Reload (rechargement rapide, conserve l'état)
- `R` — Hot Restart (redémarrage complet, réinitialise l'état)

---

### Étape 5 — Vérification Finale

| Test | Action | Résultat attendu |
|---|---|---|
| Backend actif | Ouvrir `http://<IP>:8000/docs` | Interface Swagger visible |
| Authentification | Se connecter avec `+221770000000` / `password123` | Tableau de bord affiché |
| Persistance | Créer un produit → redémarrer backend → vérifier | ✅ Produit toujours présent |
| Assistant vocal | Appuyer sur micro → "J'ai vendu 3 Coca à 500 FCFA" | ✅ Transaction créée (amount=1500) |
| Fallback IA | Vérifier les logs backend pendant le vocal | `[STT] ✓ Groq Whisper` et `[NLU] ✓ Groq LLaMA` |

---

## 🧪 Tests du Backend

Depuis le dossier `backend/` (avec le `.venv` activé) :

```bash
# Test de la chaîne de fallback STT + NLU (Groq, Gemini, OpenAI, Regex)
python test_fallback.py

# Test de l'assistant IA & logique métier (NLU, stock, création client)
python test_ai_logic.py

# Test de l'authentification JWT & isolation multi-utilisateur
python test_jwt_auth.py
```

**Résultat attendu de `test_fallback.py` :**
```
[1] Groq LLaMA   : OK type=SALE amount=1500.0 product=Coca-Cola qty=3.0
[2] Gemini Flash : OK type=SALE amount=1500.0 product=Coca-Cola qty=3.0
[4] Regex        : OK type=SALE amount=500.0  product=None      qty=3.0
```

---

## 🐛 Dépannage Courant

### Les données disparaissent au redémarrage
- Vérifiez que `DATABASE_URL` pointe vers PostgreSQL (pas SQLite).
- Vérifiez que le conteneur Docker PostgreSQL tourne : `docker ps`
- Relancez si nécessaire : `docker-compose up -d db`

### L'app mobile reçoit des erreurs `401 Unauthorized`
- La session a expiré ou le token JWT est invalide.
- **Solution :** Se déconnecter et se reconnecter dans l'app. Le token expiré est supprimé automatiquement.
- Vérifiez que `SECRET_KEY` est identique dans le `.env` entre les redémarrages.

### L'app mobile ne peut pas joindre le backend
- Vérifiez que l'IP dans `api_endpoints.dart` correspond à l'IP Wi-Fi **actuelle** de votre machine (`ipconfig`).
- Vérifiez que le backend tourne avec `--host 0.0.0.0` (et non `127.0.0.1`).
- Vérifiez que le téléphone et la machine sont sur le **même réseau Wi-Fi**.
- Vérifiez que le pare-feu Windows ne bloque pas le port `8000`.

### L'assistant vocal ne fonctionne pas / timeout
- Vérifiez que `GROQ_API_KEY` est défini dans `backend/.env`.
- Regardez les logs backend : `[STT]` et `[NLU]` indiquent quel moteur est utilisé.
- Si tous les moteurs cloud échouent, `faster-whisper` local prend le relais (plus lent ~5-8s, normal).
- Pour tester sans aucune API : activez `OPENAI_TRANSCRIPTION_MOCK=1` dans le `.env`.
- Vérifiez que l'autorisation microphone est accordée à l'app (Paramètres → Applications).

### Quota Groq épuisé (2000 req/jour dépassé)
- La chaîne bascule automatiquement vers Gemini Flash, puis OpenAI, puis faster-whisper local.
- Aucune action nécessaire, le fallback est automatique.

### Erreur `uvicorn: command not found`
- Assurez-vous que le virtualenv est activé : `.venv\Scripts\Activate.ps1`

### Erreur de connexion à PostgreSQL au démarrage
- Vérifiez que Docker tourne et que le conteneur est démarré.
- Relancez : `docker-compose up -d db`

---

## 🔑 Identifiants Infrastructure

> **Compte commerçant :** Créé via l'écran **Inscription** de l'application mobile. Aucun compte par défaut n'est pré-créé.

| Service | Champ | Valeur |
|---|---|---|
| **PgAdmin** | URL | `http://localhost:5050` |
| **PgAdmin** | Email | `admin@admin.com` |
| **PgAdmin** | Mot de passe | `admin` |
| **PostgreSQL** | Host | `localhost:5432` |
| **PostgreSQL** | Base de données | `commercant_db` |
| **PostgreSQL** | Utilisateur | `dev_user` |
| **PostgreSQL** | Mot de passe | `dev_password` |

---

## 🔑 Clés API à Créer (toutes gratuites)

| Service | Usage | Lien création | Tier gratuit |
|---|---|---|---|
| **Groq** | STT priorité 1 + NLU priorité 1 | [console.groq.com](https://console.groq.com) | 2000 req/jour STT, 6K tokens/min NLU |
| **Google Gemini** | NLU priorité 2 | [aistudio.google.com/apikey](https://aistudio.google.com/apikey) | 15 RPM |
| OpenAI | STT + NLU (fallback) | [platform.openai.com/api-keys](https://platform.openai.com/api-keys) | Payant (crédits) |
