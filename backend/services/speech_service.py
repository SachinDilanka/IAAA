"""
SPEECH EVALUATION SERVICE
Provides phonetic verification and clinical feedback for Sinhala speech therapy exercises.
"""

class SpeechEvaluationService:
    @staticmethod
    def evaluate_pronunciation(target_text: str, spoken_text: str) -> dict:
        """
        Compares child's spoken text against target Sinhala letter/word.
        Returns accuracy score, matched status, and child-friendly feedback.
        """
        target = target_text.strip().lower()
        spoken = spoken_text.strip().lower()

        if not spoken:
            return {
                "is_correct": False,
                "score": 0.0,
                "feedback": "ශබ්දයක් ඇසුණේ නැත. නැවත උත්සාහ කරමු! 😊",
                "therapy_advice": "තත්පර 10 ඇතුළත කට හොඳින් විවෘත කර ශබ්දය නඟන්න."
            }

        # Exact match or substring match
        if target == spoken or target in spoken:
            return {
                "is_correct": True,
                "score": 100.0,
                "feedback": "ඉතා විශිෂ්ටයි! ඔයා හරිම දක්ෂයි! 🌟",
                "therapy_advice": "නිවැරදි උච්චාරණයකි."
            }

        # Simple character overlap ratio
        matches = sum(1 for c in target if c in spoken)
        score = round((matches / max(len(target), 1)) * 100.0, 1)

        if score >= 70.0:
            return {
                "is_correct": True,
                "score": score,
                "feedback": "හොඳ උත්සාහයක්! වචනය සම්පූර්ණයි! 👏",
                "therapy_advice": "පැහැදිලි ශබ්ද නිකුත් කිරීමක්."
            }
        else:
            return {
                "is_correct": False,
                "score": score,
                "feedback": "නැවත උත්සාහ කරමු! මගේ පස්සේ කියන්න! 👍",
                "therapy_advice": "අක්ෂර ශබ්දය නැවත සාවධානව අසා පුරුදු වන්න."
            }

speech_service = SpeechEvaluationService()
