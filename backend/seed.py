"""
Seed the backend database with all default locations, categories, and messages.
Run from research/ with:  python backend/seed.py
"""
import sys, os
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app, db
from app.models.location import LocationType
from app.models.category import Category
from app.models.message import Message

def seed_database():
    app = create_app()
    with app.app_context():
        db.drop_all()
        db.create_all()
        print("Seeding database …")

        data = [
            {
                "name": "Hospital & Health",
                "slug": "hospital",
                "icon": "fa-hospital",
                "description": "Emergency care, appointments, doctor visits and medical directions.",
                "osm_tags": "amenity=hospital,amenity=clinic",
                "display_order": 1,
                "categories": [
                    {
                        "name": "Emergency & Urgent",
                        "slug": "emergency",
                        "icon": "fa-truck-medical",
                        "display_order": 1,
                        "messages": [
                            {"template": "I need emergency care immediately.", "icon": "fa-triangle-exclamation", "priority": 10},
                            {"template": "I need urgent medical help.", "icon": "fa-hand-holding-medical", "priority": 9},
                            {"template": "Where is the emergency department?", "icon": "fa-location-dot", "priority": 8},
                        ]
                    },
                    {
                        "name": "Appointments & Check-in",
                        "slug": "appointments",
                        "icon": "fa-calendar-check",
                        "display_order": 2,
                        "messages": [
                            {"template": "I have an appointment scheduled.", "icon": "fa-clipboard-user", "priority": 5},
                            {"template": "I am here for a routine check-up.", "icon": "fa-notes-medical", "priority": 4},
                            {"template": "I need to check in at reception.", "icon": "fa-id-card", "priority": 3},
                        ]
                    },
                    {
                        "name": "Doctor & Symptoms",
                        "slug": "doctor-symptoms",
                        "icon": "fa-user-doctor",
                        "display_order": 3,
                        "messages": [
                            {"template": "I need to see a doctor.", "icon": "fa-user-doctor", "priority": 5},
                            {"template": "I need to explain my symptoms.", "icon": "fa-comment-medical", "priority": 4},
                            {"template": "I need a sign language interpreter if available.", "icon": "fa-hands-asl-interpreting", "priority": 3},
                        ]
                    },
                    {
                        "name": "Directions & Facilities",
                        "slug": "hospital-directions",
                        "icon": "fa-compass",
                        "display_order": 4,
                        "messages": [
                            {"template": "Where is the hospital pharmacy?", "icon": "fa-prescription-bottle-medical", "priority": 5},
                            {"template": "Where is the radiology / X-ray department?", "icon": "fa-x-ray", "priority": 4},
                            {"template": "Where is the restroom?", "icon": "fa-restroom", "priority": 3},
                        ]
                    },
                ]
            },
            {
                "name": "Restaurant & Dining",
                "slug": "restaurant",
                "icon": "fa-utensils",
                "description": "Ordering meals, specifying food allergies, and requesting the bill.",
                "osm_tags": "amenity=restaurant,amenity=fast_food,amenity=cafe",
                "display_order": 2,
                "categories": [
                    {
                        "name": "Ordering Food",
                        "slug": "ordering",
                        "icon": "fa-bowl-food",
                        "display_order": 1,
                        "messages": [
                            {"template": "Can I see the menu, please?", "icon": "fa-book-open", "priority": 10},
                            {"template": "I am ready to order.", "icon": "fa-circle-check", "priority": 9},
                            {"template": "I would like to order pasta.", "icon": "fa-plate-wheat", "priority": 8},
                            {"template": "I would like to order rice.", "icon": "fa-bowl-rice", "priority": 7},
                            {"template": "I would like a glass of water, please.", "icon": "fa-glass-water", "priority": 6},
                        ]
                    },
                    {
                        "name": "Allergies & Preferences",
                        "slug": "allergies-prefs",
                        "icon": "fa-wheat-awn-circle-exclamation",
                        "display_order": 2,
                        "messages": [
                            {"template": "I have a food allergy.", "icon": "fa-shield-halved", "priority": 5},
                            {"template": "I would like to change my order.", "icon": "fa-pen-to-square", "priority": 4},
                            {"template": "Is this dish vegetarian / vegan?", "icon": "fa-seedling", "priority": 3},
                        ]
                    },
                    {
                        "name": "Payment & Service",
                        "slug": "restaurant-payment",
                        "icon": "fa-receipt",
                        "display_order": 3,
                        "messages": [
                            {"template": "Can I have the bill, please?", "icon": "fa-credit-card", "priority": 5},
                            {"template": "Are card payments accepted?", "icon": "fa-wallet", "priority": 4},
                            {"template": "Thank you, the food was great!", "icon": "fa-thumbs-up", "priority": 3},
                        ]
                    },
                ]
            },
            {
                "name": "Supermarket & Stores",
                "slug": "supermarket",
                "icon": "fa-cart-shopping",
                "description": "Finding products, grocery sections, assistance, and checkout.",
                "osm_tags": "shop=supermarket,shop=grocery",
                "display_order": 3,
                "categories": [
                    {
                        "name": "Finding Products",
                        "slug": "finding-products",
                        "icon": "fa-magnifying-glass",
                        "display_order": 1,
                        "messages": [
                            {"template": "I need to buy groceries.", "icon": "fa-basket-shopping", "priority": 10},
                            {"template": "Where can I find this item?", "icon": "fa-location-dot", "priority": 9},
                            {"template": "I need help finding a product.", "icon": "fa-handshake-angle", "priority": 8},
                            {"template": "I need this item: {slot}", "has_slot": True, "slot_placeholder": "e.g. Milk, Eggs, Bread", "icon": "fa-pen-to-square", "priority": 7},
                        ]
                    },
                    {
                        "name": "Aisles & Sections",
                        "slug": "sections",
                        "icon": "fa-layer-group",
                        "display_order": 2,
                        "messages": [
                            {"template": "Where is the dairy section?", "icon": "fa-cow", "priority": 5},
                            {"template": "Where can I find fresh vegetables?", "icon": "fa-carrot", "priority": 4},
                            {"template": "Where can I find bakery / bread?", "icon": "fa-bread-slice", "priority": 3},
                        ]
                    },
                    {
                        "name": "Pricing & Checkout",
                        "slug": "checkout-pricing",
                        "icon": "fa-cash-register",
                        "display_order": 3,
                        "messages": [
                            {"template": "How much does this cost?", "icon": "fa-tag", "priority": 5},
                            {"template": "Where is the checkout counter?", "icon": "fa-cash-register", "priority": 4},
                        ]
                    },
                ]
            },
            {
                "name": "Pharmacy",
                "slug": "pharmacy",
                "icon": "fa-prescription-bottle-medical",
                "description": "Prescriptions, over-the-counter medicine and health supplies.",
                "osm_tags": "amenity=pharmacy",
                "display_order": 4,
                "categories": [
                    {
                        "name": "Prescriptions",
                        "slug": "prescriptions",
                        "icon": "fa-file-prescription",
                        "display_order": 1,
                        "messages": [
                            {"template": "I need to collect my prescription.", "icon": "fa-file-medical", "priority": 5},
                            {"template": "I need medicine for a cold / fever.", "icon": "fa-thermometer", "priority": 4},
                            {"template": "Do I need a doctor's prescription for this?", "icon": "fa-circle-question", "priority": 3},
                        ]
                    },
                    {
                        "name": "Supplies & Dosage",
                        "slug": "supplies",
                        "icon": "fa-kit-medical",
                        "display_order": 2,
                        "messages": [
                            {"template": "Where can I find first aid supplies?", "icon": "fa-band-aid", "priority": 5},
                            {"template": "Can you write down the dosage instructions?", "icon": "fa-pen", "priority": 4},
                        ]
                    },
                ]
            },
            {
                "name": "Bank & Finance",
                "slug": "bank",
                "icon": "fa-building-columns",
                "description": "Account inquiries, deposits, withdrawals and ATM directions.",
                "osm_tags": "amenity=bank,amenity=atm",
                "display_order": 5,
                "categories": [
                    {
                        "name": "Counter Services",
                        "slug": "bank-counter",
                        "icon": "fa-vault",
                        "display_order": 1,
                        "messages": [
                            {"template": "I need to deposit money into my account.", "icon": "fa-money-bill-trend-up", "priority": 5},
                            {"template": "I need to withdraw cash.", "icon": "fa-money-bill-transfer", "priority": 4},
                            {"template": "I need to speak with a customer service agent.", "icon": "fa-user-tie", "priority": 3},
                        ]
                    },
                    {
                        "name": "ATM & Cards",
                        "slug": "atm-cards",
                        "icon": "fa-credit-card",
                        "display_order": 2,
                        "messages": [
                            {"template": "Where is the nearest ATM?", "icon": "fa-cash-register", "priority": 5},
                            {"template": "I need assistance with my card.", "icon": "fa-triangle-exclamation", "priority": 4},
                        ]
                    },
                ]
            },
            {
                "name": "General Assistance",
                "slug": "other",
                "icon": "fa-comments",
                "description": "General communication messages for any public place.",
                "osm_tags": "",
                "display_order": 6,
                "categories": [
                    {
                        "name": "Basic Interaction",
                        "slug": "basic-interaction",
                        "icon": "fa-hands",
                        "display_order": 1,
                        "messages": [
                            {"template": "Excuse me, I am deaf / non-verbal.", "icon": "fa-ear-deaf", "priority": 10},
                            {"template": "Can you please write your response down for me?", "icon": "fa-pen-clip", "priority": 9},
                            {"template": "Thank you for your patience and help!", "icon": "fa-heart", "priority": 8},
                            {"template": "Where is the nearest exit / restroom?", "icon": "fa-door-open", "priority": 7},
                        ]
                    },
                ]
            },
        ]

        for loc_data in data:
            cats = loc_data.pop("categories")
            loc = LocationType(**loc_data)
            db.session.add(loc)
            db.session.flush()
            for cat_data in cats:
                msgs = cat_data.pop("messages")
                cat_data["location_type_id"] = loc.id
                cat = Category(**cat_data)
                db.session.add(cat)
                db.session.flush()
                for msg_data in msgs:
                    msg_data["category_id"] = cat.id
                    db.session.add(Message(**msg_data))

        db.session.commit()
        print("Database seeded successfully!")

if __name__ == "__main__":
    seed_database()
