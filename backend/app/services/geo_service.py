import requests

OSM_NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"

def detect_place_by_coordinates(lat, lon):
    """
    Attempts to reverse geocode lat/lon into a location category (hospital, restaurant, supermarket, pharmacy, bank, or other).
    Uses Nominatim API with proper User-Agent header.
    """
    try:
        headers = {
            'User-Agent': 'DeafNonVerbalAccessibleCommsApp/1.0 (accessibility-app@example.com)'
        }
        params = {
            'lat': lat,
            'lon': lon,
            'format': 'json',
            'extratags': 1,
            'addressdetails': 1
        }
        response = requests.get(OSM_NOMINATIM_URL, params=params, headers=headers, timeout=4)
        if response.status_code == 200:
            data = response.json()
            category_slug = map_osm_data_to_slug(data)
            display_name = data.get('display_name', 'Unknown Location')
            address = data.get('address', {})
            poi_name = address.get('hospital') or address.get('restaurant') or address.get('supermarket') or address.get('pharmacy') or address.get('bank') or address.get('amenity') or address.get('shop') or display_name.split(',')[0]
            
            return {
                'success': True,
                'detected_slug': category_slug,
                'poi_name': poi_name,
                'address': display_name
            }
    except Exception as e:
        print(f"Geo lookup error: {e}")
    
    return {
        'success': False,
        'detected_slug': 'other',
        'poi_name': 'Manual Selection',
        'address': 'Location auto-detection unavailable'
    }

def map_osm_data_to_slug(osm_data):
    address = osm_data.get('address', {})
    category = osm_data.get('category', '').lower()
    type_tag = osm_data.get('type', '').lower()

    amenity = address.get('amenity', '').lower()
    shop = address.get('shop', '').lower()
    healthcare = address.get('healthcare', '').lower()

    if amenity in ['hospital', 'clinic', 'doctors'] or healthcare in ['hospital', 'clinic'] or type_tag in ['hospital', 'clinic']:
        return 'hospital'
    elif amenity in ['restaurant', 'fast_food', 'cafe', 'food_court'] or category == 'eating':
        return 'restaurant'
    elif shop in ['supermarket', 'grocery', 'convenience'] or category == 'shop':
        return 'supermarket'
    elif amenity == 'pharmacy' or healthcare == 'pharmacy' or type_tag == 'pharmacy':
        return 'pharmacy'
    elif amenity in ['bank', 'atm']:
        return 'bank'
    
    return 'other'
