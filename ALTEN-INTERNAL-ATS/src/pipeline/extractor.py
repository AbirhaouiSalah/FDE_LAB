# src/pipeline/extractor.py
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
        """Removes excessive whitespace, non-breaking spaces, and artifacts line by line."""
        text = text.replace("\xa0", " ")
        
        # Clean line by line to strip trailing/leading spaces per line
        lines = [re.sub(r'[ \t]+', ' ', line).strip() for line in text.splitlines()]
        
        # Filter out excessive consecutive blank lines
        cleaned_lines = []
        for line in lines:
            if line or (cleaned_lines and cleaned_lines[-1] != ""):
                cleaned_lines.append(line)
                
        joined = "\n".join(cleaned_lines)
        # Collapse 3 or more newlines down to 2
        joined = re.sub(r'\n{3,}', '\n\n', joined)
        
        return joined.strip()