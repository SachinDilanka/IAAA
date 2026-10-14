"""
FER-2013 Facial Emotion Recognition API Route
Handles real-time webcam frame emotion detection requests.
"""

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel
from typing import Optional
from services.emotion_service import emotion_service

router = APIRouter(prefix="/api", tags=["Emotion Recognition"])

class EmotionDetectRequest(BaseModel):
    image_base64: str
    child_id: Optional[int] = 1

class EmotionDetectResponse(BaseModel):
    emotion: str
    sinhala: str
    emoji: str
    confidence: float
    advice: str

@router.post("/detect_emotion", response_model=EmotionDetectResponse)
def detect_emotion(payload: EmotionDetectRequest):
    """
    Analyzes child webcam frame and returns predicted facial emotion (FER-2013)
    along with Sinhala label and clinical therapy advice.
    """
    try:
        result = emotion_service.predict_from_base64(payload.image_base64)
        return EmotionDetectResponse(
            emotion=result["emotion"],
            sinhala=result["sinhala"],
            emoji=result["emoji"],
            confidence=result["confidence"],
            advice=result["advice"]
        )
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Emotion detection error: {str(e)}")
