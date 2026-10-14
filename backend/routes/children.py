from typing import List
from fastapi import APIRouter, Depends, HTTPException
from sqlalchemy.orm import Session
from database import get_db
from models import Child
from schemas import ChildCreate, ChildResponse

router = APIRouter(prefix="/api/children", tags=["Children"])

@router.get("", response_model=List[ChildResponse])
def get_all_children(db: Session = Depends(get_db)):
    """Retrieve all registered children."""
    return db.query(Child).all()

@router.post("", response_model=ChildResponse)
def create_child(child: ChildCreate, db: Session = Depends(get_db)):
    """Register a new child profile."""
    new_child = Child(
        name=child.name,
        age=child.age,
        learning_level=child.learning_level,
        avatar_name=child.avatar_name,
    )
    db.add(new_child)
    db.commit()
    db.refresh(new_child)
    return new_child

@router.get("/{child_id}", response_model=ChildResponse)
def get_child(child_id: int, db: Session = Depends(get_db)):
    """Retrieve a single child by ID."""
    child = db.query(Child).filter(Child.id == child_id).first()
    if not child:
        raise HTTPException(status_code=404, detail="Child profile not found")
    return child
