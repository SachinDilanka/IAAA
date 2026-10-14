import json
from backend.models.db_models import Exercise, Child

# Letters for speech therapy: basic vowels and sounds
LETTERS = [
    {"sinhala_text": "අ", "instruction": "අ කියන්න. හොඳින් කට අරින්න.", "emoji": "🔤"},
    {"sinhala_text": "ආ", "instruction": "ආ කියන්න. ශබ්දය දිගු කර කියන්න.", "emoji": "🔤"},
    {"sinhala_text": "ඇ", "instruction": "ඇ කියන්න. ලස්සනට සිනාසෙන්න.", "emoji": "🔤"},
    {"sinhala_text": "ඈ", "instruction": "ඈ කියන්න. ශබ්දය දිගු කර කියන්න.", "emoji": "🔤"},
    {"sinhala_text": "ඉ", "instruction": "ඉ කියන්න. කට මඳක් විවෘත කරන්න.", "emoji": "🔤"},
    {"sinhala_text": "ඊ", "instruction": "ඊ කියන්න. දිගු ශබ්දයක්.", "emoji": "🔤"},
    {"sinhala_text": "උ", "instruction": "උ කියන්න. තොල් ඉදිරියට රවුම් කරන්න.", "emoji": "🔤"},
    {"sinhala_text": "ඌ", "instruction": "ඌ කියන්න. තොල් රවුම් කර දිගු කරන්න.", "emoji": "🔤"},
]

# 20 Child-friendly Sinhala words with step-by-step syllables
WORDS = [
    {"sinhala_text": "අම්මා", "breakdown": ["අ", "ම්", "මා", "අම්මා"], "instruction": "අ ... ම් ... මා ... අම්මා කියමු!", "emoji": "👩‍👧"},
    {"sinhala_text": "තාත්තා", "breakdown": ["තා", "ත්", "තා", "තාත්තා"], "instruction": "තා ... ත් ... තා ... තාත්තා කියමු!", "emoji": "👨‍👧"},
    {"sinhala_text": "ගස", "breakdown": ["ග", "ස", "ගස"], "instruction": "ග ... ස ... ගස කියමු!", "emoji": "🌳"},
    {"sinhala_text": "මල", "breakdown": ["ම", "ල", "මල"], "instruction": "ම ... ල ... මල කියමු!", "emoji": "🌸"},
    {"sinhala_text": "පොත", "breakdown": ["පො", "ත", "පොත"], "instruction": "පො ... ත ... පොත කියමු!", "emoji": "📖"},
    {"sinhala_text": "පාසල", "breakdown": ["පා", "ස", "ල", "පාසල"], "instruction": "පා ... ස ... ල ... පාසල කියමු!", "emoji": "🏫"},
    {"sinhala_text": "අලියා", "breakdown": ["අ", "ලි", "යා", "අලියා"], "instruction": "අ ... ලි ... යා ... අලියා කියමු!", "emoji": "🐘"},
    {"sinhala_text": "කිරි", "breakdown": ["කි", "රි", "කිරි"], "instruction": "කි ... රි ... කිරි කියමු!", "emoji": "🥛"},
    {"sinhala_text": "බල්ලා", "breakdown": ["බ", "ල්", "ලා", "බල්ලා"], "instruction": "බ ... ල් ... ලා ... බල්ලා කියමු!", "emoji": "🐕"},
    {"sinhala_text": "පූසා", "breakdown": ["පූ", "සා", "පූසා"], "instruction": "පූ ... සා ... පූසා කියමු!", "emoji": "🐈"},
    {"sinhala_text": "දොර", "breakdown": ["දො", "ර", "දොර"], "instruction": "දො ... ර ... දොර කියමු!", "emoji": "🚪"},
    {"sinhala_text": "තරුව", "breakdown": ["ත", "රු", "ව", "තරුව"], "instruction": "ත ... රු ... ව ... තරුව කියමු!", "emoji": "⭐"},
    {"sinhala_text": "හිරු", "breakdown": ["හි", "රු", "හිරු"], "instruction": "හි ... රු ... හිරු කියමු!", "emoji": "☀️"},
    {"sinhala_text": "සඳු", "breakdown": ["ස", "ඳු", "සඳු"], "instruction": "ස ... ඳු ... සඳු කියමු!", "emoji": "🌙"},
    {"sinhala_text": "වතුර", "breakdown": ["ව", "තු", "ර", "වතුර"], "instruction": "ව ... තු ... ර ... වතුර කියමු!", "emoji": "💧"},
    {"sinhala_text": "අත", "breakdown": ["අ", "ත", "අත"], "instruction": "අ ... ත ... අත කියමු!", "emoji": "✋"},
    {"sinhala_text": "කන", "breakdown": ["ක", "න", "කන"], "instruction": "ක ... න ... කන කියමු!", "emoji": "👂"},
    {"sinhala_text": "ඇස", "breakdown": ["ඇ", "ස", "ඇස"], "instruction": "ඇ ... ස ... ඇස කියමු!", "emoji": "👁️"},
    {"sinhala_text": "මුව", "breakdown": ["මු", "ව", "මුව"], "instruction": "මු ... ව ... මුව කියමු!", "emoji": "🦌"},
    {"sinhala_text": "බබා", "breakdown": ["බ", "බා", "බබා"], "instruction": "බ ... බා ... බබා කියමු!", "emoji": "👶"},
]

def seed_database(db):
    if db.query(Child).count() == 0:
        default_child = Child(name="සිඟිති දරුවා", age=4, avatar_id="tikiri", current_level="letters")
        db.add(default_child)
        db.commit()

    if db.query(Exercise).count() == 0:
        # Seed Letters
        for item in LETTERS:
            ex = Exercise(
                category="letter",
                sinhala_text=item["sinhala_text"],
                breakdown_json=json.dumps([item["sinhala_text"]], ensure_ascii=False),
                instruction_sinhala=item["instruction"],
                icon_emoji=item["emoji"],
                difficulty_level=1
            )
            db.add(ex)

        # Seed 20 Words
        for item in WORDS:
            ex = Exercise(
                category="word",
                sinhala_text=item["sinhala_text"],
                breakdown_json=json.dumps(item["breakdown"], ensure_ascii=False),
                instruction_sinhala=item["instruction"],
                icon_emoji=item["emoji"],
                difficulty_level=2
            )
            db.add(ex)

        db.commit()
