from typing import List, Optional
from fastapi import APIRouter, Depends, HTTPException, Query
from sqlalchemy.orm import Session
from database import get_db
from models import Exercise
from schemas import ExerciseResponse

router = APIRouter(prefix="/api/exercises", tags=["Exercises"])

@router.get("", response_model=List[ExerciseResponse])
def get_exercises(
    exercise_type: Optional[str] = Query(None, description="Filter by type: letter, word_building, phonological_clinic"),
    category: Optional[str] = Query(None, description="Filter by category: vowel, consonant, basic_word, stopping, fronting, etc."),
    db: Session = Depends(get_db)
):
    """Retrieve exercises with optional filters."""
    query = db.query(Exercise).order_num if False else db.query(Exercise)
    if exercise_type:
        query = query.filter(Exercise.exercise_type == exercise_type)
    if category:
        query = query.filter(Exercise.category == category)
    
    exercises = query.order_by(Exercise.order_num.asc()).all()
    # Format response including dynamic syllables property
    result = []
    for ex in exercises:
        result.append(
            ExerciseResponse(
                id=ex.id,
                title=ex.title,
                sinhala_text=ex.sinhala_text,
                exercise_type=ex.exercise_type,
                category=ex.category,
                ipa_transcription=ex.ipa_transcription,
                english_meaning=ex.english_meaning,
                emoji=ex.emoji,
                syllables=ex.syllables,
                avatar_instruction=ex.avatar_instruction,
                phonological_note=ex.phonological_note,
                order_num=ex.order_num,
            )
        )
    return result

@router.get("/{exercise_id}", response_model=ExerciseResponse)
def get_exercise_by_id(exercise_id: int, db: Session = Depends(get_db)):
    """Retrieve details for a single speech exercise."""
    ex = db.query(Exercise).filter(Exercise.id == exercise_id).first()
    if not ex:
        raise HTTPException(status_code=404, detail="Exercise not found")
    return ExerciseResponse(
        id=ex.id,
        title=ex.title,
        sinhala_text=ex.sinhala_text,
        exercise_type=ex.exercise_type,
        category=ex.category,
        ipa_transcription=ex.ipa_transcription,
        english_meaning=ex.english_meaning,
        emoji=ex.emoji,
        syllables=ex.syllables,
        avatar_instruction=ex.avatar_instruction,
        phonological_note=ex.phonological_note,
        order_num=ex.order_num,
    )
