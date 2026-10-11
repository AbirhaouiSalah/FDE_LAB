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
