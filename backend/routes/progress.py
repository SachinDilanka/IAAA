from typing import List
from datetime import datetime
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Child, Exercise, Attempt
from schemas import AttemptCreate, AttemptResponse, ProgressSummary

router = APIRouter(prefix="/api", tags=["Progress & Attempts"])

@router.post("/attempts", response_model=AttemptResponse)
def record_attempt(attempt_data: AttemptCreate, db: Session = Depends(get_db)):
    """Records an attempt by a child on a specific exercise."""
    child = db.query(Child).filter(Child.id == attempt_data.child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")

    exercise = db.query(Exercise).filter(Exercise.id == attempt_data.exercise_id).first()
    if not exercise:
        raise HTTPException(status_code=404, detail="Exercise not found")

    # Check if there is an existing attempt record
    existing = db.query(Attempt).filter(
        Attempt.child_id == attempt_data.child_id,
        Attempt.exercise_id == attempt_data.exercise_id
    ).first()

    if existing:
        existing.attempts_count += 1
        existing.status = attempt_data.status
        existing.score = attempt_data.score
        existing.feedback_note = attempt_data.feedback_note
        existing.created_at = datetime.utcnow()
        db.commit()
        db.refresh(existing)
        return AttemptResponse(
            id=existing.id,
            child_id=existing.child_id,
            exercise_id=existing.exercise_id,
            attempts_count=existing.attempts_count,
            status=existing.status,
            score=existing.score,
            feedback_note=existing.feedback_note,
            created_at=existing.created_at,
            exercise_text=exercise.sinhala_text,
            exercise_title=exercise.title,
        )

    new_attempt = Attempt(
        child_id=attempt_data.child_id,
        exercise_id=attempt_data.exercise_id,
        attempts_count=attempt_data.attempts_count,
        status=attempt_data.status,
        score=attempt_data.score,
        feedback_note=attempt_data.feedback_note,
    )
    db.add(new_attempt)
    db.commit()
    db.refresh(new_attempt)

    return AttemptResponse(
        id=new_attempt.id,
        child_id=new_attempt.child_id,
        exercise_id=new_attempt.exercise_id,
        attempts_count=new_attempt.attempts_count,
        status=new_attempt.status,
        score=new_attempt.score,
        feedback_note=new_attempt.feedback_note,
        created_at=new_attempt.created_at,
        exercise_text=exercise.sinhala_text,
        exercise_title=exercise.title,
    )


@router.get("/progress/{child_id}", response_model=ProgressSummary)
def get_child_progress(child_id: int, db: Session = Depends(get_db)):
    """Provides progress summary for the child dashboard and progress page."""
    child = db.query(Child).filter(Child.id == child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")

    total_exercises = db.query(Exercise).count()
    attempts = db.query(Attempt).filter(Attempt.child_id == child_id).all()

    completed_count = sum(1 for a in attempts if a.status == "Completed")
    in_progress_count = sum(1 for a in attempts if a.status == "In Progress")

    overall_pct = (completed_count / total_exercises * 100.0) if total_exercises > 0 else 0.0

    recent_attempts_list = []
    for a in sorted(attempts, key=lambda x: x.created_at, reverse=True)[:10]:
        ex = a.exercise
        recent_attempts_list.append(
            AttemptResponse(
                id=a.id,
                child_id=a.child_id,
                exercise_id=a.exercise_id,
                attempts_count=a.attempts_count,
                status=a.status,
                score=a.score,
                feedback_note=a.feedback_note,
                created_at=a.created_at,
                exercise_text=ex.sinhala_text if ex else "",
                exercise_title=ex.title if ex else "",
            )
        )

    # Phonological Process metrics summary for SLT monitoring
    categories = ["stopping", "fronting", "cluster_reduction", "weak_syllable_deletion", "basic_word", "vowel", "consonant"]
    patterns_summary = []
    for cat in categories:
        cat_exercises = db.query(Exercise).filter(Exercise.category == cat).all()
        cat_ids = [e.id for e in cat_exercises]
        if not cat_ids:
            continue
        cat_attempts = [a for a in attempts if a.exercise_id in cat_ids]
        cat_completed = sum(1 for a in cat_attempts if a.status == "Completed")
        patterns_summary.append({
            "category": cat,
            "total_targets": len(cat_ids),
            "completed": cat_completed,
            "pct": round((cat_completed / len(cat_ids) * 100.0), 1) if cat_ids else 0.0
        })

    return ProgressSummary(
        child_id=child.id,
        child_name=child.name,
        total_completed=completed_count,
        total_in_progress=in_progress_count,
        overall_progress_pct=round(overall_pct, 1),
        current_learning_level=child.learning_level,
        recent_attempts=recent_attempts_list,
        clinical_patterns_summary=patterns_summary,
    )


@router.get("/therapist/report/{child_id}")
def get_therapist_detailed_report(child_id: int, db: Session = Depends(get_db)):
    """Provides detailed clinical analysis for Speech-Language Therapists and Parents."""
    child = db.query(Child).filter(Child.id == child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child not found")

    attempts = db.query(Attempt).filter(Attempt.child_id == child_id).all()
    all_exercises = db.query(Exercise).all()

    report_items = []
    for ex in all_exercises:
        att = next((a for a in attempts if a.exercise_id == ex.id), None)
        report_items.append({
            "exercise_id": ex.id,
            "title": ex.title,
            "sinhala_text": ex.sinhala_text,
            "category": ex.category,
            "ipa": ex.ipa_transcription,
            "clinical_note": ex.phonological_note,
            "attempts": att.attempts_count if att else 0,
            "status": att.status if att else "Not Attempted",
            "score": att.score if att else 0.0,
            "last_practiced": att.created_at.strftime("%Y-%m-%d %H:%M") if att else "-",
        })

    return {
        "child": {
            "id": child.id,
            "name": child.name,
            "age": child.age,
            "level": child.learning_level,
        },
        "total_targets": len(all_exercises),
        "targets_evaluated": report_items,
        "clinical_recommendation": (
            "Continue step-by-step syllable assembly exercises. For children exhibiting velar fronting "
            "or stopping of fricatives, encourage gentle auditory discrimination using the Avatar before repetition."
        )
    }
