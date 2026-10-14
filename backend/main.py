import os
from fastapi import FastAPI, Depends, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from sqlalchemy.orm import Session
from typing import List

from backend.database import engine, Base, get_db
from backend.models.db_models import Child, Exercise, Attempt
from backend.models.schemas import (
    ChildCreate, ChildUpdate, ChildResponse, ExerciseResponse,
    AttemptCreate, AttemptResponse, EmotionRequest, EmotionResponse
)
from backend.seed_data import seed_database
from backend.ml.emotion_classifier import emotion_detector

# Ensure database tables exist
Base.metadata.create_all(bind=engine)

# Seed database on startup
with next(get_db()) as db:
    seed_database(db)

app = FastAPI(title="Sinhala Speech Therapy for Children", version="1.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ----------------- Child Profile APIs -----------------
@app.get("/api/children", response_model=List[ChildResponse])
def get_children(db: Session = Depends(get_db)):
    return db.query(Child).all()

@app.post("/api/children", response_model=ChildResponse)
def create_child(child: ChildCreate, db: Session = Depends(get_db)):
    db_child = Child(name=child.name, age=child.age, avatar_id=child.avatar_id)
    db.add(db_child)
    db.commit()
    db.refresh(db_child)
    return db_child

@app.put("/api/children/{child_id}", response_model=ChildResponse)
def update_child(child_id: int, child: ChildUpdate, db: Session = Depends(get_db)):
    db_child = db.query(Child).filter(Child.id == child_id).first()
    if not db_child:
        raise HTTPException(status_code=404, detail="Child not found")

    db_child.name = child.name
    db_child.age = child.age
    db.commit()
    db.refresh(db_child)
    return db_child

# ----------------- Exercise APIs -----------------
@app.get("/api/exercises", response_model=List[ExerciseResponse])
def get_exercises(category: str = None, db: Session = Depends(get_db)):
    query = db.query(Exercise)
    if category:
        query = query.filter(Exercise.category == category)
    return query.all()

@app.get("/api/exercises/{exercise_id}", response_model=ExerciseResponse)
def get_exercise(exercise_id: int, db: Session = Depends(get_db)):
    ex = db.query(Exercise).filter(Exercise.id == exercise_id).first()
    if not ex:
        raise HTTPException(status_code=404, detail="Exercise not found")
    return ex

# ----------------- Attempts & Progress APIs -----------------
@app.post("/api/attempts", response_model=AttemptResponse)
def record_attempt(attempt: AttemptCreate, db: Session = Depends(get_db)):
    db_attempt = Attempt(
        child_id=attempt.child_id,
        exercise_id=attempt.exercise_id,
        status=attempt.status,
        attempts_count=attempt.attempts_count,
        stars_earned=attempt.stars_earned,
        detected_emotion=attempt.detected_emotion
    )
    db.add(db_attempt)
    db.commit()
    db.refresh(db_attempt)
    return db_attempt

@app.get("/api/progress/{child_id}")
def get_child_progress(child_id: int, db: Session = Depends(get_db)):
    attempts = db.query(Attempt).filter(Attempt.child_id == child_id).all()
    total_exercises = db.query(Exercise).count()
    completed_ids = set([a.exercise_id for a in attempts if a.status == "completed"])
    total_stars = sum([a.stars_earned for a in attempts])
    
    recent_history = []
    for att in reversed(attempts[-10:]):
        ex = db.query(Exercise).filter(Exercise.id == att.exercise_id).first()
        recent_history.append({
            "id": att.id,
            "sinhala_text": ex.sinhala_text if ex else "",
            "category": ex.category if ex else "",
            "status": att.status,
            "stars": att.stars_earned,
            "emotion": att.detected_emotion,
            "date": att.session_date.strftime("%Y-%m-%d %H:%M") if att.session_date else ""
        })

    percent = int((len(completed_ids) / total_exercises * 100)) if total_exercises > 0 else 0

    return {
        "child_id": child_id,
        "total_completed": len(completed_ids),
        "total_available": total_exercises,
        "progress_percent": percent,
        "total_stars": total_stars,
        "recent_history": recent_history
    }

# ----------------- Camera Emotion Analysis API -----------------
@app.post("/api/emotion/analyze", response_model=EmotionResponse)
def analyze_emotion(req: EmotionRequest):
    result = emotion_detector.analyze_frame(req.image_base64)
    return result

# ----------------- Frontend Static Files -----------------
frontend_path = os.path.join(os.path.dirname(__file__), "..", "frontend")
if os.path.exists(frontend_path):
    app.mount("/", StaticFiles(directory=frontend_path, html=True), name="frontend")
