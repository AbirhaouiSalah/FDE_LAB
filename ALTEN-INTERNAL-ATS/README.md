# ALTEN Internal ATS Copilot 🤖💼

**Lab FDE (Forward Deployed Engineer) – Cas d'usage IA pour les Fonctions Support (RH)**

Projet de cadrage, prototypage rapide et évaluation automatisée des candidatures pour la cellule FDE ALTEN.

## 🎯 Contexte & Enjeux Métier

Dans le cadre de l'accélération de l'usage de l'IA chez ALTEN, la DSI Groupe et le Chief AI Officer constituent une équipe de Forward Deployed Engineers (FDE). L'un des projets prioritaires pour les fonctions support (RH) consiste à optimiser le recrutement et l'évaluation des profils techniques complexes (FDE, Solution Architects, DevOps).

**Points de friction identifiés :**

1. **Volumétrie & temps de qualification** : screening manuel chronophage de CVs à forte technicité.
2. **Alignement Métier / Tech** : évaluation délicate des profils hybrides (Python/API + posture de consultant terrain).
3. **Expérience recruteur** : besoin de grilles d'entretien automatisées et objectives pour accélérer le Time-to-Hire.

## 💡 Solution Proposée : ATS Copilot

Un assistant agentique qui s'intègre au système ATS interne pour :

1. **Parser & structurer** les CVs reçus.
2. **Évaluer & scorer** l'adéquation candidat / fiche de poste via RAG et prompt engineering structuré.
3. **Générer une fiche de synthèse** pour le recruteur : score de matching, skill gaps, grille de questions d'entretien.

## 🏗️ Architecture du Projet

```
alten-internal-ats-copilot/
├── .github/workflows/    # Pipeline CI/CD (Pytest)
├── data/                 # Données de test (CVs anonymisés, fiches de poste)
├── docs/                 # Cadrage FDE, notes d'ateliers RH et KPIs
├── src/
│   ├── parser/           # Extraction structurée (PDF/Texte)
│   ├── evaluator/        # Moteur d'évaluation RAG & Agent LLM
│   └── api/              # API REST FastAPI pour intégration ATS/RH
├── tests/                # Tests unitaires Pytest
├── requirements.txt
└── README.md
```

## 🛠️ Stack Technique

- **Langage** : Python 3.10+
- **Agent / LLM** : Agentic RAG, Prompt Engineering (Pydantic / OpenAI / Mistral)
- **API** : FastAPI, endpoints REST
- **Qualité & CI/CD** : Pytest, GitHub Actions

## 🚀 Démarrage Rapide

```bash
git clone https://github.com/votre-user/alten-internal-ats-copilot.git
cd alten-internal-ats-copilot

python3 -m venv venv
source venv/bin/activate
pip install -r requirements.txt
pytest

# Lancer l'API
uvicorn src.api.main:app --reload
```

---
Projet réalisé par Salah-Eddine ABIRHAOUI - Candidature Forward Deployed Engineer (FDE) chez ALTEN.
