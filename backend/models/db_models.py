from sqlalchemy import Column, Integer, String, Text, DateTime, ForeignKey
from sqlalchemy.sql import func
from backend.database import Base

class Child(Base):
    __tablename__ = "children"

    id = Column(Integer, primary_key=True, index=True)
    name = Column(String(100), nullable=False)
    age = Column(Integer, default=5)
    avatar_id = Column(String(50), default="tikiri")
    current_level = Column(String(50), default="letters")
    created_at = Column(DateTime(timezone=True), server_default=func.now())

class Exercise(Base):
    __tablename__ = "exercises"

    id = Column(Integer, primary_key=True, index=True)
    category = Column(String(50), nullable=False)  # 'letter', 'word'
    sinhala_text = Column(String(100), nullable=False)
    breakdown_json = Column(Text, nullable=True)  # JSON list: ["අ", "ම්", "මා", "අම්මා"]
    instruction_sinhala = Column(Text, nullable=False)  # "අ කියන්න"
    icon_emoji = Column(String(20), default="🌟")
    difficulty_level = Column(Integer, default=1)

class Attempt(Base):
    __tablename__ = "attempts"

    id = Column(Integer, primary_key=True, index=True)
    child_id = Column(Integer, ForeignKey("children.id"), nullable=False)
    exercise_id = Column(Integer, ForeignKey("exercises.id"), nullable=False)
    status = Column(String(50), default="completed")  # 'completed', 'in_progress'
    attempts_count = Column(Integer, default=1)
    stars_earned = Column(Integer, default=3)
    detected_emotion = Column(String(50), default="happy")
    session_date = Column(DateTime(timezone=True), server_default=func.now())
