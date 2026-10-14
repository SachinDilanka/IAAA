import json
from datetime import datetime
from sqlalchemy import Column, Integer, String, Float, DateTime, ForeignKey, Text
from sqlalchemy.orm import relationship
try:
    from backend.database import Base
except ImportError:
    from database import Base

class Child(Base):
    __tablename__ = "children"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    age = Column(Integer, default=5)
    learning_level = Column(String(50), default="අකුරු මට්ටම (Letters)")
    avatar_name = Column(String(50), default="මිලී පැංචා (Mili)")
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    attempts = relationship("Attempt", back_populates="child", cascade="all, delete-orphan")


class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    title = Column(String(100), nullable=False)
    sinhala_text = Column(String(100), nullable=False)
    exercise_type = Column(String(50), nullable=False) # 'letter', 'syllable', 'word_building', 'phonological_clinic'
    category = Column(String(50), default="general")   # 'vowel', 'consonant', 'basic_word', 'stopping', 'fronting', 'cluster_reduction', 'ipa'
    ipa_transcription = Column(String(50), nullable=True) # e.g., '/a/', '/amma/', '/kæt/'
    english_meaning = Column(String(100), nullable=True)
    emoji = Column(String(20), default="⭐")
    syllables_json = Column(Text, nullable=True)       # JSON string e.g. '["අ", "ම්", "මා"]'
    avatar_instruction = Column(String(255), nullable=False) # Sinhala prompt e.g. "අ කියන්න"
    phonological_note = Column(Text, nullable=True)     # Clinical note from Dr. Shyamani's notes
    order_num = Column(Integer, default=0)

    # Relationships
    attempts = relationship("Attempt", back_populates="exercise", cascade="all, delete-orphan")

    @property
    def syllables(self):
        if self.syllables_json:
            try:
                return json.loads(self.syllables_json)
            except Exception:
                return []
        return []


class Attempt(Base):
    __tablename__ = "attempts"

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False)
    exercise_id = Column(Integer, ForeignKey("exercises.id"), nullable=False)
    attempts_count = Column(Integer, default=1)
    status = Column(String(50), default="Completed") # 'Completed', 'In Progress', 'Needs Practice'
    score = Column(Float, default=100.0)             # Simple performance percentage
    feedback_note = Column(String(255), default="හොඳ උත්සාහයක්! 👍")
    created_at = Column(DateTime, default=datetime.utcnow)

    # Relationships
    child = relationship("Child", back_populates="attempts")
    exercise = relationship("Exercise", back_populates="attempts")
