from flask import Blueprint, render_template
from app.services.sample_data import get_sample_locations

main_bp = Blueprint('main', __name__)

@main_bp.route('/')
def index():
    locations = get_sample_locations()
    return render_template('index.html', locations=locations)
