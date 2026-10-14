from typing import List, Optional
from datetime import datetime
from pydantic import BaseModel

# -----------------------------------------------------------------------------
# Child Schemas
# -----------------------------------------------------------------------------
class ChildBase(BaseModel):
    name: str
    age: int = 5
    learning_level: str = "අකුරු මට්ටම (Letters)"
    avatar_name: str = "මිලී පැංචා (Mili)"

class ChildCreate(ChildBase):
    pass

class ChildResponse(ChildBase):
    id: int
    created_at: datetime

    class Config:
        from_attributes = True


# -----------------------------------------------------------------------------
# Exercise Schemas
# -----------------------------------------------------------------------------
class ExerciseBase(BaseModel):
    title: str
    sinhala_text: str
    exercise_type: str
    category: str
    ipa_transcription: Optional[str] = None
    english_meaning: Optional[str] = None
    emoji: Optional[str] = "⭐"
    syllables: Optional[List[str]] = []
    avatar_instruction: str
    phonological_note: Optional[str] = None
    order_num: int = 0

class ExerciseResponse(ExerciseBase):
    id: int

    class Config:
        from_attributes = True


# -----------------------------------------------------------------------------
# Attempt Schemas
# -----------------------------------------------------------------------------
class AttemptCreate(BaseModel):
    child_id: int
    exercise_id: int
    attempts_count: int = 1
    status: str = "Completed"
    score: float = 100.0
    feedback_note: Optional[str] = "හොඳ උත්සාහයක්! 👍"

class AttemptResponse(AttemptCreate):
    id: int
    created_at: datetime
    exercise_text: Optional[str] = None
    exercise_title: Optional[str] = None

    class Config:
        from_attributes = True


# -----------------------------------------------------------------------------
# Progress & Therapist Reports
# -----------------------------------------------------------------------------
class ProgressSummary(BaseModel):
    child_id: int
    child_name: str
    total_completed: int
    total_in_progress: int
    overall_progress_pct: float
    current_learning_level: str
    recent_attempts: List[AttemptResponse]
    clinical_patterns_summary: List[dict]
