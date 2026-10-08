from flask import Blueprint, render_template
from app.services.sample_data import get_sample_locations

main_bp = Blueprint('main', __name__)

@main_bp.route('/')
def index():
    locations = get_sample_locations()
    return render_template('index.html', locations=locations)

@main_bp.route('/mobile')
@main_bp.route('/mobile/<slug>')
def mobile_view(slug='hospital'):
    wireframe_hospital_messages = [
        {"template": "I have an appointment", "icon": "fa-calendar-check"},
        {"template": "I need to see a doctor", "icon": "fa-user-doctor"},
        {"template": "I need emergency assistance", "icon": "fa-triangle-exclamation"},
        {"template": "Where is the pharmacy?", "icon": "fa-prescription-bottle-medical"},
        {"template": "Where is the restroom?", "icon": "fa-restroom"},
        {"template": "I need a wheelchair", "icon": "fa-wheelchair"},
    ]

    location_name = "Hospital"
    messages = wireframe_hospital_messages

    if slug == 'restaurant':
        location_name = "Restaurant"
        messages = [
            {"template": "Can I see the menu, please?", "icon": "fa-book-open"},
            {"template": "I am ready to order", "icon": "fa-circle-check"},
            {"template": "I would like a glass of water", "icon": "fa-glass-water"},
            {"template": "Where is the restroom?", "icon": "fa-restroom"},
            {"template": "I have a food allergy", "icon": "fa-shield-halved"},
            {"template": "Can I have the bill, please?", "icon": "fa-receipt"}
        ]
    elif slug == 'supermarket':
        location_name = "Supermarket"
        messages = [
            {"template": "Where can I find groceries?", "icon": "fa-cart-shopping"},
            {"template": "How much does this cost?", "icon": "fa-tag"},
            {"template": "Where is the checkout counter?", "icon": "fa-cash-register"},
            {"template": "Can you help me reach this item?", "icon": "fa-hand"},
            {"template": "Where is the restroom?", "icon": "fa-restroom"},
            {"template": "Do you have fresh produce?", "icon": "fa-apple-whole"}
        ]

    return render_template('mobile.html', location_slug=slug, location_name=location_name, messages=messages)

