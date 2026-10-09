from flask import Blueprint, jsonify, request
from app.services.message_service import get_all_locations, get_location_messages
from app.services.geo_service import (
    detect_place_by_coordinates,
    LOCATION_PRESETS,
    get_sri_lanka_hospitals,
    select_hospital_by_id,
    get_sri_lanka_banks,
    select_bank_by_id,
    get_sri_lanka_restaurants,
    select_restaurant_by_id
)

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

@api_bp.route('/location-presets', methods=['GET'])
def get_location_presets():
    return jsonify(LOCATION_PRESETS)

@api_bp.route('/location-presets/<slug>', methods=['GET'])
def get_location_preset(slug):
    slug = slug.lower()
    preset = LOCATION_PRESETS.get(slug)
    if not preset:
        return jsonify({'error': 'Preset not found'}), 404
    return jsonify(preset)

@api_bp.route('/sri-lanka-hospitals', methods=['GET'])
def get_sri_lanka_hospitals_route():
    lat = request.args.get('lat', type=float)
    lon = request.args.get('lon', type=float)
    hospitals = get_sri_lanka_hospitals(lat, lon)
    return jsonify({
        'success': True,
        'country': 'Sri Lanka',
        'count': len(hospitals),
        'hospitals': hospitals
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

@api_bp.route('/select-hospital', methods=['POST'])
def select_hospital():
    data = request.get_json() or {}
    hosp_id = data.get('hospital_id') or data.get('id')
    hosp_name = data.get('hospital_name') or data.get('name')
    lat = data.get('lat')
    lon = data.get('lon')

    if not hosp_id and lat is not None and lon is not None:
        res = detect_place_by_coordinates(lat, lon)
        if res.get('is_hospital'):
            res['manually_selected'] = True
            return jsonify(res)

    result = select_hospital_by_id(hosp_id, hosp_name)
    return jsonify(result)

@api_bp.route('/sri-lanka-banks', methods=['GET'])
def get_sri_lanka_banks_route():
    lat = request.args.get('lat', type=float)
    lon = request.args.get('lon', type=float)
    banks = get_sri_lanka_banks(lat, lon)
    return jsonify({
        'success': True,
        'country': 'Sri Lanka',
        'count': len(banks),
        'banks': banks
    })

@api_bp.route('/select-bank', methods=['POST'])
def select_bank():
    data = request.get_json() or {}
    bank_id = data.get('bank_id') or data.get('id')
    bank_name = data.get('bank_name') or data.get('name')
    lat = data.get('lat')
    lon = data.get('lon')

    if not bank_id and lat is not None and lon is not None:
        res = detect_place_by_coordinates(lat, lon)
        if res.get('is_bank'):
            res['manually_selected'] = True
            return jsonify(res)

    result = select_bank_by_id(bank_id, bank_name)
    return jsonify(result)

@api_bp.route('/sri-lanka-restaurants', methods=['GET'])
def get_sri_lanka_restaurants_route():
    lat = request.args.get('lat', type=float)
    lon = request.args.get('lon', type=float)
    restaurants = get_sri_lanka_restaurants(lat, lon)
    return jsonify({
        'success': True,
        'country': 'Sri Lanka',
        'count': len(restaurants),
        'restaurants': restaurants
    })

@api_bp.route('/select-restaurant', methods=['POST'])
def select_restaurant():
    data = request.get_json() or {}
    restaurant_id = data.get('restaurant_id') or data.get('id')
    restaurant_name = data.get('restaurant_name') or data.get('name')
    lat = data.get('lat')
    lon = data.get('lon')

    if not restaurant_id and lat is not None and lon is not None:
        res = detect_place_by_coordinates(lat, lon)
        if res.get('is_restaurant'):
            res['manually_selected'] = True
            return jsonify(res)

    result = select_restaurant_by_id(restaurant_id, restaurant_name)
    return jsonify(result)


