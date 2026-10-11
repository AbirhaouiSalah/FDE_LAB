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
