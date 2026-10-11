#!/usr/bin/env bash
set -e

echo "🚀 Initializing alten-internal-ats-copilot repository structure..."

# 1. Create directories
mkdir -p src/pipeline
mkdir -p src/api
mkdir -p tests/fixtures/raw_resumes
mkdir -p tests/fixtures/processed_json

echo "📂 Created directory structure."

# 2. Create requirements.txt
cat << 'EOF' > requirements.txt
pydantic>=2.0.0
pypdf>=3.0.0
fastapi>=0.100.0
uvicorn>=0.20.0
pytest>=7.0.0
pytest-mock>=3.10.0
EOF

# 3. Create src/pipeline/__init__.py
touch src/pipeline/__init__.py

# 4. Create src/pipeline/schemas.py
cat << 'EOF' > src/pipeline/schemas.py
from typing import List, Optional
from pydantic import BaseModel, Field

class ExperienceItem(BaseModel):
    company: str = Field(..., description="Company name")
    role: str = Field(..., description="Job title / position")
    duration: str = Field(..., description="Start and end dates (e.g., '2022 - Present')")
    description: List[str] = Field(default_factory=list, description="Key achievements or responsibilities")

class EducationItem(BaseModel):
    institution: str = Field(..., description="University or school name")
    degree: str = Field(..., description="Degree obtained (e.g., Master, Engineering Degree)")
    field_of_study: Optional[str] = Field(None, description="Field of study or major")
    graduation_year: Optional[str] = Field(None, description="Year of graduation")

class CandidateProfile(BaseModel):
    full_name: str = Field(..., description="Candidate's full name")
    email: Optional[str] = Field(None, description="Contact email")
    phone: Optional[str] = Field(None, description="Contact phone number")
    location: Optional[str] = Field(None, description="City, Country")
    summary: Optional[str] = Field(None, description="Professional summary or bio")
    skills: List[str] = Field(default_factory=list, description="Extracted technical and soft skills")
    experience: List[ExperienceItem] = Field(default_factory=list)
    education: List[EducationItem] = Field(default_factory=list)
    source_file: str = Field(..., description="Original PDF file name")
EOF

# 5. Create src/pipeline/extractor.py
cat << 'EOF' > src/pipeline/extractor.py
import re
from pathlib import Path
from pypdf import PdfReader

class PDFResumeExtractor:
    @staticmethod
    def extractor_text(pdf_path: Path) -> str:
        """Alias for backward compatibility."""
        return PDFResumeExtractor.extract_text(pdf_path)

    @staticmethod
    def extract_text(pdf_path: Path) -> str:
        """Extracts and cleans raw text from a PDF resume."""
        if not pdf_path.exists():
            raise FileNotFoundError(f"PDF file not found: {pdf_path}")
            
        reader = PdfReader(str(pdf_path))
        raw_text = ""
        
        for page in reader.pages:
            text = page.extract_text()
            if text:
                raw_text += text + "\n"
                
        return PDFResumeExtractor._clean_text(raw_text)

    @staticmethod
    def _clean_text(text: str) -> str:
        """Removes excessive whitespace, non-breaking spaces, and artifacts."""
        text = text.replace("\xa0", " ")
        text = re.sub(r'[ \t]+', ' ', text)
        text = re.sub(r'\n\s*\n', '\n\n', text)
        return text.strip()
EOF

# 6. Create src/pipeline/runner.py
cat << 'EOF' > src/pipeline/runner.py
import json
from pathlib import Path
from src.pipeline.extractor import PDFResumeExtractor
from src.pipeline.schemas import CandidateProfile

def process_resume_dataset(input_dir: str, output_dir: str):
    """Batch process raw PDF resumes into preformatted JSON files."""
    in_path = Path(input_dir)
    out_path = Path(output_dir)
    out_path.mkdir(parents=True, exist_ok=True)
    
    pdf_files = list(in_path.glob("*.pdf"))
    print(f"Found {len(pdf_files)} PDF resumes to process in {input_dir}.")
    
    if not pdf_files:
        print("⚠️ No PDF files found in input directory. Drop a sample PDF into tests/fixtures/raw_resumes/ to test!")
        return
    
    for pdf_file in pdf_files:
        try:
            print(f"Processing: {pdf_file.name}...")
            clean_text = PDFResumeExtractor.extract_text(pdf_file)
            
            # Stub mock profile for baseline pipeline verification
            mock_profile = CandidateProfile(
                full_name="Jane Doe",
                email="jane.doe@example.com",
                phone="+33612345678",
                location="Paris, France",
                summary="Forward Deployed Engineer with experience in cloud architectures...",
                skills=["Python", "FastAPI", "Docker", "Kubernetes"],
                source_file=pdf_file.name
            )
            
            output_file = out_path / f"{pdf_file.stem}.json"
            with open(output_file, "w", encoding="utf-8") as f:
                f.write(mock_profile.model_dump_json(indent=2))
                
            print(f"Successfully converted -> {output_file.name}")
            
        except Exception as e:
            print(f"Error processing {pdf_file.name}: {str(e)}")

if __name__ == "__main__":
    process_resume_dataset(
        input_dir="tests/fixtures/raw_resumes",
        output_dir="tests/fixtures/processed_json"
    )
EOF

echo "✨ All components generated successfully under src/ and requirements.txt!"
echo "👉 Run the following commands to test:"
echo "   pip install -r requirements.txt"
echo "   python -m src.pipeline.runner"