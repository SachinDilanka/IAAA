from pydantic import BaseModel, Field, StringConstraints
from typing import Annotated, List, Optional
from datetime import datetime

ChildName = Annotated[str, StringConstraints(strip_whitespace=True, min_length=1, max_length=100)]

class ChildCreate(BaseModel):
    name: ChildName
    age: int = Field(default=5, ge=4, le=10)
    avatar_id: str = "tikiri"

class ChildUpdate(BaseModel):
    name: ChildName
    age: int = Field(ge=4, le=10)

class ChildResponse(BaseModel):
    id: int
    name: str
    age: int
    avatar_id: str
    current_level: str
    created_at: Optional[datetime] = None

    class Config:
        from_attributes = True

class ExerciseResponse(BaseModel):
    id: int
    category: str
    sinhala_text: str
    breakdown_json: Optional[str]
    instruction_sinhala: str
    icon_emoji: str
    difficulty_level: int

    class Config:
        from_attributes = True

class AttemptCreate(BaseModel):
    child_id: int
    exercise_id: int
    status: str = "completed"
    attempts_count: int = 1
    stars_earned: int = 3
    detected_emotion: Optional[str] = "happy"

class AttemptResponse(BaseModel):
    id: int
    child_id: int
    exercise_id: int
    status: str
    attempts_count: int
    stars_earned: int
    detected_emotion: Optional[str]
    session_date: Optional[datetime] = None

    class Config:
        from_attributes = True

class EmotionRequest(BaseModel):
    image_base64: str

class EmotionResponse(BaseModel):
    emotion: str
    sinhala_label: str
    feedback_sinhala: str
    confidence: float
