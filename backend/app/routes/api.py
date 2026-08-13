from flask import Blueprint, jsonify, request
from app.services.message_service import get_all_locations, get_location_messages
from app.services.geo_service import detect_place_by_coordinates

api_bp = Blueprint('api', __name__)

@api_bp.route('/locations', methods=['GET'])
def list_locations():
    locations = get_all_locations()
    return jsonify([loc.to_dict() for loc in locations])

@api_bp.route('/locations/<slug>', methods=['GET'])
def get_location_details(slug):
    data = get_location_messages(slug)
    if not data:
        return jsonify({'error': 'Location not found'}), 404
    
    return jsonify({
        'location': data['location'].to_dict(),
        'categories': [
            {
                'category': item['category'].to_dict(),
                'messages': [m.to_dict() for m in item['messages']]
            }
            for item in data['categories_with_messages']
        ]
    })

@api_bp.route('/detect-location', methods=['POST'])
def detect_location():
    data = request.get_json() or {}
    lat = data.get('lat')
    lon = data.get('lon')

    if lat is None or lon is None:
        return jsonify({'success': False, 'detected_slug': 'other', 'error': 'Missing coordinates'}), 400

    result = detect_place_by_coordinates(lat, lon)
    return jsonify(result)
