#!/usr/bin/env bash
# ==============================================================================
# ALTEN FDE LAB: Internal ATS Copilot - Repository Initializer (macOS / Linux)
# Compatible macOS 12 Monterey (bash 3.2 / zsh)
# ==============================================================================
set -euo pipefail

REPO_NAME="alten-internal-ats-copilot"

echo "🚀 Initializing FDE Lab Repository: ${REPO_NAME}..."

# --- Prérequis -----------------------------------------------------------------
if ! command -v git >/dev/null 2>&1; then
  echo "❌ git est introuvable. Installez les outils Xcode : xcode-select --install"
  exit 1
fi

if [ -e "${REPO_NAME}" ] && [ -n "$(ls -A "${REPO_NAME}" 2>/dev/null)" ]; then
  echo "❌ Le dossier ${REPO_NAME} existe déjà et n'est pas vide. Abandon."
  exit 1
fi

# --- 1. Dossier projet -----------------------------------------------------------
mkdir -p "${REPO_NAME}"
cd "${REPO_NAME}"

# --- 2. Git ------------------------------------------------------------------------
if [ ! -d ".git" ]; then
  if git init -b main >/dev/null 2>&1; then
    :
  else
    # Git < 2.28 ne supporte pas -b
    git init >/dev/null
    git checkout -b main >/dev/null 2>&1 || git symbolic-ref HEAD refs/heads/main
  fi
  echo "✅ Git repository initialized."
fi

# --- 3. Arborescence ---------------------------------------------------------------
echo "📁 Building directory structure..."
mkdir -p .github/workflows
mkdir -p data/resumes
mkdir -p data/job_descriptions
mkdir -p docs
mkdir -p src/parser
mkdir -p src/evaluator
mkdir -p src/api
mkdir -p tests

touch data/resumes/.gitkeep
touch data/job_descriptions/.gitkeep
touch docs/.gitkeep

# --- 4. requirements.txt -----------------------------------------------------------
cat << 'EOF' > requirements.txt
fastapi>=0.100.0
uvicorn>=0.22.0
pydantic>=2.0.0
pytest>=7.4.0
httpx>=0.24.0
python-dotenv>=1.0.0
EOF

# --- 5. .gitignore -----------------------------------------------------------------
cat << 'EOF' > .gitignore
# macOS
.DS_Store
.AppleDouble
.LSOverride

# Python
__pycache__/
*.py[cod]
*$py.class
.venv/
venv/
ENV/

# Environment variables
.env

# Testing
.pytest_cache/
.coverage
htmlcov/

# Local mock data (privacy)
data/resumes/*
!data/resumes/.gitkeep
data/job_descriptions/*
!data/job_descriptions/.gitkeep
EOF

# --- 6. pytest.ini (rend `src` importable) -------------------------------------------
cat << 'EOF' > pytest.ini
[pytest]
pythonpath = .
testpaths = tests
EOF

# --- 7. Modules Python ---------------------------------------------------------------
touch src/__init__.py
touch src/parser/__init__.py
touch src/evaluator/__init__.py
touch src/api/__init__.py
touch tests/__init__.py

cat << 'EOF' > src/parser/resume_parser.py
"""
Resume Parsing module for ALTEN ATS Copilot.
Extracts structured text and entities from CVs.
"""


def parse_resume(file_path: str) -> dict:
    """Mock parser to be implemented with LLM / structured outputs."""
    return {
        "candidate_name": "Sample Candidate",
        "skills": ["Python", "APIs", "Stakeholder Management"],
        "raw_text": "Sample content...",
    }
EOF

cat << 'EOF' > src/evaluator/matcher.py
"""
Matching Engine for ALTEN ATS Copilot.
Evaluates a candidate CV against FDE Job Description requirements.
"""


def evaluate_candidate(candidate_data: dict, job_description: str) -> dict:
    """Evaluates alignment, missing competencies, and generates a scorecard."""
    return {
        "match_score": 85,
        "key_strengths": ["Strong Python background", "Client-facing experience"],
        "gaps": ["Requires deeper Agentic framework experience"],
        "suggested_interview_questions": [
            "Can you describe a situation where you had to simplify an AI "
            "architecture for business stakeholders?"
        ],
    }
EOF

cat << 'EOF' > src/api/main.py
"""
REST API (FastAPI) for ATS / HR integration.
Run with: uvicorn src.api.main:app --reload
"""
from fastapi import FastAPI

from src.evaluator.matcher import evaluate_candidate
from src.parser.resume_parser import parse_resume

app = FastAPI(title="ALTEN ATS Copilot")


@app.get("/health")
def health() -> dict:
    return {"status": "ok"}


@app.post("/evaluate")
def evaluate(job_description: str = "") -> dict:
    parsed = parse_resume("dummy_path")
    return evaluate_candidate(parsed, job_description)
EOF

# --- 8. CI GitHub Actions --------------------------------------------------------------
cat << 'EOF' > .github/workflows/ci.yml
name: FDE Lab CI/CD Pipeline

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Set up Python
        uses: actions/setup-python@v5
        with:
          python-version: '3.10'
      - name: Install dependencies
        run: |
          python -m pip install --upgrade pip
          pip install -r requirements.txt
      - name: Run Pytest
        run: pytest
EOF

# --- 9. Tests ------------------------------------------------------------------------------
cat << 'EOF' > tests/test_evaluator.py
from src.evaluator.matcher import evaluate_candidate
from src.parser.resume_parser import parse_resume


def test_pipeline_basic_flow():
    parsed = parse_resume("dummy_path")
    result = evaluate_candidate(parsed, "dummy_jd")
    assert "match_score" in result
    assert result["match_score"] > 0
EOF

cat << 'EOF' > tests/test_api.py
from fastapi.testclient import TestClient

from src.api.main import app

client = TestClient(app)


def test_health():
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
EOF

# --- 10. README ------------------------------------------------------------------------------
cat << 'EOF' > README.md
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
EOF

# --- 11. Premier commit ------------------------------------------------------------------------
echo "📦 Executing first Git commit..."
if [ -z "$(git config user.name || true)" ] || [ -z "$(git config user.email || true)" ]; then
  echo "⚠️  Identité Git non configurée. Configurez-la puis committez :"
  echo "    git config --global user.name \"Votre Nom\""
  echo "    git config --global user.email \"vous@example.com\""
  echo "    git add . && git commit -m \"feat: initial commit\""
else
  git add .
  git commit -m "feat: initial commit - setup FDE ATS copilot lab structure, docs, and test suite" >/dev/null
  echo "✅ Commit initial créé."
fi

echo ""
echo "✅ macOS Setup complete!"
echo "👉 Next steps:"
echo "   cd ${REPO_NAME}"
echo "   python3 -m venv venv && source venv/bin/activate"
echo "   pip install -r requirements.txt && pytest"