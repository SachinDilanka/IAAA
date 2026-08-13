from flask import Blueprint, render_template, request, redirect, url_for
from app.services.message_service import get_all_locations, get_location_messages

views_bp = Blueprint('views', __name__)

@views_bp.route('/')
def index():
    locations = get_all_locations()
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
