from flask import Blueprint, render_template, request, redirect, url_for
from app.services.message_service import get_all_locations, get_location_messages, get_location_by_slug

views_bp = Blueprint('views', __name__)

@views_bp.route('/')
def index():
    locations = get_all_locations()
    if not locations:
        try:
            from app.services.sample_data import get_sample_locations
            locations = get_sample_locations()
        except ImportError:
            pass
    return render_template('index.html', locations=locations)


@views_bp.route('/location/<slug>')
def location_dashboard(slug):
    search = request.args.get('q', '').strip()
    data = get_location_messages(slug, search_query=search if search else None)
    if not data:
        return redirect(url_for('views.index'))
    return render_template('location.html', location=data['location'], categories_with_messages=data['categories_with_messages'], search_query=search)

@views_bp.route('/show')
def show_card():
    message_text = request.args.get('text', 'No message content provided.').strip()
    icon = request.args.get('icon', 'fa-comment')
    location_slug = request.args.get('location', 'other')
    return render_template('card_view.html', message_text=message_text, icon=icon, location_slug=location_slug)

from app.services.geo_service import LOCATION_PRESETS

PREDEFINED_MOBILE_CONFIG = LOCATION_PRESETS

@views_bp.route('/mobile')
@views_bp.route('/mobile/<slug>')
def mobile_view(slug=None):
    auto_detect = False
    if not slug:
        slug = request.args.get('location', '').strip().lower()
        if not slug:
            # Single interface entry: wait for GPS to detect hospital before suggesting messages
            slug = 'other'
            auto_detect = True
    else:
        slug = slug.lower()

    cfg = LOCATION_PRESETS.get(slug, LOCATION_PRESETS.get('other', {}))
    location_name = 'Detecting Location...' if auto_detect else cfg.get('short_name', 'Location')
    badge_icon = cfg.get('badge_icon', 'fa-location-dot')
    theme_color = cfg.get('theme_color', '#6366f1')
    bg_color = cfg.get('bg_color', '#e0e7ff')
    category_name = cfg.get('category_name', '') if not auto_detect else ''
    messages = list(cfg.get('messages', [])) if not auto_detect else []

    # If explicitly requested /mobile/hospital
    if slug == 'hospital' and not auto_detect:
        theme_color = cfg.get('theme_color', '#f43f5e')
        bg_color = cfg.get('bg_color', '#ffe4e6')
        category_name = cfg.get('category_name', '1. මූලික සන්නිවේදනය / Basic communication')
        messages = list(cfg.get('messages', []))

    categories = cfg.get('categories', []) if not auto_detect else []
    hospital_categories = cfg.get('hospital_categories', {}) if not auto_detect else {}
    bank_categories = cfg.get('bank_categories', {}) if not auto_detect else {}

    # If explicitly requested /mobile/bank
    if slug == 'bank' and not auto_detect:
        theme_color = cfg.get('theme_color', '#2563eb')
        bg_color = cfg.get('bg_color', '#dbeafe')
        category_name = cfg.get('category_name', '1. මූලික සන්නිවේදනය / Basic communication')
        categories = list(cfg.get('categories', []))
        bank_categories = dict(cfg.get('bank_categories', {}))

    return render_template(
        'mobile.html',
        location_slug=slug,
        location_name=location_name,
        badge_icon=badge_icon,
        theme_color=theme_color,
        bg_color=bg_color,
        category_name=category_name,
        categories=categories,
        hospital_categories=hospital_categories,
        bank_categories=bank_categories,
        messages=messages,
        auto_detect=auto_detect
    )




