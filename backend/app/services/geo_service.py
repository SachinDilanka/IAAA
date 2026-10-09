import math
import requests

OSM_NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"

def calculate_distance_km(lat1, lon1, lat2, lon2):
    """Haversine formula to calculate geodesic distance in km between two GPS points."""
    R = 6371.0 # Earth radius in km
    dlat = math.radians(lat2 - lat1)
    dlon = math.radians(lon2 - lon1)
    a = (math.sin(dlat / 2) ** 2 +
         math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) *
         math.sin(dlon / 2) ** 2)
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
    return R * c

# Major Hospitals in Sri Lanka (Government Teaching, General, Specialty & Top Private Hospitals)
SRI_LANKA_HOSPITALS = [
    {
        'id': 'nhsl-colombo',
        'name': 'National Hospital of Sri Lanka (NHSL)',
        'short_name': 'NHSL Colombo',
        'city': 'Colombo 10',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'National Teaching Hospital',
        'lat': 6.9197,
        'lon': 79.8693,
        'emergency': '1990 / +94 11 269 1111',
        'slug': 'hospital'
    },
    {
        'id': 'asiri-central',
        'name': 'Asiri Central Hospital',
        'short_name': 'Asiri Central',
        'city': 'Norris Canal Rd, Colombo 10',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Private Multi-Specialty Hospital',
        'lat': 6.9248,
        'lon': 79.8647,
        'emergency': '+94 11 466 5500',
        'slug': 'hospital'
    },
    {
        'id': 'nawaloka-colombo',
        'name': 'Nawaloka Hospital',
        'short_name': 'Nawaloka Hospital',
        'city': 'Deshamanya H.K. Dharmadasa Mw, Colombo 02',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Private Multi-Specialty Hospital',
        'lat': 6.9243,
        'lon': 79.8524,
        'emergency': '+94 11 557 7111',
        'slug': 'hospital'
    },
    {
        'id': 'kalubowila-teaching',
        'name': 'Colombo South Teaching Hospital (Kalubowila)',
        'short_name': 'Kalubowila Hospital',
        'city': 'Kalubowila / Dehiwala',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Teaching Hospital',
        'lat': 6.8732,
        'lon': 79.8789,
        'emergency': '1990 / +94 11 276 3066',
        'slug': 'hospital'
    },
    {
        'id': 'lanka-hospitals',
        'name': 'The Lanka Hospitals',
        'short_name': 'Lanka Hospitals',
        'city': 'Elvitigala Mw, Narahenpita, Colombo 05',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Private Multi-Specialty Hospital',
        'lat': 6.8953,
        'lon': 79.8837,
        'emergency': '+94 11 543 0000 / 1566',
        'slug': 'hospital'
    },
    {
        'id': 'durdans-colombo',
        'name': 'Durdans Hospital',
        'short_name': 'Durdans Hospital',
        'city': 'Alfred Place, Kollupitiya, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Private Hospital',
        'lat': 6.8988,
        'lon': 79.8548,
        'emergency': '+94 11 214 0000 / 1344',
        'slug': 'hospital'
    },
    {
        'id': 'asiri-surgical',
        'name': 'Asiri Surgical Hospital',
        'short_name': 'Asiri Surgical',
        'city': 'Kirimandala Mw, Narahenpita, Colombo 05',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Private Surgical Hospital',
        'lat': 6.8924,
        'lon': 79.8842,
        'emergency': '+94 11 452 4400',
        'slug': 'hospital'
    },
    {
        'id': 'lrh-colombo',
        'name': 'Lady Ridgeway Hospital for Children (LRH)',
        'short_name': 'LRH Children Hospital',
        'city': 'Danister De Silva Mw, Colombo 08',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Pediatric Teaching Hospital',
        'lat': 6.9238,
        'lon': 79.8761,
        'emergency': '1990 / +94 11 269 3711',
        'slug': 'hospital'
    },
    {
        'id': 'castle-street',
        'name': 'Castle Street Hospital for Women',
        'short_name': 'Castle Street Hospital',
        'city': 'Castle Street, Colombo 08',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Women & Maternity Teaching Hospital',
        'lat': 6.9142,
        'lon': 79.8856,
        'emergency': '+94 11 269 6231',
        'slug': 'hospital'
    },
    {
        'id': 'ragama-teaching',
        'name': 'Colombo North Teaching Hospital (Ragama)',
        'short_name': 'Ragama Hospital',
        'city': 'Ragama',
        'district': 'Gampaha',
        'province': 'Western',
        'type': 'Teaching Hospital',
        'lat': 7.0286,
        'lon': 79.9190,
        'emergency': '1990 / +94 11 295 9261',
        'slug': 'hospital'
    },
    {
        'id': 'sri-jayewardenepura',
        'name': 'Sri Jayewardenepura General Hospital',
        'short_name': 'SJGH Kotte',
        'city': 'Thalapathpitiya, Nugegoda',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'General Hospital',
        'lat': 6.8772,
        'lon': 79.9272,
        'emergency': '+94 11 277 8610',
        'slug': 'hospital'
    },
    {
        'id': 'negombo-hospital',
        'name': 'District General Hospital Negombo',
        'short_name': 'Negombo Hospital',
        'city': 'Colombo Rd, Negombo',
        'district': 'Gampaha',
        'province': 'Western',
        'type': 'District General Hospital',
        'lat': 7.2144,
        'lon': 79.8452,
        'emergency': '1990 / +94 31 222 2261',
        'slug': 'hospital'
    },
    {
        'id': 'gampaha-hospital',
        'name': 'District General Hospital Gampaha',
        'short_name': 'Gampaha Hospital',
        'city': 'Gampaha',
        'district': 'Gampaha',
        'province': 'Western',
        'type': 'District General Hospital',
        'lat': 7.0898,
        'lon': 79.9934,
        'emergency': '1990 / +94 33 222 2261',
        'slug': 'hospital'
    },
    {
        'id': 'kandy-teaching',
        'name': 'National Hospital Kandy',
        'short_name': 'Kandy National Hospital',
        'city': 'William Gopallawa Mw, Kandy',
        'district': 'Kandy',
        'province': 'Central',
        'type': 'National Teaching Hospital',
        'lat': 7.2885,
        'lon': 80.6277,
        'emergency': '1990 / +94 81 223 3337',
        'slug': 'hospital'
    },
    {
        'id': 'karapitiya-teaching',
        'name': 'Teaching Hospital Karapitiya (Galle)',
        'short_name': 'Karapitiya Hospital Galle',
        'city': 'Karapitiya, Galle',
        'district': 'Galle',
        'province': 'Southern',
        'type': 'Teaching Hospital',
        'lat': 6.0645,
        'lon': 80.2285,
        'emergency': '1990 / +94 91 223 2250',
        'slug': 'hospital'
    },
    {
        'id': 'jaffna-teaching',
        'name': 'Teaching Hospital Jaffna',
        'short_name': 'Jaffna Hospital',
        'city': 'Hospital Rd, Jaffna',
        'district': 'Jaffna',
        'province': 'Northern',
        'type': 'Teaching Hospital',
        'lat': 9.6644,
        'lon': 80.0215,
        'emergency': '1990 / +94 21 222 2261',
        'slug': 'hospital'
    },
    {
        'id': 'anuradhapura-teaching',
        'name': 'Teaching Hospital Anuradhapura',
        'short_name': 'Anuradhapura Hospital',
        'city': 'Maithripala Senanayake Mw, Anuradhapura',
        'district': 'Anuradhapura',
        'province': 'North Central',
        'type': 'Teaching Hospital',
        'lat': 8.3370,
        'lon': 80.4045,
        'emergency': '1990 / +94 25 222 2261',
        'slug': 'hospital'
    },
    {
        'id': 'batticaloa-teaching',
        'name': 'Teaching Hospital Batticaloa',
        'short_name': 'Batticaloa Hospital',
        'city': 'Hospital Rd, Batticaloa',
        'district': 'Batticaloa',
        'province': 'Eastern',
        'type': 'Teaching Hospital',
        'lat': 7.7126,
        'lon': 81.6961,
        'emergency': '1990 / +94 65 222 2261',
        'slug': 'hospital'
    },
    {
        'id': 'panadura-hospital',
        'name': 'Base Hospital Panadura',
        'short_name': 'Panadura Hospital',
        'city': 'Horana Rd, Panadura',
        'district': 'Kalutara',
        'province': 'Western',
        'type': 'Base Hospital',
        'lat': 6.7135,
        'lon': 79.9074,
        'emergency': '1990 / +94 38 223 2261',
        'slug': 'hospital'
    },
    {
        'id': 'homagama-hospital',
        'name': 'Base Hospital Homagama',
        'short_name': 'Homagama Hospital',
        'city': 'Homagama',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Base Hospital',
        'lat': 6.8436,
        'lon': 80.0035,
        'emergency': '1990 / +94 11 285 5261',
        'slug': 'hospital'
    }
]

def get_sri_lanka_hospitals(user_lat=None, user_lon=None):
    """Returns list of Sri Lanka hospitals with calculated distances if coordinates are given."""
    hospitals = [dict(h) for h in SRI_LANKA_HOSPITALS]
    if user_lat is not None and user_lon is not None:
        try:
            u_lat = float(user_lat)
            u_lon = float(user_lon)
            for h in hospitals:
                d = calculate_distance_km(u_lat, u_lon, h['lat'], h['lon'])
                h['distance_km'] = round(d, 2)
                h['distance_m'] = round(d * 1000)
            hospitals.sort(key=lambda x: x['distance_km'])
        except Exception:
            pass
    return hospitals

# Major Banks in Sri Lanka (State Commercial, Licensed Private, Foreign & Regional Banks)
SRI_LANKA_BANKS = [
    {
        'id': 'boc-head-office',
        'name': 'Bank of Ceylon (BOC) - Head Office',
        'short_name': 'BOC Head Office',
        'bank_name': 'Bank of Ceylon',
        'branch': 'Head Office',
        'city': 'BOC Square, Bank of Ceylon Mw, Fort, Colombo 01',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'State Commercial Bank',
        'lat': 6.9348,
        'lon': 79.8436,
        'hotline': '1975 / +94 11 220 4444',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'combank-head-office',
        'name': 'Commercial Bank of Ceylon - Head Office',
        'short_name': 'Commercial Bank HQ',
        'bank_name': 'Commercial Bank',
        'branch': 'Commercial House, Fort',
        'city': 'Bristol St, Fort, Colombo 01',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9340,
        'lon': 79.8444,
        'hotline': '+94 11 248 6000',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'peoples-bank-head-office',
        'name': "People's Bank - Head Office",
        'short_name': "People's Bank HQ",
        'bank_name': "People's Bank",
        'branch': 'Head Office',
        'city': 'Sir Chittampalam A Gardiner Mw, Colombo 02',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'State Commercial Bank',
        'lat': 6.9312,
        'lon': 79.8510,
        'hotline': '1961 / +94 11 245 8100',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'hnb-towers',
        'name': 'Hatton National Bank (HNB) - Head Office',
        'short_name': 'HNB Towers Colombo',
        'bank_name': 'Hatton National Bank',
        'branch': 'HNB Towers',
        'city': 'T.B. Jayah Mw, Colombo 10',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9208,
        'lon': 79.8652,
        'hotline': '+94 11 266 4664',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'sampath-bank-head-office',
        'name': 'Sampath Bank - Head Office',
        'short_name': 'Sampath Bank HQ',
        'bank_name': 'Sampath Bank',
        'branch': 'Head Office',
        'city': 'Sir James Pieris Mw, Colombo 02',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9205,
        'lon': 79.8560,
        'hotline': '+94 11 230 3050',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'seylan-towers',
        'name': 'Seylan Bank - Head Office',
        'short_name': 'Seylan Towers Colombo',
        'bank_name': 'Seylan Bank',
        'branch': 'Seylan Towers',
        'city': 'Galle Rd, Kollupitiya, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9152,
        'lon': 79.8505,
        'hotline': '+94 11 200 8888',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'nsb-head-office',
        'name': 'National Savings Bank (NSB) - Head Office',
        'short_name': 'NSB Head Office',
        'bank_name': 'National Savings Bank',
        'branch': 'Head Office',
        'city': 'Ananda Coomaraswamy Mw, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'State Savings Bank',
        'lat': 6.9078,
        'lon': 79.8570,
        'hotline': '+94 11 237 9379',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'ntb-head-office',
        'name': 'Nations Trust Bank (NTB) - Head Office',
        'short_name': 'Nations Trust HQ',
        'bank_name': 'Nations Trust Bank',
        'branch': 'Head Office',
        'city': 'Union Place, Colombo 02',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9200,
        'lon': 79.8580,
        'hotline': '+94 11 471 1411',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'dfcc-head-office',
        'name': 'DFCC Bank - Head Office',
        'short_name': 'DFCC Bank HQ',
        'bank_name': 'DFCC Bank',
        'branch': 'Head Office',
        'city': 'Galle Rd, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9180,
        'lon': 79.8495,
        'hotline': '+94 11 235 0000',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'pan-asia-head-office',
        'name': 'Pan Asia Bank - Head Office',
        'short_name': 'Pan Asia Bank HQ',
        'bank_name': 'Pan Asia Bank',
        'branch': 'Head Office',
        'city': 'Galle Rd, Kollupitiya, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9030,
        'lon': 79.8525,
        'hotline': '+94 11 466 7222',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'hsbc-fort',
        'name': 'HSBC Sri Lanka - Colombo Main Office',
        'short_name': 'HSBC Fort Colombo',
        'bank_name': 'HSBC',
        'branch': 'Colombo Fort Branch',
        'city': 'Sir Baron Jayatilaka Mw, Fort, Colombo 01',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'International Commercial Bank',
        'lat': 6.9360,
        'lon': 79.8430,
        'hotline': '+94 11 447 2200',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'standard-chartered-fort',
        'name': 'Standard Chartered Bank - Main Office',
        'short_name': 'Standard Chartered Fort',
        'bank_name': 'Standard Chartered',
        'branch': 'Sri Lanka Main Branch',
        'city': 'Janadhipathi Mw, Fort, Colombo 01',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'International Commercial Bank',
        'lat': 6.9335,
        'lon': 79.8420,
        'hotline': '+94 11 248 0000',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'amana-bank-head-office',
        'name': 'Amāna Bank - Corporate Office',
        'short_name': 'Amāna Bank HQ',
        'bank_name': 'Amāna Bank',
        'branch': 'Corporate Office',
        'city': 'Dharmapala Mw, Colombo 07',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9110,
        'lon': 79.8620,
        'hotline': '+94 11 775 6756',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'cargills-bank-head-office',
        'name': 'Cargills Bank - Head Office',
        'short_name': 'Cargills Bank HQ',
        'bank_name': 'Cargills Bank',
        'branch': 'Head Office',
        'city': 'Maitland Crescent, Colombo 07',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9045,
        'lon': 79.8665,
        'hotline': '+94 11 764 0640',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'union-bank-head-office',
        'name': 'Union Bank of Colombo - Head Office',
        'short_name': 'Union Bank HQ',
        'bank_name': 'Union Bank',
        'branch': 'Head Office',
        'city': 'Galle Rd, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 6.9090,
        'lon': 79.8510,
        'hotline': '+94 11 580 0800',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'boc-kandy-super',
        'name': 'Bank of Ceylon (BOC) - Kandy Super Grade Branch',
        'short_name': 'BOC Kandy Super Branch',
        'bank_name': 'Bank of Ceylon',
        'branch': 'Kandy Super Grade Branch',
        'city': 'Dalada Veediya, Kandy',
        'district': 'Kandy',
        'province': 'Central',
        'type': 'State Commercial Bank',
        'lat': 7.2935,
        'lon': 80.6360,
        'hotline': '1975 / +94 81 223 4282',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'combank-kandy-city',
        'name': 'Commercial Bank - Kandy City Branch',
        'short_name': 'Commercial Bank Kandy',
        'bank_name': 'Commercial Bank',
        'branch': 'Kandy City Branch',
        'city': 'Ward Street (Kotugodella Veediya), Kandy',
        'district': 'Kandy',
        'province': 'Central',
        'type': 'Licensed Commercial Bank',
        'lat': 7.2920,
        'lon': 80.6345,
        'hotline': '+94 81 222 4558',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'hnb-kandy',
        'name': 'Hatton National Bank (HNB) - Kandy Branch',
        'short_name': 'HNB Kandy Branch',
        'bank_name': 'Hatton National Bank',
        'branch': 'Kandy Main Branch',
        'city': 'Dalada Veediya, Kandy',
        'district': 'Kandy',
        'province': 'Central',
        'type': 'Licensed Commercial Bank',
        'lat': 7.2940,
        'lon': 80.6370,
        'hotline': '+94 81 223 4381',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'peoples-bank-galle',
        'name': "People's Bank - Galle Regional Branch",
        'short_name': "People's Bank Galle",
        'bank_name': "People's Bank",
        'branch': 'Galle Regional Branch',
        'city': 'Main Street, Galle',
        'district': 'Galle',
        'province': 'Southern',
        'type': 'State Commercial Bank',
        'lat': 6.0350,
        'lon': 80.2160,
        'hotline': '1961 / +94 91 223 4331',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'combank-galle-fort',
        'name': 'Commercial Bank - Galle Fort Branch',
        'short_name': 'Commercial Bank Galle Fort',
        'bank_name': 'Commercial Bank',
        'branch': 'Galle Fort Branch',
        'city': 'Church Street, Galle Fort',
        'district': 'Galle',
        'province': 'Southern',
        'type': 'Licensed Commercial Bank',
        'lat': 6.0270,
        'lon': 80.2175,
        'hotline': '+94 91 223 4511',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'boc-jaffna-main',
        'name': 'Bank of Ceylon (BOC) - Jaffna Main Branch',
        'short_name': 'BOC Jaffna Main',
        'bank_name': 'Bank of Ceylon',
        'branch': 'Jaffna Main Branch',
        'city': 'Hospital Rd, Jaffna',
        'district': 'Jaffna',
        'province': 'Northern',
        'type': 'State Commercial Bank',
        'lat': 9.6630,
        'lon': 80.0165,
        'hotline': '1975 / +94 21 222 2281',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'hnb-negombo',
        'name': 'Hatton National Bank (HNB) - Negombo Main Branch',
        'short_name': 'HNB Negombo Branch',
        'bank_name': 'Hatton National Bank',
        'branch': 'Negombo Main Branch',
        'city': 'Greens Road, Negombo',
        'district': 'Gampaha',
        'province': 'Western',
        'type': 'Licensed Commercial Bank',
        'lat': 7.2100,
        'lon': 79.8390,
        'hotline': '+94 31 222 2841',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'sampath-kurunegala',
        'name': 'Sampath Bank - Kurunegala Super Branch',
        'short_name': 'Sampath Bank Kurunegala',
        'bank_name': 'Sampath Bank',
        'branch': 'Kurunegala Super Branch',
        'city': 'Colombo Road, Kurunegala',
        'district': 'Kurunegala',
        'province': 'North Western',
        'type': 'Licensed Commercial Bank',
        'lat': 7.4850,
        'lon': 80.3620,
        'hotline': '+94 37 222 3991',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'combank-anuradhapura',
        'name': 'Commercial Bank - Anuradhapura Branch',
        'short_name': 'Commercial Bank Anuradhapura',
        'bank_name': 'Commercial Bank',
        'branch': 'Anuradhapura Branch',
        'city': 'Maithripala Senanayake Mw, Anuradhapura',
        'district': 'Anuradhapura',
        'province': 'North Central',
        'type': 'Licensed Commercial Bank',
        'lat': 8.3310,
        'lon': 80.4080,
        'hotline': '+94 25 222 2771',
        'slug': 'bank',
        'color': '#2563eb'
    },
    {
        'id': 'peoples-bank-batticaloa',
        'name': "People's Bank - Batticaloa Branch",
        'short_name': "People's Bank Batticaloa",
        'bank_name': "People's Bank",
        'branch': 'Batticaloa Branch',
        'city': 'Bar Road, Batticaloa',
        'district': 'Batticaloa',
        'province': 'Eastern',
        'type': 'State Commercial Bank',
        'lat': 7.7160,
        'lon': 81.6990,
        'hotline': '1961 / +94 65 222 2271',
        'slug': 'bank',
        'color': '#2563eb'
    }
]

def get_sri_lanka_banks(user_lat=None, user_lon=None):
    """Returns list of Sri Lanka banks with calculated distances if coordinates are given."""
    banks = [dict(b) for b in SRI_LANKA_BANKS]
    if user_lat is not None and user_lon is not None:
        try:
            u_lat = float(user_lat)
            u_lon = float(user_lon)
            for b in banks:
                d = calculate_distance_km(u_lat, u_lon, b['lat'], b['lon'])
                b['distance_km'] = round(d, 2)
                b['distance_m'] = round(d * 1000)
            banks.sort(key=lambda x: x['distance_km'])
        except Exception:
            pass
    return banks

# Major & Popular Restaurants in Sri Lanka (Famous Dining, Traditional, Seafood & Heritage Venues)
SRI_LANKA_RESTAURANTS = [
    {
        'id': 'upalis-colombo',
        'name': "Upali's by Nawaloka",
        'short_name': "Upali's Colombo",
        'restaurant_name': "Upali's by Nawaloka",
        'cuisine': 'Authentic Sri Lankan Cuisine',
        'branch': 'Colombo 07',
        'city': 'C.W.W. Kannangara Mw, Town Hall, Colombo 07',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9115,
        'lon': 79.8635,
        'phone': '+94 11 269 5812',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'ministry-of-crab',
        'name': 'Ministry of Crab',
        'short_name': 'Ministry of Crab',
        'restaurant_name': 'Ministry of Crab',
        'cuisine': 'Seafood & Lagoon Crab Fine Dining',
        'branch': 'Old Dutch Hospital',
        'city': 'Old Dutch Hospital, Fort, Colombo 01',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9345,
        'lon': 79.8437,
        'phone': '+94 11 540 2722',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'the-lagoon-cinnamon-grand',
        'name': 'The Lagoon - Cinnamon Grand',
        'short_name': 'The Lagoon',
        'restaurant_name': 'The Lagoon',
        'cuisine': 'Premium Seafood Market & Dining',
        'branch': 'Cinnamon Grand',
        'city': 'Galle Road, Kollupitiya, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9167,
        'lon': 79.8492,
        'phone': '+94 11 249 7371',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'nuga-gama',
        'name': 'Nuga Gama - Cinnamon Grand',
        'short_name': 'Nuga Gama',
        'restaurant_name': 'Nuga Gama',
        'cuisine': 'Traditional Sri Lankan Village Dining',
        'branch': 'Cinnamon Grand',
        'city': 'Galle Road, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9172,
        'lon': 79.8488,
        'phone': '+94 11 249 7369',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'shanmugas-wellawatte',
        'name': 'Shanmugas Restaurant',
        'short_name': 'Shanmugas',
        'restaurant_name': 'Shanmugas',
        'cuisine': 'South Indian Vegetarian',
        'branch': 'Wellawatte',
        'city': 'Ramakrishna Rd, Wellawatte, Colombo 06',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.8785,
        'lon': 79.8601,
        'phone': '+94 11 236 1384',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'green-cabin-colombo',
        'name': 'Green Cabin Restaurant',
        'short_name': 'Green Cabin',
        'restaurant_name': 'Green Cabin',
        'cuisine': 'Traditional Sri Lankan & Bakery',
        'branch': 'Kollupitiya',
        'city': 'Galle Road, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.8970,
        'lon': 79.8565,
        'phone': '+94 11 258 8811',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'raja-bojun',
        'name': 'Raja Bojun',
        'short_name': 'Raja Bojun',
        'restaurant_name': 'Raja Bojun',
        'cuisine': 'Authentic Sri Lankan Buffet',
        'branch': 'Liberty Arcade',
        'city': 'R.A. De Mel Mw, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9038,
        'lon': 79.8530,
        'phone': '+94 11 471 6171',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'galle-face-sea-spray',
        'name': 'Sea Spray - The Galle Face Hotel',
        'short_name': 'Sea Spray Galle Face',
        'restaurant_name': 'Sea Spray',
        'cuisine': 'Oceanfront Seafood & Grill',
        'branch': 'Galle Face Hotel',
        'city': 'Galle Road, Kollupitiya, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9205,
        'lon': 79.8448,
        'phone': '+94 11 254 1010',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'pilawoos-kollupitiya',
        'name': 'Hotel de Pilawoos',
        'short_name': 'Pilawoos Kollupitiya',
        'restaurant_name': 'Hotel de Pilawoos',
        'cuisine': 'Sri Lankan Street Food & Kottu',
        'branch': 'Kollupitiya',
        'city': 'Galle Road, Kollupitiya, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9080,
        'lon': 79.8510,
        'phone': '+94 11 257 4333',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'the-gallery-cafe',
        'name': 'The Gallery Café (Paradise Road)',
        'short_name': 'The Gallery Café',
        'restaurant_name': 'The Gallery Café',
        'cuisine': 'Contemporary Fusion & Desserts',
        'branch': 'Bambalapitiya',
        'city': 'Alfred House Rd, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.8988,
        'lon': 79.8550,
        'phone': '+94 11 258 2162',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'kaema-sutra-shangrila',
        'name': 'Kaema Sutra - Shangri-La Colombo',
        'short_name': 'Kaema Sutra',
        'restaurant_name': 'Kaema Sutra',
        'cuisine': 'Modern Creative Sri Lankan',
        'branch': 'Shangri-La Hotel',
        'city': 'One Galle Face, Colombo 01',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9272,
        'lon': 79.8442,
        'phone': '+94 11 788 8288',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'monsoon-colombo',
        'name': 'Monsoon Colombo',
        'short_name': 'Monsoon Colombo',
        'restaurant_name': 'Monsoon',
        'cuisine': 'Southeast Asian Street Food',
        'branch': 'Park Street Mews',
        'city': 'Park Street Mews, Colombo 02',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9185,
        'lon': 79.8580,
        'phone': '+94 11 230 4333',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'bavarian-german-restaurant',
        'name': 'Bavarian German Restaurant',
        'short_name': 'Bavarian Colombo',
        'restaurant_name': 'Bavarian German Restaurant',
        'cuisine': 'European & German Grill',
        'branch': 'Galle Face Terrace',
        'city': 'Galle Face Terrace, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9200,
        'lon': 79.8475,
        'phone': '+94 11 242 2233',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'graze-kitchen-hilton',
        'name': 'Graze Kitchen - Hilton Colombo',
        'short_name': 'Graze Kitchen',
        'restaurant_name': 'Graze Kitchen',
        'cuisine': 'International Live Stations & Buffet',
        'branch': 'Hilton Colombo',
        'city': 'Sir Chittampalam A Gardiner Mw, Colombo 02',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9320,
        'lon': 79.8465,
        'phone': '+94 11 249 2492',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'dinemore-thurstan',
        'name': 'Dinemore - Thurstan Road',
        'short_name': 'Dinemore Thurstan',
        'restaurant_name': 'Dinemore',
        'cuisine': 'Submarines, Grill & Fast Casual',
        'branch': 'Thurstan Road',
        'city': 'Thurstan Rd, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9040,
        'lon': 79.8585,
        'phone': '+94 11 255 6000',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'chola-authentic-indian',
        'name': 'Chola Authentic Indian Restaurant',
        'short_name': 'Chola Restaurant',
        'restaurant_name': 'Chola',
        'cuisine': 'North & South Indian Cuisine',
        'branch': 'Wellawatte',
        'city': 'Lily Ave, Wellawatte, Colombo 06',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.8770,
        'lon': 79.8595,
        'phone': '+94 11 436 4364',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'the-kandy-house',
        'name': 'The Kandy House Restaurant',
        'short_name': 'The Kandy House',
        'restaurant_name': 'The Kandy House',
        'cuisine': 'Gourmet Fusion & Fine Dining',
        'branch': 'Amunugama',
        'city': 'Amunugama, Gunnepana, Kandy',
        'district': 'Kandy',
        'province': 'Central',
        'lat': 7.3080,
        'lon': 80.6720,
        'phone': '+94 81 492 1394',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'slightly-chilled-kandy',
        'name': 'Slightly Chilled Lounge & Restaurant',
        'short_name': 'Slightly Chilled Kandy',
        'restaurant_name': 'Slightly Chilled Lounge',
        'cuisine': 'Asian, Continental & Lake View Dining',
        'branch': 'Kandy Lake',
        'city': 'Anagarika Dharmapala Mw, Kandy',
        'district': 'Kandy',
        'province': 'Central',
        'lat': 7.2925,
        'lon': 80.6410,
        'phone': '+94 81 223 8238',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'pedlars-inn-galle',
        'name': "Pedlar's Inn Café & Restaurant",
        'short_name': "Pedlar's Inn Galle",
        'restaurant_name': "Pedlar's Inn Café",
        'cuisine': 'Italian, Continental & Gelato',
        'branch': 'Galle Fort',
        'city': 'Pedlar St, Galle Fort, Galle',
        'district': 'Galle',
        'province': 'Southern',
        'lat': 6.0270,
        'lon': 80.2175,
        'phone': '+94 91 222 5333',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'a-minute-by-tuk-tuk',
        'name': 'A Minute by Tuk Tuk',
        'short_name': 'A Minute by Tuk Tuk',
        'restaurant_name': 'A Minute by Tuk Tuk',
        'cuisine': 'Sri Lankan Fusion & Seafood',
        'branch': 'Dutch Hospital Galle',
        'city': 'Old Dutch Hospital, Galle Fort, Galle',
        'district': 'Galle',
        'province': 'Southern',
        'lat': 6.0260,
        'lon': 80.2185,
        'phone': '+94 91 224 4550',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'lords-restaurant-negombo',
        'name': 'Lords Restaurant Complex',
        'short_name': 'Lords Negombo',
        'restaurant_name': 'Lords Restaurant',
        'cuisine': 'Seafood, Sri Lankan & International',
        'branch': 'Porutota',
        'city': 'Porutota Rd, Negombo',
        'district': 'Gampaha',
        'province': 'Western',
        'lat': 7.2340,
        'lon': 79.8420,
        'phone': '+94 31 227 5000',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'black-pepper-colombo',
        'name': 'Black Pepper Restaurant',
        'short_name': 'Black Pepper',
        'restaurant_name': 'Black Pepper',
        'cuisine': 'Authentic Sri Lankan Crab & Spices',
        'branch': 'Dutch Hospital Fort',
        'city': 'Old Dutch Hospital, Fort, Colombo 01',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9342,
        'lon': 79.8440,
        'phone': '+94 11 232 0544',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 't-lounge-dilmah',
        'name': 't-Lounge by Dilmah',
        'short_name': 'Dilmah t-Lounge',
        'restaurant_name': 't-Lounge by Dilmah',
        'cuisine': 'Gourmet Tea, Crepes & High Tea',
        'branch': 'Chatham Street',
        'city': 'Chatham St, Fort, Colombo 01',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9338,
        'lon': 79.8442,
        'phone': '+94 11 244 7168',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'sultans-biryani-colombo',
        'name': "Sultan's Biryani & Grill",
        'short_name': "Sultan's Biryani",
        'restaurant_name': "Sultan's Biryani",
        'cuisine': 'Biryani, Tandoor & Middle Eastern',
        'branch': 'Bambalapitiya',
        'city': 'Marine Drive, Colombo 04',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.8890,
        'lon': 79.8545,
        'phone': '+94 11 250 8800',
        'slug': 'restaurant',
        'color': '#f59e0b'
    },
    {
        'id': 'manhattan-fish-market',
        'name': 'The Manhattan Fish Market',
        'short_name': 'Manhattan Fish Market',
        'restaurant_name': 'The Manhattan Fish Market',
        'cuisine': 'American Style Seafood & Platters',
        'branch': 'Kollupitiya',
        'city': 'Deal Place, Kollupitiya, Colombo 03',
        'district': 'Colombo',
        'province': 'Western',
        'lat': 6.9042,
        'lon': 79.8535,
        'phone': '+94 11 237 0044',
        'slug': 'restaurant',
        'color': '#f59e0b'
    }
]

def get_sri_lanka_restaurants(user_lat=None, user_lon=None):
    """Returns list of Sri Lanka restaurants with calculated distances if coordinates are given."""
    restaurants = [dict(r) for r in SRI_LANKA_RESTAURANTS]
    if user_lat is not None and user_lon is not None:
        try:
            u_lat = float(user_lat)
            u_lon = float(user_lon)
            for r in restaurants:
                d = calculate_distance_km(u_lat, u_lon, r['lat'], r['lon'])
                r['distance_km'] = round(d, 2)
                r['distance_m'] = round(d * 1000)
            restaurants.sort(key=lambda x: x['distance_km'])
        except Exception:
            pass
    return restaurants

# Predefined reference coordinates (Primary in Sri Lanka, with aliases for tests)
PREDEFINED_COORDINATES = {
    'hospital': {'lat': 6.9197, 'lon': 79.8693, 'name': 'National Hospital of Sri Lanka (NHSL), Colombo', 'slug': 'hospital'},
    'hospital_us': {'lat': 40.739, 'lon': -73.975, 'name': 'Bellevue Hospital Center', 'slug': 'hospital'},
    'supermarket': {'lat': 6.9180, 'lon': 79.8620, 'name': 'Cargills Food City / Keells Supermarket, Colombo', 'slug': 'supermarket'},
    'supermarket_uk': {'lat': 51.515, 'lon': -0.141, 'name': 'Whole Foods Market / Supermarket', 'slug': 'supermarket'},
    'restaurant': {'lat': 6.9115, 'lon': 79.8635, 'name': "Upali's by Nawaloka / Popular Dining Colombo", 'slug': 'restaurant'},
    'restaurant_fr': {'lat': 48.858, 'lon': 2.294, 'name': 'Le Jules Verne Restaurant', 'slug': 'restaurant'},
    'bank': {'lat': 6.9333, 'lon': 79.8430, 'name': 'Bank of Ceylon (BOC) / Commercial Bank Head Office', 'slug': 'bank'},
    'bank_uk': {'lat': 51.513, 'lon': -0.088, 'name': 'City Central Bank & ATM', 'slug': 'bank'},
    'pharmacy': {'lat': 6.9205, 'lon': 79.8665, 'name': 'State Pharmaceuticals Corporation (Osu Sala) Colombo', 'slug': 'pharmacy'},
    'pharmacy_us': {'lat': 40.758, 'lon': -73.985, 'name': 'Duane Reade Pharmacy', 'slug': 'pharmacy'},
}

# Hospital Category 1: 1. මූලික සන්නිවේදනය / Basic communication (10 Messages)
HOSPITAL_BASIC_COMMUNICATION_MESSAGES = [
    {
        "id": 1,
        "template": "I am deaf.",
        "template_en": "I am deaf.",
        "template_si": "මම බිහිරි කෙනෙක්.",
        "icon": "fa-ear-deaf",
        "category": "Basic communication"
    },
    {
        "id": 2,
        "template": "I cannot speak.",
        "template_en": "I cannot speak.",
        "template_si": "මට කතා කරන්න බැහැ.",
        "icon": "fa-volume-xmark",
        "category": "Basic communication"
    },
    {
        "id": 3,
        "template": "Please write down your message.",
        "template_en": "Please write down your message.",
        "template_si": "කරුණාකර ඔබේ පණිවිඩය ලියන්න.",
        "icon": "fa-pen-to-square",
        "category": "Basic communication"
    },
    {
        "id": 4,
        "template": "Please speak slowly and face me.",
        "template_en": "Please speak slowly and face me.",
        "template_si": "කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.",
        "icon": "fa-face-smile",
        "category": "Basic communication"
    },
    {
        "id": 5,
        "template": "Please wait a moment.",
        "template_en": "Please wait a moment.",
        "template_si": "කරුණාකර මොහොතක් රැඳී සිටින්න.",
        "icon": "fa-clock",
        "category": "Basic communication"
    },
    {
        "id": 6,
        "template": "Thank you.",
        "template_en": "Thank you.",
        "template_si": "ස්තූතියි.",
        "icon": "fa-hands-clapping",
        "category": "Basic communication"
    },
    {
        "id": 7,
        "template": "Yes.",
        "template_en": "Yes.",
        "template_si": "ඔව්.",
        "icon": "fa-circle-check",
        "category": "Basic communication"
    },
    {
        "id": 8,
        "template": "No.",
        "template_en": "No.",
        "template_si": "නැහැ.",
        "icon": "fa-circle-xmark",
        "category": "Basic communication"
    },
    {
        "id": 9,
        "template": "I do not understand.",
        "template_en": "I do not understand.",
        "template_si": "මට තේරෙන්නේ නැහැ.",
        "icon": "fa-circle-question",
        "category": "Basic communication"
    },
    {
        "id": 10,
        "template": "Please repeat that.",
        "template_en": "Please repeat that.",
        "template_si": "කරුණාකර නැවත කියන්න.",
        "icon": "fa-rotate-right",
        "category": "Basic communication"
    }
]

# Hospital Category 2: 2. පිළිගැනීම සහ ලියාපදිංචිය / Reception and registration (10 Messages)
HOSPITAL_RECEPTION_MESSAGES = [
    {
        "id": 1,
        "template": "I need help.",
        "template_en": "I need help.",
        "template_si": "මට උදව්වක් අවශ්යයි.",
        "icon": "fa-handshake-angle",
        "category": "Reception and registration"
    },
    {
        "id": 2,
        "template": "Where is the reception?",
        "template_en": "Where is the reception?",
        "template_si": "පිළිගැනීමේ කවුන්ටරය කොහෙද?",
        "icon": "fa-bell-concierge",
        "category": "Reception and registration"
    },
    {
        "id": 3,
        "template": "I want to register as a new patient.",
        "template_en": "I want to register as a new patient.",
        "template_si": "මට නව රෝගියෙකු ලෙස ලියාපදිංචි වීමට අවශ්යයි.",
        "icon": "fa-user-plus",
        "category": "Reception and registration"
    },
    {
        "id": 4,
        "template": "I have an appointment.",
        "template_en": "I have an appointment.",
        "template_si": "මට වේලාවක් වෙන්කරගෙන තියෙනවා.",
        "icon": "fa-calendar-check",
        "category": "Reception and registration"
    },
    {
        "id": 5,
        "template": "I want to make an appointment.",
        "template_en": "I want to make an appointment.",
        "template_si": "මට වේලාවක් වෙන්කරගන්න ඕනේ.",
        "icon": "fa-calendar-plus",
        "category": "Reception and registration"
    },
    {
        "id": 6,
        "template": "Which counter should I go to?",
        "template_en": "Which counter should I go to?",
        "template_si": "මම යා යුත්තේ කුමන කවුන්ටරයට ද?",
        "icon": "fa-arrow-right-to-bracket",
        "category": "Reception and registration"
    },
    {
        "id": 7,
        "template": "How long is the waiting time?",
        "template_en": "How long is the waiting time?",
        "template_si": "බලා සිටිය යුතු කාලය කොපමණ ද?",
        "icon": "fa-hourglass-half",
        "category": "Reception and registration"
    },
    {
        "id": 8,
        "template": "Where do I get a token number?",
        "template_en": "Where do I get a token number?",
        "template_si": "ටෝකන් අංකය ලබාගන්නේ කොහෙන්ද?",
        "icon": "fa-ticket",
        "category": "Reception and registration"
    },
    {
        "id": 9,
        "template": "Here is my ID card.",
        "template_en": "Here is my ID card.",
        "template_si": "මෙන්න මගේ හැඳුනුම්පත.",
        "icon": "fa-id-card",
        "category": "Reception and registration"
    },
    {
        "id": 10,
        "template": "Here is my clinic book.",
        "template_en": "Here is my clinic book.",
        "template_si": "මෙන්න මගේ සායන පොත.",
        "icon": "fa-book-medical",
        "category": "Reception and registration"
    }
]

# Hospital Category 3: 3. දිශාවන් / Directions (10 Messages)
HOSPITAL_DIRECTIONS_MESSAGES = [
    {
        "id": 1,
        "template": "Where is the Outpatient Department (OPD)?",
        "template_en": "Where is the Outpatient Department (OPD)?",
        "template_si": "බාහිර රෝගී අංශය (OPD) කොහෙද?",
        "icon": "fa-hospital-user",
        "category": "Directions"
    },
    {
        "id": 2,
        "template": "Where is the emergency unit?",
        "template_en": "Where is the emergency unit?",
        "template_si": "හදිසි අනතුරු අංශය කොහෙද?",
        "icon": "fa-truck-medical",
        "category": "Directions"
    },
    {
        "id": 3,
        "template": "Where is the pharmacy?",
        "template_en": "Where is the pharmacy?",
        "template_si": "ඖෂධ ශාලාව කොහෙද?",
        "icon": "fa-pills",
        "category": "Directions"
    },
    {
        "id": 4,
        "template": "Where is the laboratory?",
        "template_en": "Where is the laboratory?",
        "template_si": "රසායනාගාරය කොහෙද?",
        "icon": "fa-flask-vial",
        "category": "Directions"
    },
    {
        "id": 5,
        "template": "Where is the X-ray room?",
        "template_en": "Where is the X-ray room?",
        "template_si": "X-ray කාමරය කොහෙද?",
        "icon": "fa-x-ray",
        "category": "Directions"
    },
    {
        "id": 6,
        "template": "Where is the toilet?",
        "template_en": "Where is the toilet?",
        "template_si": "වැසිකිළිය කොහෙද?",
        "icon": "fa-restroom",
        "category": "Directions"
    },
    {
        "id": 7,
        "template": "Where is the lift?",
        "template_en": "Where is the lift?",
        "template_si": "සෝපානය කොහෙද?",
        "icon": "fa-elevator",
        "category": "Directions"
    },
    {
        "id": 8,
        "template": "Where is the payment counter?",
        "template_en": "Where is the payment counter?",
        "template_si": "ගෙවීම් කවුන්ටරය කොහෙද?",
        "icon": "fa-cash-register",
        "category": "Directions"
    },
    {
        "id": 9,
        "template": "Where is the ward?",
        "template_en": "Where is the ward?",
        "template_si": "වාට්ටුව කොහෙද?",
        "icon": "fa-bed-pulse",
        "category": "Directions"
    },
    {
        "id": 10,
        "template": "Can you show me the way?",
        "template_en": "Can you show me the way?",
        "template_si": "මට පාර පෙන්වන්න පුළුවන් ද?",
        "icon": "fa-diamond-turn-right",
        "category": "Directions"
    }
]

# Hospital Category 4: 4. රෝග ලක්ෂණ / Symptoms (19 Messages)
HOSPITAL_SYMPTOMS_MESSAGES = [
    {
        "id": 1,
        "template": "I am in pain.",
        "template_en": "I am in pain.",
        "template_si": "මට වේදනාවක් තියෙනවා.",
        "icon": "fa-circle-exclamation",
        "category": "Symptoms"
    },
    {
        "id": 2,
        "template": "I have a headache.",
        "template_en": "I have a headache.",
        "template_si": "මට හිසරදයක් තියෙනවා.",
        "icon": "fa-head-side-virus",
        "category": "Symptoms"
    },
    {
        "id": 3,
        "template": "I have a fever.",
        "template_en": "I have a fever.",
        "template_si": "මට උණ තියෙනවා.",
        "icon": "fa-temperature-high",
        "category": "Symptoms"
    },
    {
        "id": 4,
        "template": "I have a cough.",
        "template_en": "I have a cough.",
        "template_si": "මට කැස්සක් තියෙනවා.",
        "icon": "fa-lungs",
        "category": "Symptoms"
    },
    {
        "id": 5,
        "template": "I have chest pain.",
        "template_en": "I have chest pain.",
        "template_si": "මට පපුවේ වේදනාවක් තියෙනවා.",
        "icon": "fa-heart-crack",
        "category": "Symptoms"
    },
    {
        "id": 6,
        "template": "I have difficulty breathing.",
        "template_en": "I have difficulty breathing.",
        "template_si": "මට හුස්ම ගැනීමට අපහසුයි.",
        "icon": "fa-wind",
        "category": "Symptoms"
    },
    {
        "id": 7,
        "template": "I have stomach pain.",
        "template_en": "I have stomach pain.",
        "template_si": "මට බඩේ කැක්කුමක් තියෙනවා.",
        "icon": "fa-person-dots-from-line",
        "category": "Symptoms"
    },
    {
        "id": 8,
        "template": "I feel dizzy.",
        "template_en": "I feel dizzy.",
        "template_si": "මට හිස කැරකෙනවා.",
        "icon": "fa-rotate",
        "category": "Symptoms"
    },
    {
        "id": 9,
        "template": "I feel nauseous.",
        "template_en": "I feel nauseous.",
        "template_si": "මට වමනය යන්න වගේ.",
        "icon": "fa-face-dizzy",
        "category": "Symptoms"
    },
    {
        "id": 10,
        "template": "I have been vomiting.",
        "template_en": "I have been vomiting.",
        "template_si": "මම වමනය කරනවා.",
        "icon": "fa-face-frown-open",
        "category": "Symptoms"
    },
    {
        "id": 11,
        "template": "I have diarrhoea.",
        "template_en": "I have diarrhoea.",
        "template_si": "මට පාචනයක් තියෙනවා.",
        "icon": "fa-toilet",
        "category": "Symptoms"
    },
    {
        "id": 12,
        "template": "I have back pain.",
        "template_en": "I have back pain.",
        "template_si": "මට කොන්දේ වේදනාවක් තියෙනවා.",
        "icon": "fa-child",
        "category": "Symptoms"
    },
    {
        "id": 13,
        "template": "I have a toothache.",
        "template_en": "I have a toothache.",
        "template_si": "මට දත් කැක්කුමක් තියෙනවා.",
        "icon": "fa-tooth",
        "category": "Symptoms"
    },
    {
        "id": 14,
        "template": "I have a sore throat.",
        "template_en": "I have a sore throat.",
        "template_si": "මට උගුරේ අමාරුවක් තියෙනවා.",
        "icon": "fa-viruses",
        "category": "Symptoms"
    },
    {
        "id": 15,
        "template": "I have a skin rash.",
        "template_en": "I have a skin rash.",
        "template_si": "මගේ සමේ කැසීමක් සහ පැල්ලම් තියෙනවා.",
        "icon": "fa-hand-dots",
        "category": "Symptoms"
    },
    {
        "id": 16,
        "template": "I have a problem with my eye.",
        "template_en": "I have a problem with my eye.",
        "template_si": "මගේ ඇසට ප්රශ්නයක් තියෙනවා.",
        "icon": "fa-eye",
        "category": "Symptoms"
    },
    {
        "id": 17,
        "template": "I have a problem with my ear.",
        "template_en": "I have a problem with my ear.",
        "template_si": "මගේ කණට ප්රශ්නයක් තියෙනවා.",
        "icon": "fa-ear-listen",
        "category": "Symptoms"
    },
    {
        "id": 18,
        "template": "I am bleeding.",
        "template_en": "I am bleeding.",
        "template_si": "මගෙන් ලේ ගලනවා.",
        "icon": "fa-droplet",
        "category": "Symptoms"
    },
    {
        "id": 19,
        "template": "I feel very weak.",
        "template_en": "I feel very weak.",
        "template_si": "මම හරිම දුර්වලයි.",
        "icon": "fa-battery-quarter",
        "category": "Symptoms"
    }
]

# Hospital Category 5: 5. හදිසි අවස්ථාව / Emergency (8 Messages)
HOSPITAL_EMERGENCY_MESSAGES = [
    {
        "id": 1,
        "template": "This is an emergency!",
        "template_en": "This is an emergency!",
        "template_si": "මෙය හදිසි අවස්ථාවක්!",
        "icon": "fa-triangle-exclamation",
        "category": "Emergency"
    },
    {
        "id": 2,
        "template": "Please call a doctor immediately.",
        "template_en": "Please call a doctor immediately.",
        "template_si": "කරුණාකර වහාම වෛද්යවරයෙකු කැඳවන්න.",
        "icon": "fa-user-doctor",
        "category": "Emergency"
    },
    {
        "id": 3,
        "template": "Please call a nurse.",
        "template_en": "Please call a nurse.",
        "template_si": "කරුණාකර හෙදියක් කැඳවන්න.",
        "icon": "fa-user-nurse",
        "category": "Emergency"
    },
    {
        "id": 4,
        "template": "I need an ambulance.",
        "template_en": "I need an ambulance.",
        "template_si": "මට ගිලන් රථයක් අවශ්යයි.",
        "icon": "fa-truck-medical",
        "category": "Emergency"
    },
    {
        "id": 5,
        "template": "I think I am having a heart attack.",
        "template_en": "I think I am having a heart attack.",
        "template_si": "මට හෘදයාබාධයක් වගේ දැනෙනවා.",
        "icon": "fa-heart-crack",
        "category": "Emergency"
    },
    {
        "id": 6,
        "template": "I feel like I am going to faint.",
        "template_en": "I feel like I am going to faint.",
        "template_si": "මට සිහිසුන් වෙන්න යනවා වගේ.",
        "icon": "fa-person-falling",
        "category": "Emergency"
    },
    {
        "id": 7,
        "template": "I have had an accident.",
        "template_en": "I have had an accident.",
        "template_si": "මට අනතුරක් වුණා.",
        "icon": "fa-car-burst",
        "category": "Emergency"
    },
    {
        "id": 8,
        "template": "Please call my family.",
        "template_en": "Please call my family.",
        "template_si": "කරුණාකර මගේ පවුලේ අයට කතා කරන්න.",
        "icon": "fa-phone",
        "category": "Emergency"
    }
]

# Hospital Category 6: 6. වෛද්ය ඉතිහාසය / Medical history (14 Messages)
HOSPITAL_MEDICAL_HISTORY_MESSAGES = [
    {
        "id": 1,
        "template": "I have diabetes.",
        "template_en": "I have diabetes.",
        "template_si": "මට දියවැඩියාව තියෙනවා.",
        "icon": "fa-droplet",
        "category": "Medical history"
    },
    {
        "id": 2,
        "template": "I have high blood pressure.",
        "template_en": "I have high blood pressure.",
        "template_si": "මට අධි රුධිර පීඩනය තියෙනවා.",
        "icon": "fa-heart-pulse",
        "category": "Medical history"
    },
    {
        "id": 3,
        "template": "I have asthma.",
        "template_en": "I have asthma.",
        "template_si": "මට ඇදුම තියෙනවා.",
        "icon": "fa-lungs",
        "category": "Medical history"
    },
    {
        "id": 4,
        "template": "I have a heart condition.",
        "template_en": "I have a heart condition.",
        "template_si": "මට හෘද රෝගයක් තියෙනවා.",
        "icon": "fa-heart",
        "category": "Medical history"
    },
    {
        "id": 5,
        "template": "I am allergic to a medicine.",
        "template_en": "I am allergic to a medicine.",
        "template_si": "මට ඖෂධයකට අසාත්මිකතාවක් තියෙනවා.",
        "icon": "fa-capsules",
        "category": "Medical history"
    },
    {
        "id": 6,
        "template": "I am allergic to penicillin.",
        "template_en": "I am allergic to penicillin.",
        "template_si": "මට පෙනිසිලින් වලට අසාත්මිකයි.",
        "icon": "fa-shield-halved",
        "category": "Medical history"
    },
    {
        "id": 7,
        "template": "I am pregnant.",
        "template_en": "I am pregnant.",
        "template_si": "මම ගර්භණීයි.",
        "icon": "fa-person-breastfeeding",
        "category": "Medical history"
    },
    {
        "id": 8,
        "template": "I take regular medication.",
        "template_en": "I take regular medication.",
        "template_si": "මම නිතර ඖෂධ ගන්නවා.",
        "icon": "fa-pills",
        "category": "Medical history"
    },
    {
        "id": 9,
        "template": "I have no known allergies.",
        "template_en": "I have no known allergies.",
        "template_si": "මට කිසිදු අසාත්මිකතාවක් නැහැ.",
        "icon": "fa-circle-check",
        "category": "Medical history"
    },
    {
        "id": 10,
        "template": "I have had surgery before.",
        "template_en": "I have had surgery before.",
        "template_si": "මට කලින් ශල්යකර්මයක් කරලා තියෙනවා.",
        "icon": "fa-scissors",
        "category": "Medical history"
    },
    {
        "id": 11,
        "template": "I need a blood test.",
        "template_en": "I need a blood test.",
        "template_si": "මට රුධිර පරීක්ෂාවක් අවශ්යයි.",
        "icon": "fa-vial",
        "category": "Medical history"
    },
    {
        "id": 12,
        "template": "I have had this problem since yesterday.",
        "template_en": "I have had this problem since yesterday.",
        "template_si": "මට මේ ප්රශ්නය ඊයේ සිට තියෙනවා.",
        "icon": "fa-calendar-day",
        "category": "Medical history"
    },
    {
        "id": 13,
        "template": "I have had this for several days.",
        "template_en": "I have had this for several days.",
        "template_si": "මට මේක දවස් කිහිපයක් සිට තියෙනවා.",
        "icon": "fa-calendar-week",
        "category": "Medical history"
    },
    {
        "id": 14,
        "template": "This is the first time I have had this.",
        "template_en": "This is the first time I have had this.",
        "template_si": "මට මෙය පළමු වතාවටයි.",
        "icon": "fa-circle-exclamation",
        "category": "Medical history"
    }
]

# Hospital Category 7: 7. වෛද්ය උපදේශනය / Doctor consultation (14 Messages)
HOSPITAL_DOCTOR_CONSULTATION_MESSAGES = [
    {
        "id": 1,
        "template": "Please explain my condition in writing.",
        "template_en": "Please explain my condition in writing.",
        "template_si": "කරුණාකර මගේ තත්ත්වය ලියා පැහැදිලි කරන්න.",
        "icon": "fa-pen-to-square",
        "category": "Doctor consultation"
    },
    {
        "id": 2,
        "template": "What is my diagnosis?",
        "template_en": "What is my diagnosis?",
        "template_si": "මගේ රෝග විනිශ්චය කුමක්ද?",
        "icon": "fa-stethoscope",
        "category": "Doctor consultation"
    },
    {
        "id": 3,
        "template": "Is it serious?",
        "template_en": "Is it serious?",
        "template_si": "මෙය බරපතල ද?",
        "icon": "fa-triangle-exclamation",
        "category": "Doctor consultation"
    },
    {
        "id": 4,
        "template": "Do I need tests?",
        "template_en": "Do I need tests?",
        "template_si": "මට පරීක්ෂණ අවශ්යයි ද?",
        "icon": "fa-microscope",
        "category": "Doctor consultation"
    },
    {
        "id": 5,
        "template": "Do I need surgery?",
        "template_en": "Do I need surgery?",
        "template_si": "මට ශල්යකර්මයක් අවශ්යයි ද?",
        "icon": "fa-syringe",
        "category": "Doctor consultation"
    },
    {
        "id": 6,
        "template": "Do I need to stay in the hospital?",
        "template_en": "Do I need to stay in the hospital?",
        "template_si": "මට රෝහලේ නැවතී සිටිය යුතු ද?",
        "icon": "fa-hospital",
        "category": "Doctor consultation"
    },
    {
        "id": 7,
        "template": "What medicine should I take?",
        "template_en": "What medicine should I take?",
        "template_si": "මම ගත යුතු ඖෂධ මොනවාද?",
        "icon": "fa-pills",
        "category": "Doctor consultation"
    },
    {
        "id": 8,
        "template": "How many times a day should I take it?",
        "template_en": "How many times a day should I take it?",
        "template_si": "දවසකට කී වතාවක් ගත යුතුද?",
        "icon": "fa-clock",
        "category": "Doctor consultation"
    },
    {
        "id": 9,
        "template": "Are there any side effects?",
        "template_en": "Are there any side effects?",
        "template_si": "අතුරු ආබාධ තියෙනවා ද?",
        "icon": "fa-circle-info",
        "category": "Doctor consultation"
    },
    {
        "id": 10,
        "template": "Can I eat before the test?",
        "template_en": "Can I eat before the test?",
        "template_si": "පරීක්ෂණයට පෙර මට කෑමට පුළුවන් ද?",
        "icon": "fa-utensils",
        "category": "Doctor consultation"
    },
    {
        "id": 11,
        "template": "When should I come again?",
        "template_en": "When should I come again?",
        "template_si": "මම නැවත එන්න ඕනේ කවදාද?",
        "icon": "fa-calendar-plus",
        "category": "Doctor consultation"
    },
    {
        "id": 12,
        "template": "Can you write down the instructions?",
        "template_en": "Can you write down the instructions?",
        "template_si": "උපදෙස් ලියා දෙන්න පුළුවන් ද?",
        "icon": "fa-file-lines",
        "category": "Doctor consultation"
    },
    {
        "id": 13,
        "template": "Is a sign language interpreter available?",
        "template_en": "Is a sign language interpreter available?",
        "template_si": "සංඥා භාෂා පරිවර්තකයෙකු ඉන්නවාද?",
        "icon": "fa-hands-asl-interpreting",
        "category": "Doctor consultation"
    },
    {
        "id": 14,
        "template": "Please point to where it hurts or show me.",
        "template_en": "Please point to where it hurts or show me.",
        "template_si": "කරුණාකර රිදෙන තැන පෙන්වන්න.",
        "icon": "fa-hand-pointer",
        "category": "Doctor consultation"
    }
]

# Hospital Category 8: 8. ක්රියාපටිපාටි සහ පහසුව / Procedures and comfort (8 Messages)
HOSPITAL_PROCEDURES_COMFORT_MESSAGES = [
    {
        "id": 1,
        "template": "Please tell me before you examine me.",
        "template_en": "Please tell me before you examine me.",
        "template_si": "පරීක්ෂා කිරීමට පෙර කරුණාකර මට දන්වන්න.",
        "icon": "fa-circle-info",
        "category": "Procedures and comfort"
    },
    {
        "id": 2,
        "template": "Please show me what I need to do.",
        "template_en": "Please show me what I need to do.",
        "template_si": "මා කළ යුත්තේ කුමක්දැයි කරුණාකර පෙන්වන්න.",
        "icon": "fa-arrow-pointer",
        "category": "Procedures and comfort"
    },
    {
        "id": 3,
        "template": "I am afraid.",
        "template_en": "I am afraid.",
        "template_si": "මට බයයි.",
        "icon": "fa-face-frown",
        "category": "Procedures and comfort"
    },
    {
        "id": 4,
        "template": "Please be gentle, it hurts.",
        "template_en": "Please be gentle, it hurts.",
        "template_si": "කරුණාකර සෙමින් කරන්න, රිදෙනවා.",
        "icon": "fa-hand-holding",
        "category": "Procedures and comfort"
    },
    {
        "id": 5,
        "template": "I agree to the procedure.",
        "template_en": "I agree to the procedure.",
        "template_si": "මම මෙම ක්රියාපටිපාටියට එකඟයි.",
        "icon": "fa-circle-check",
        "category": "Procedures and comfort"
    },
    {
        "id": 6,
        "template": "I need more information before I agree.",
        "template_en": "I need more information before I agree.",
        "template_si": "එකඟ වීමට පෙර මට තව තොරතුරු අවශ්යයි.",
        "icon": "fa-circle-question",
        "category": "Procedures and comfort"
    },
    {
        "id": 7,
        "template": "Please let me know when it is my turn.",
        "template_en": "Please let me know when it is my turn.",
        "template_si": "මගේ වාරය පැමිණි විට කරුණාකර මට දන්වන්න.",
        "icon": "fa-clock",
        "category": "Procedures and comfort"
    },
    {
        "id": 8,
        "template": "Please tap my shoulder when it is my turn.",
        "template_en": "Please tap my shoulder when it is my turn.",
        "template_si": "මගේ වාරය පැමිණි විට කරුණාකර මගේ උරහිසට තට්ටු කරන්න.",
        "icon": "fa-hand",
        "category": "Procedures and comfort"
    }
]

# Hospital Category 9: 9. ඖෂධ ශාලාව, බිල්පත් කිරීම සහ බැහැර කිරීම / Pharmacy, billing and discharge (6 Messages)
HOSPITAL_PHARMACY_BILLING_MESSAGES = [
    {
        "id": 1,
        "template": "Please write down how to use this medicine.",
        "template_en": "Please write down how to use this medicine.",
        "template_si": "මෙම ඖෂධය භාවිතා කරන ආකාරය ලියා දෙන්න.",
        "icon": "fa-prescription-bottle-medical",
        "category": "Pharmacy, billing and discharge"
    },
    {
        "id": 2,
        "template": "How much is the bill?",
        "template_en": "How much is the bill?",
        "template_si": "බිල කීයද?",
        "icon": "fa-money-bill-wave",
        "category": "Pharmacy, billing and discharge"
    },
    {
        "id": 3,
        "template": "Can I pay by card?",
        "template_en": "Can I pay by card?",
        "template_si": "කාඩ්පතෙන් ගෙවන්න පුළුවන් ද?",
        "icon": "fa-credit-card",
        "category": "Pharmacy, billing and discharge"
    },
    {
        "id": 4,
        "template": "Where can I collect my reports?",
        "template_en": "Where can I collect my reports?",
        "template_si": "මගේ වාර්තා ලබාගන්නේ කොහෙන්ද?",
        "icon": "fa-file-invoice",
        "category": "Pharmacy, billing and discharge"
    },
    {
        "id": 5,
        "template": "May I go home now?",
        "template_en": "May I go home now?",
        "template_si": "මට දැන් ගෙදර යන්න පුළුවන් ද?",
        "icon": "fa-house-chimney",
        "category": "Pharmacy, billing and discharge"
    },
    {
        "id": 6,
        "template": "Thank you for your help.",
        "template_en": "Thank you for your help.",
        "template_si": "ඔබේ උදව්වට ස්තූතියි.",
        "icon": "fa-hands-clapping",
        "category": "Pharmacy, billing and discharge"
    }
]

HOSPITAL_COMMUNICATION_CATEGORIES = [
    {
        'id': 'basic-comm',
        'key': 'basic-comm',
        'name': '1. මූලික සන්නිවේදනය / Basic communication',
        'name_si': 'මූලික සන්නිවේදනය',
        'name_en': 'Basic communication',
        'icon': 'fa-comments',
        'count': len(HOSPITAL_BASIC_COMMUNICATION_MESSAGES),
        'messages': HOSPITAL_BASIC_COMMUNICATION_MESSAGES
    },
    {
        'id': 'reception',
        'key': 'reception',
        'name': '2. පිළිගැනීම සහ ලියාපදිංචිය / Reception and registration',
        'name_si': 'පිළිගැනීම සහ ලියාපදිංචිය',
        'name_en': 'Reception and registration',
        'icon': 'fa-clipboard-user',
        'count': len(HOSPITAL_RECEPTION_MESSAGES),
        'messages': HOSPITAL_RECEPTION_MESSAGES
    },
    {
        'id': 'directions',
        'key': 'directions',
        'name': '3. දිශාවන් / Directions',
        'name_si': 'දිශාවන්',
        'name_en': 'Directions',
        'icon': 'fa-diamond-turn-right',
        'count': len(HOSPITAL_DIRECTIONS_MESSAGES),
        'messages': HOSPITAL_DIRECTIONS_MESSAGES
    },
    {
        'id': 'symptoms',
        'key': 'symptoms',
        'name': '4. රෝග ලක්ෂණ / Symptoms',
        'name_si': 'රෝග ලක්ෂණ',
        'name_en': 'Symptoms',
        'icon': 'fa-heart-pulse',
        'count': len(HOSPITAL_SYMPTOMS_MESSAGES),
        'messages': HOSPITAL_SYMPTOMS_MESSAGES
    },
    {
        'id': 'emergency',
        'key': 'emergency',
        'name': '5. හදිසි අවස්ථාව / Emergency',
        'name_si': 'හදිසි අවස්ථාව',
        'name_en': 'Emergency',
        'icon': 'fa-truck-medical',
        'count': len(HOSPITAL_EMERGENCY_MESSAGES),
        'messages': HOSPITAL_EMERGENCY_MESSAGES
    },
    {
        'id': 'medical-history',
        'key': 'medical-history',
        'name': '6. වෛද්ය ඉතිහාසය / Medical history',
        'name_si': 'වෛද්ය ඉතිහාසය',
        'name_en': 'Medical history',
        'icon': 'fa-file-waveform',
        'count': len(HOSPITAL_MEDICAL_HISTORY_MESSAGES),
        'messages': HOSPITAL_MEDICAL_HISTORY_MESSAGES
    },
    {
        'id': 'doctor-consultation',
        'key': 'doctor-consultation',
        'name': '7. වෛද්ය උපදේශනය / Doctor consultation',
        'name_si': 'වෛද්ය උපදේශනය',
        'name_en': 'Doctor consultation',
        'icon': 'fa-user-doctor',
        'count': len(HOSPITAL_DOCTOR_CONSULTATION_MESSAGES),
        'messages': HOSPITAL_DOCTOR_CONSULTATION_MESSAGES
    },
    {
        'id': 'procedures-comfort',
        'key': 'procedures-comfort',
        'name': '8. ක්රියාපටිපාටි සහ පහසුව / Procedures and comfort',
        'name_si': 'ක්රියාපටිපාටි සහ පහසුව',
        'name_en': 'Procedures and comfort',
        'icon': 'fa-hand-holding-heart',
        'count': len(HOSPITAL_PROCEDURES_COMFORT_MESSAGES),
        'messages': HOSPITAL_PROCEDURES_COMFORT_MESSAGES
    },
    {
        'id': 'pharmacy-billing',
        'key': 'pharmacy-billing',
        'name': '9. ඖෂධ ශාලාව, බිල්පත් කිරීම සහ බැහැර කිරීම / Pharmacy, billing and discharge',
        'name_si': 'ඖෂධ ශාලාව, බිල්පත් කිරීම සහ බැහැර කිරීම',
        'name_en': 'Pharmacy, billing and discharge',
        'icon': 'fa-receipt',
        'count': len(HOSPITAL_PHARMACY_BILLING_MESSAGES),
        'messages': HOSPITAL_PHARMACY_BILLING_MESSAGES
    }
]

# Bank Category 1: 1. Basic communication (7 Messages)
BANK_BASIC_COMMUNICATION_MESSAGES = [
    {
        "id": 1,
        "template": "I am deaf.",
        "template_en": "I am deaf.",
        "template_si": "මම බිහිරි කෙනෙක්.",
        "icon": "fa-ear-deaf",
        "category": "Basic communication"
    },
    {
        "id": 2,
        "template": "I cannot speak.",
        "template_en": "I cannot speak.",
        "template_si": "මට කතා කරන්න බැහැ.",
        "icon": "fa-comment-slash",
        "category": "Basic communication"
    },
    {
        "id": 3,
        "template": "Please write down your message.",
        "template_en": "Please write down your message.",
        "template_si": "කරුණාකර ඔබේ පණිවිඩය ලියන්න.",
        "icon": "fa-pen-to-square",
        "category": "Basic communication"
    },
    {
        "id": 4,
        "template": "Please speak slowly and face me.",
        "template_en": "Please speak slowly and face me.",
        "template_si": "කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.",
        "icon": "fa-eye",
        "category": "Basic communication"
    },
    {
        "id": 5,
        "template": "Please wait a moment.",
        "template_en": "Please wait a moment.",
        "template_si": "කරුණාකර මොහොතක් රැඳී සිටින්න.",
        "icon": "fa-clock",
        "category": "Basic communication"
    },
    {
        "id": 6,
        "template": "Please repeat that.",
        "template_en": "Please repeat that.",
        "template_si": "කරුණාකර නැවත කියන්න.",
        "icon": "fa-rotate-right",
        "category": "Basic communication"
    },
    {
        "id": 7,
        "template": "I do not understand.",
        "template_en": "I do not understand.",
        "template_si": "මට තේරෙන්නේ නැහැ.",
        "icon": "fa-circle-question",
        "category": "Basic communication"
    }
]

# Bank Category 2: 2. පිළිගැනීමේ අංශය සහ පෝලිම / Reception and queue (8 Messages)
BANK_RECEPTION_QUEUE_MESSAGES = [
    {
        "id": 1,
        "template": "I need help.",
        "template_en": "I need help.",
        "template_si": "මට උදව්වක් අවශ්යයි.",
        "icon": "fa-handshake-angle",
        "category": "Reception and queue"
    },
    {
        "id": 2,
        "template": "Where is the customer service desk?",
        "template_en": "Where is the customer service desk?",
        "template_si": "ගනුදෙනුකරු සේවා මේසය කොහෙද?",
        "icon": "fa-headset",
        "category": "Reception and queue"
    },
    {
        "id": 3,
        "template": "Where do I get a queue token?",
        "template_en": "Where do I get a queue token?",
        "template_si": "පෝලිම් ටෝකන් අංකය ලබාගන්නේ කොහෙන්ද?",
        "icon": "fa-ticket",
        "category": "Reception and queue"
    },
    {
        "id": 4,
        "template": "Which counter should I go to?",
        "template_en": "Which counter should I go to?",
        "template_si": "මම යා යුත්තේ කුමන කවුන්ටරයට ද?",
        "icon": "fa-arrow-right-to-bracket",
        "category": "Reception and queue"
    },
    {
        "id": 5,
        "template": "How long is the waiting time?",
        "template_en": "How long is the waiting time?",
        "template_si": "බලා සිටිය යුතු කාලය කොපමණ ද?",
        "icon": "fa-hourglass-half",
        "category": "Reception and queue"
    },
    {
        "id": 6,
        "template": "Please tap my shoulder when it is my turn.",
        "template_en": "Please tap my shoulder when it is my turn.",
        "template_si": "මගේ වාරය පැමිණි විට කරුණාකර මගේ උරහිසට තට්ටු කරන්න.",
        "icon": "fa-hand-pointer",
        "category": "Reception and queue"
    },
    {
        "id": 7,
        "template": "Please let me know when my number is called.",
        "template_en": "Please let me know when my number is called.",
        "template_si": "මගේ අංකය කැඳවන විට කරුණාකර මට දන්වන්න.",
        "icon": "fa-bullhorn",
        "category": "Reception and queue"
    },
    {
        "id": 8,
        "template": "May I speak to the manager?",
        "template_en": "May I speak to the manager?",
        "template_si": "මට කළමනාකරු හමුවීමට පුළුවන් ද?",
        "icon": "fa-user-tie",
        "category": "Reception and queue"
    }
]

# Bank Category 3: 3. ගිණුමක් විවෘත කිරීම / Opening an account (12 Messages)
BANK_OPEN_ACCOUNT_MESSAGES = [
    {
        "id": 1,
        "template": "I want to open a new account.",
        "template_en": "I want to open a new account.",
        "template_si": "මට නව ගිණුමක් විවෘත කිරීමට අවශ්යයි.",
        "icon": "fa-user-plus",
        "category": "Opening an account"
    },
    {
        "id": 2,
        "template": "I want to open a savings account.",
        "template_en": "I want to open a savings account.",
        "template_si": "මට ඉතිරිකිරීමේ ගිණුමක් විවෘත කිරීමට අවශ්යයි.",
        "icon": "fa-piggy-bank",
        "category": "Opening an account"
    },
    {
        "id": 3,
        "template": "I want to open a current account.",
        "template_en": "I want to open a current account.",
        "template_si": "මට ජංගම ගිණුමක් විවෘත කිරීමට අවශ්යයි.",
        "icon": "fa-briefcase",
        "category": "Opening an account"
    },
    {
        "id": 4,
        "template": "I want to open a fixed deposit.",
        "template_en": "I want to open a fixed deposit.",
        "template_si": "මට ස්ථාවර තැන්පතුවක් ආරම්භ කිරීමට අවශ්යයි.",
        "icon": "fa-vault",
        "category": "Opening an account"
    },
    {
        "id": 5,
        "template": "What documents do I need?",
        "template_en": "What documents do I need?",
        "template_si": "මට අවශ්ය ලේඛන මොනවාද?",
        "icon": "fa-file-lines",
        "category": "Opening an account"
    },
    {
        "id": 6,
        "template": "Here is my National Identity Card.",
        "template_en": "Here is my National Identity Card.",
        "template_si": "මෙන්න මගේ ජාතික හැඳුනුම්පත.",
        "icon": "fa-id-card",
        "category": "Opening an account"
    },
    {
        "id": 7,
        "template": "Here is my passport.",
        "template_en": "Here is my passport.",
        "template_si": "මෙන්න මගේ විදේශ ගමන් බලපත්රය.",
        "icon": "fa-passport",
        "category": "Opening an account"
    },
    {
        "id": 8,
        "template": "Here is my proof of address.",
        "template_en": "Here is my proof of address.",
        "template_si": "මෙන්න මගේ ලිපිනය තහවුරු කරන ලේඛනය.",
        "icon": "fa-house-chimney",
        "category": "Opening an account"
    },
    {
        "id": 9,
        "template": "What is the minimum balance required?",
        "template_en": "What is the minimum balance required?",
        "template_si": "අවශ්ය අවම ශේෂය කීයද?",
        "icon": "fa-scale-balanced",
        "category": "Opening an account"
    },
    {
        "id": 10,
        "template": "Is there a monthly fee?",
        "template_en": "Is there a monthly fee?",
        "template_si": "මාසික ගාස්තුවක් තියෙනවා ද?",
        "icon": "fa-coins",
        "category": "Opening an account"
    },
    {
        "id": 11,
        "template": "Where should I sign?",
        "template_en": "Where should I sign?",
        "template_si": "මම අත්සන් කළ යුත්තේ කොහෙද?",
        "icon": "fa-signature",
        "category": "Opening an account"
    },
    {
        "id": 12,
        "template": "Can I have a copy of the form?",
        "template_en": "Can I have a copy of the form?",
        "template_si": "ෆෝරමයේ පිටපතක් ලබාගන්න පුළුවන් ද?",
        "icon": "fa-copy",
        "category": "Opening an account"
    }
]

# Bank Category 4: 4. තැන්පත් කිරීම් සහ මුදල් ආපසු ගැනීම් / Deposits and withdrawals (12 Messages)
BANK_DEPOSITS_WITHDRAWALS_MESSAGES = [
    {
        "id": 1,
        "template": "I want to deposit money.",
        "template_en": "I want to deposit money.",
        "template_si": "මට මුදල් තැන්පත් කිරීමට අවශ්යයි.",
        "icon": "fa-money-bill-wave",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 2,
        "template": "I want to withdraw money.",
        "template_en": "I want to withdraw money.",
        "template_si": "මට මුදල් ආපසු ගැනීමට අවශ්යයි.",
        "icon": "fa-hand-holding-dollar",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 3,
        "template": "I want to deposit a cheque.",
        "template_en": "I want to deposit a cheque.",
        "template_si": "මට චෙක්පතක් තැන්පත් කිරීමට අවශ්යයි.",
        "icon": "fa-money-check",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 4,
        "template": "I want to cash a cheque.",
        "template_en": "I want to cash a cheque.",
        "template_si": "මට චෙක්පතක් මුදල් බවට හරවා ගැනීම අවශ්යයි.",
        "icon": "fa-money-check-dollar",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 5,
        "template": "How much can I withdraw today?",
        "template_en": "How much can I withdraw today?",
        "template_si": "අද මට උපරිම කොපමණ මුදලක් ආපසු ගත හැකිද?",
        "icon": "fa-calculator",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 6,
        "template": "Please give me small notes.",
        "template_en": "Please give me small notes.",
        "template_si": "කරුණාකර කුඩා නෝට්ටු දෙන්න.",
        "icon": "fa-money-bills",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 7,
        "template": "Please count the money in front of me.",
        "template_en": "Please count the money in front of me.",
        "template_si": "කරුණාකර මා ඉදිරියේ මුදල් ගණන් කරන්න.",
        "icon": "fa-eye",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 8,
        "template": "Here is the deposit slip.",
        "template_en": "Here is the deposit slip.",
        "template_si": "මෙන්න තැන්පතු පත්රිකාව.",
        "icon": "fa-file-invoice",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 9,
        "template": "Where can I get a deposit slip?",
        "template_en": "Where can I get a deposit slip?",
        "template_si": "තැන්පතු පත්රිකාවක් ලබාගන්නේ කොහෙන්ද?",
        "icon": "fa-circle-question",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 10,
        "template": "Please give me a receipt.",
        "template_en": "Please give me a receipt.",
        "template_si": "කරුණාකර රිසිට්පතක් දෙන්න.",
        "icon": "fa-receipt",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 11,
        "template": "What is my account balance?",
        "template_en": "What is my account balance?",
        "template_si": "මගේ ගිණුම් ශේෂය කීයද?",
        "icon": "fa-scale-balanced",
        "category": "Deposits and withdrawals"
    },
    {
        "id": 12,
        "template": "Please update my passbook.",
        "template_en": "Please update my passbook.",
        "template_si": "කරුණාකර මගේ බැංකු පොත යාවත්කාලීන කරන්න.",
        "icon": "fa-book",
        "category": "Deposits and withdrawals"
    }
]

# Bank Category 5: 5. කාඩ්පත් සහ ATM / Cards and ATM (12 Messages)
BANK_CARDS_ATM_MESSAGES = [
    {
        "id": 1,
        "template": "I want to apply for a debit card.",
        "template_en": "I want to apply for a debit card.",
        "template_si": "මට ඩෙබිට් කාඩ්පතක් සඳහා අයදුම් කිරීමට අවශ්යයි.",
        "icon": "fa-credit-card",
        "category": "Cards and ATM"
    },
    {
        "id": 2,
        "template": "I want to apply for a credit card.",
        "template_en": "I want to apply for a credit card.",
        "template_si": "මට ක්රෙඩිට් කාඩ්පතක් සඳහා අයදුම් කිරීමට අවශ්යයි.",
        "icon": "fa-credit-card",
        "category": "Cards and ATM"
    },
    {
        "id": 3,
        "template": "I have lost my card.",
        "template_en": "I have lost my card.",
        "template_si": "මගේ කාඩ්පත නැති වුණා.",
        "icon": "fa-circle-exclamation",
        "category": "Cards and ATM"
    },
    {
        "id": 4,
        "template": "My card was stolen.",
        "template_en": "My card was stolen.",
        "template_si": "මගේ කාඩ්පත සොරකම් වුණා.",
        "icon": "fa-shield-halved",
        "category": "Cards and ATM"
    },
    {
        "id": 5,
        "template": "Please block my card.",
        "template_en": "Please block my card.",
        "template_si": "කරුණාකර මගේ කාඩ්පත අවහිර කරන්න.",
        "icon": "fa-ban",
        "category": "Cards and ATM"
    },
    {
        "id": 6,
        "template": "My card is not working.",
        "template_en": "My card is not working.",
        "template_si": "මගේ කාඩ්පත ක්රියා කරන්නේ නැහැ.",
        "icon": "fa-triangle-exclamation",
        "category": "Cards and ATM"
    },
    {
        "id": 7,
        "template": "The ATM kept my card.",
        "template_en": "The ATM kept my card.",
        "template_si": "ATM යන්ත්රය මගේ කාඩ්පත රඳවා ගත්තා.",
        "icon": "fa-box-archive",
        "category": "Cards and ATM"
    },
    {
        "id": 8,
        "template": "The ATM did not give me the cash.",
        "template_en": "The ATM did not give me the cash.",
        "template_si": "ATM යන්ත්රය මට මුදල් දුන්නේ නැහැ.",
        "icon": "fa-money-bill-circle-xmark",
        "category": "Cards and ATM"
    },
    {
        "id": 9,
        "template": "I forgot my PIN.",
        "template_en": "I forgot my PIN.",
        "template_si": "මට මගේ PIN අංකය අමතක වුණා.",
        "icon": "fa-key",
        "category": "Cards and ATM"
    },
    {
        "id": 10,
        "template": "I want to change my PIN.",
        "template_en": "I want to change my PIN.",
        "template_si": "මට මගේ PIN අංකය වෙනස් කිරීමට අවශ්යයි.",
        "icon": "fa-arrows-rotate",
        "category": "Cards and ATM"
    },
    {
        "id": 11,
        "template": "Where is the ATM?",
        "template_en": "Where is the ATM?",
        "template_si": "ATM යන්ත්රය කොහෙද?",
        "icon": "fa-map-pin",
        "category": "Cards and ATM"
    },
    {
        "id": 12,
        "template": "I want to activate my card.",
        "template_en": "I want to activate my card.",
        "template_si": "මට මගේ කාඩ්පත සක්රිය කිරීමට අවශ්යයි.",
        "icon": "fa-circle-check",
        "category": "Cards and ATM"
    }
]

# Bank Category 6: 6. ණය / Loans (12 Messages)
BANK_LOANS_MESSAGES = [
    {
        "id": 1,
        "template": "I want to apply for a loan.",
        "template_en": "I want to apply for a loan.",
        "template_si": "මට ණයක් සඳහා අයදුම් කිරීමට අවශ්යයි.",
        "icon": "fa-file-signature",
        "category": "Loans"
    },
    {
        "id": 2,
        "template": "I am interested in a personal loan.",
        "template_en": "I am interested in a personal loan.",
        "template_si": "මට පුද්ගලික ණයක් ගැන උනන්දුවක් තියෙනවා.",
        "icon": "fa-user",
        "category": "Loans"
    },
    {
        "id": 3,
        "template": "I am interested in a housing loan.",
        "template_en": "I am interested in a housing loan.",
        "template_si": "මට නිවාස ණයක් ගැන උනන්දුවක් තියෙනවා.",
        "icon": "fa-house",
        "category": "Loans"
    },
    {
        "id": 4,
        "template": "I am interested in a vehicle loan.",
        "template_en": "I am interested in a vehicle loan.",
        "template_si": "මට වාහන ණයක් ගැන උනන්දුවක් තියෙනවා.",
        "icon": "fa-car",
        "category": "Loans"
    },
    {
        "id": 5,
        "template": "What is the interest rate?",
        "template_en": "What is the interest rate?",
        "template_si": "පොලී අනුපාතය කීයද?",
        "icon": "fa-percent",
        "category": "Loans"
    },
    {
        "id": 6,
        "template": "What is the loan period?",
        "template_en": "What is the loan period?",
        "template_si": "ණය කාලය කොපමණද?",
        "icon": "fa-calendar-days",
        "category": "Loans"
    },
    {
        "id": 7,
        "template": "What is the monthly installment?",
        "template_en": "What is the monthly installment?",
        "template_si": "මාසික වාරිකය කීයද?",
        "icon": "fa-calendar-check",
        "category": "Loans"
    },
    {
        "id": 8,
        "template": "What documents are required for the loan?",
        "template_en": "What documents are required for the loan?",
        "template_si": "ණය සඳහා අවශ්ය ලේඛන මොනවාද?",
        "icon": "fa-folder-open",
        "category": "Loans"
    },
    {
        "id": 9,
        "template": "Do I need a guarantor?",
        "template_en": "Do I need a guarantor?",
        "template_si": "මට ඇපකරුවෙකු අවශ්යයි ද?",
        "icon": "fa-user-group",
        "category": "Loans"
    },
    {
        "id": 10,
        "template": "How long will the approval take?",
        "template_en": "How long will the approval take?",
        "template_si": "අනුමැතිය ලැබීමට කොපමණ කාලයක් ගතවේද?",
        "icon": "fa-clock",
        "category": "Loans"
    },
    {
        "id": 11,
        "template": "I want to settle my loan.",
        "template_en": "I want to settle my loan.",
        "template_si": "මට මගේ ණය නිරවුල් කිරීමට අවශ්යයි.",
        "icon": "fa-circle-check",
        "category": "Loans"
    },
    {
        "id": 12,
        "template": "Can I get a loan statement?",
        "template_en": "Can I get a loan statement?",
        "template_si": "මට ණය ප්රකාශයක් ලබාගත හැකිද?",
        "icon": "fa-file-invoice-dollar",
        "category": "Loans"
    }
]

# Bank Category 7: 7. මාරු කිරීම් සහ ගෙවීම් / Transfers and payments (10 Messages)
BANK_TRANSFERS_PAYMENTS_MESSAGES = [
    {
        "id": 1,
        "template": "I want to transfer money.",
        "template_en": "I want to transfer money.",
        "template_si": "මට මුදල් මාරු කිරීමට අවශ්යයි.",
        "icon": "fa-arrow-right-arrow-left",
        "category": "Transfers and payments"
    },
    {
        "id": 2,
        "template": "I want to transfer to another bank.",
        "template_en": "I want to transfer to another bank.",
        "template_si": "මට වෙනත් බැංකුවකට මුදල් මාරු කිරීමට අවශ්යයි.",
        "icon": "fa-building-columns",
        "category": "Transfers and payments"
    },
    {
        "id": 3,
        "template": "Here are the recipient's account details.",
        "template_en": "Here are the recipient's account details.",
        "template_si": "මෙන්න ලබන්නාගේ ගිණුම් විස්තර.",
        "icon": "fa-user-tag",
        "category": "Transfers and payments"
    },
    {
        "id": 4,
        "template": "Is there a transfer fee?",
        "template_en": "Is there a transfer fee?",
        "template_si": "මාරු කිරීමේ ගාස්තුවක් තියෙනවා ද?",
        "icon": "fa-coins",
        "category": "Transfers and payments"
    },
    {
        "id": 5,
        "template": "How long will the transfer take?",
        "template_en": "How long will the transfer take?",
        "template_si": "මාරු කිරීමට කොපමණ කාලයක් ගතවේද?",
        "icon": "fa-hourglass-half",
        "category": "Transfers and payments"
    },
    {
        "id": 6,
        "template": "I want to pay a utility bill.",
        "template_en": "I want to pay a utility bill.",
        "template_si": "මට උපයෝගිතා බිලක් ගෙවීමට අවශ්යයි.",
        "icon": "fa-file-invoice",
        "category": "Transfers and payments"
    },
    {
        "id": 7,
        "template": "I want to pay my credit card bill.",
        "template_en": "I want to pay my credit card bill.",
        "template_si": "මට මගේ ක්රෙඩිට් කාඩ්පත් බිල ගෙවීමට අවශ්යයි.",
        "icon": "fa-credit-card",
        "category": "Transfers and payments"
    },
    {
        "id": 8,
        "template": "I want to send money abroad.",
        "template_en": "I want to send money abroad.",
        "template_si": "මට විදේශයකට මුදල් යැවීමට අවශ්යයි.",
        "icon": "fa-earth-americas",
        "category": "Transfers and payments"
    },
    {
        "id": 9,
        "template": "I want to receive money from abroad.",
        "template_en": "I want to receive money from abroad.",
        "template_si": "මට විදේශයකින් මුදල් ලබාගැනීමට අවශ්යයි.",
        "icon": "fa-globe",
        "category": "Transfers and payments"
    },
    {
        "id": 10,
        "template": "I want to exchange foreign currency.",
        "template_en": "I want to exchange foreign currency.",
        "template_si": "මට විදේශ මුදල් මාරු කරගැනීමට අවශ්යයි.",
        "icon": "fa-money-bill-transfer",
        "category": "Transfers and payments"
    }
]

# Bank Category 8: 8. ගිණුම් සේවා සහ ගැටළු / Account services and problems (12 Messages)
BANK_ACCOUNT_SERVICES_MESSAGES = [
    {
        "id": 1,
        "template": "I need a bank statement.",
        "template_en": "I need a bank statement.",
        "template_si": "මට ගිණුම් ප්රකාශයක් අවශ්යයි.",
        "icon": "fa-file-lines",
        "category": "Account services and problems"
    },
    {
        "id": 2,
        "template": "I need a statement for the last three months.",
        "template_en": "I need a statement for the last three months.",
        "template_si": "මට පසුගිය මාස තුනේ ගිණුම් ප්රකාශයක් අවශ්යයි.",
        "icon": "fa-calendar-week",
        "category": "Account services and problems"
    },
    {
        "id": 3,
        "template": "I want to update my phone number.",
        "template_en": "I want to update my phone number.",
        "template_si": "මට මගේ දුරකථන අංකය යාවත්කාලීන කිරීමට අවශ්යයි.",
        "icon": "fa-phone",
        "category": "Account services and problems"
    },
    {
        "id": 4,
        "template": "I want to update my address.",
        "template_en": "I want to update my address.",
        "template_si": "මට මගේ ලිපිනය යාවත්කාලීන කිරීමට අවශ්යයි.",
        "icon": "fa-location-dot",
        "category": "Account services and problems"
    },
    {
        "id": 5,
        "template": "I want to register for online banking.",
        "template_en": "I want to register for online banking.",
        "template_si": "මට අන්තර්ජාල බැංකුකරණය සඳහා ලියාපදිංචි වීමට අවශ්යයි.",
        "icon": "fa-laptop",
        "category": "Account services and problems"
    },
    {
        "id": 6,
        "template": "I want to set up mobile banking.",
        "template_en": "I want to set up mobile banking.",
        "template_si": "මට ජංගම බැංකුකරණය ස්ථාපිත කිරීමට අවශ්යයි.",
        "icon": "fa-mobile-screen",
        "category": "Account services and problems"
    },
    {
        "id": 7,
        "template": "I forgot my online banking password.",
        "template_en": "I forgot my online banking password.",
        "template_si": "මට මගේ අන්තර්ජාල බැංකු මුරපදය අමතක වුණා.",
        "icon": "fa-key",
        "category": "Account services and problems"
    },
    {
        "id": 8,
        "template": "I am not receiving SMS alerts.",
        "template_en": "I am not receiving SMS alerts.",
        "template_si": "මට SMS දැනුම්දීම් ලැබෙන්නේ නැහැ.",
        "icon": "fa-comment-sms",
        "category": "Account services and problems"
    },
    {
        "id": 9,
        "template": "There is a mistake in my account.",
        "template_en": "There is a mistake in my account.",
        "template_si": "මගේ ගිණුමේ වැරැද්දක් තියෙනවා.",
        "icon": "fa-triangle-exclamation",
        "category": "Account services and problems"
    },
    {
        "id": 10,
        "template": "Money was deducted from my account by mistake.",
        "template_en": "Money was deducted from my account by mistake.",
        "template_si": "මගේ ගිණුමෙන් වැරදීමකින් මුදල් අඩු වී තියෙනවා.",
        "icon": "fa-circle-minus",
        "category": "Account services and problems"
    },
    {
        "id": 11,
        "template": "I want to make a complaint.",
        "template_en": "I want to make a complaint.",
        "template_si": "මට පැමිණිල්ලක් ඉදිරිපත් කිරීමට අවශ්යයි.",
        "icon": "fa-bullhorn",
        "category": "Account services and problems"
    },
    {
        "id": 12,
        "template": "I want to close my account.",
        "template_en": "I want to close my account.",
        "template_si": "මට මගේ ගිණුම වසා දැමීමට අවශ්යයි.",
        "icon": "fa-rectangle-xmark",
        "category": "Account services and problems"
    }
]

# Bank Category 9: 9. ආරක්ෂාව සහ වංචා / Security and fraud (6 Messages)
BANK_SECURITY_FRAUD_MESSAGES = [
    {
        "id": 1,
        "template": "I think someone has accessed my account without permission.",
        "template_en": "I think someone has accessed my account without permission.",
        "template_si": "මගේ ගිණුමට අවසරයකින් තොරව කවුරුහරි ඇතුළු වී ඇති බව මට හැඟෙනවා.",
        "icon": "fa-user-secret",
        "category": "Security and fraud"
    },
    {
        "id": 2,
        "template": "I received a suspicious message or call.",
        "template_en": "I received a suspicious message or call.",
        "template_si": "මට සැක සහිත පණිවිඩයක් හෝ ඇමතුමක් ලැබුණා.",
        "icon": "fa-triangle-exclamation",
        "category": "Security and fraud"
    },
    {
        "id": 3,
        "template": "I did not make this transaction.",
        "template_en": "I did not make this transaction.",
        "template_si": "මම මෙම ගනුදෙනුව කළේ නැහැ.",
        "icon": "fa-shield-halved",
        "category": "Security and fraud"
    },
    {
        "id": 4,
        "template": "Please freeze my account.",
        "template_en": "Please freeze my account.",
        "template_si": "කරුණාකර මගේ ගිණුම අත්හිටුවන්න.",
        "icon": "fa-snowflake",
        "category": "Security and fraud"
    },
    {
        "id": 5,
        "template": "I want to change my password.",
        "template_en": "I want to change my password.",
        "template_si": "මට මගේ මුරපදය වෙනස් කිරීමට අවශ්යයි.",
        "icon": "fa-lock",
        "category": "Security and fraud"
    },
    {
        "id": 6,
        "template": "Please do not share my details with anyone.",
        "template_en": "Please do not share my details with anyone.",
        "template_si": "කරුණාකර මගේ තොරතුරු කිසිවෙකු සමඟ බෙදා නොගන්න.",
        "icon": "fa-user-lock",
        "category": "Security and fraud"
    }
]

# Bank Category 10: 10. ආචාරශීලී වදන් සහ සමුගැනීම / Closing and courtesy (6 Messages)
BANK_CLOSING_COURTESY_MESSAGES = [
    {
        "id": 1,
        "template": "Can you explain this in writing?",
        "template_en": "Can you explain this in writing?",
        "template_si": "මෙය ලියා පැහැදිලි කරන්න පුළුවන් ද?",
        "icon": "fa-pen-to-square",
        "category": "Closing and courtesy"
    },
    {
        "id": 2,
        "template": "Please write down the amount.",
        "template_en": "Please write down the amount.",
        "template_si": "කරුණාකර මුදල ලියන්න.",
        "icon": "fa-pen",
        "category": "Closing and courtesy"
    },
    {
        "id": 3,
        "template": "Is a sign language interpreter available?",
        "template_en": "Is a sign language interpreter available?",
        "template_si": "සංඥා භාෂා පරිවර්තකයෙකු ඉන්නවාද?",
        "icon": "fa-hands-asl-interpreting",
        "category": "Closing and courtesy"
    },
    {
        "id": 4,
        "template": "May I bring someone to help me?",
        "template_en": "May I bring someone to help me?",
        "template_si": "මට උදව් කිරීමට කෙනෙකු රැගෙන එන්න පුළුවන් ද?",
        "icon": "fa-person-circle-question",
        "category": "Closing and courtesy"
    },
    {
        "id": 5,
        "template": "Is everything complete?",
        "template_en": "Is everything complete?",
        "template_si": "සියල්ල අවසන් ද?",
        "icon": "fa-circle-check",
        "category": "Closing and courtesy"
    },
    {
        "id": 6,
        "template": "Thank you for your help.",
        "template_en": "Thank you for your help.",
        "template_si": "ඔබේ උදව්වට ස්තූතියි.",
        "icon": "fa-handshake",
        "category": "Closing and courtesy"
    }
]

BANK_COMMUNICATION_CATEGORIES = [
    {
        'id': 'bank-basic-comm',
        'key': 'bank-basic-comm',
        'name': '1. මූලික සන්නිවේදනය / Basic communication',
        'name_si': 'මූලික සන්නිවේදනය',
        'name_en': 'Basic communication',
        'icon': 'fa-comments',
        'count': len(BANK_BASIC_COMMUNICATION_MESSAGES),
        'messages': BANK_BASIC_COMMUNICATION_MESSAGES
    },
    {
        'id': 'bank-reception-queue',
        'key': 'bank-reception-queue',
        'name': '2. පිළිගැනීමේ අංශය සහ පෝලිම / Reception and queue',
        'name_si': 'පිළිගැනීමේ අංශය සහ පෝලිම',
        'name_en': 'Reception and queue',
        'icon': 'fa-users-line',
        'count': len(BANK_RECEPTION_QUEUE_MESSAGES),
        'messages': BANK_RECEPTION_QUEUE_MESSAGES
    },
    {
        'id': 'bank-open-account',
        'key': 'bank-open-account',
        'name': '3. ගිණුමක් විවෘත කිරීම / Opening an account',
        'name_si': 'ගිණුමක් විවෘත කිරීම',
        'name_en': 'Opening an account',
        'icon': 'fa-user-plus',
        'count': len(BANK_OPEN_ACCOUNT_MESSAGES),
        'messages': BANK_OPEN_ACCOUNT_MESSAGES
    },
    {
        'id': 'bank-deposits-withdrawals',
        'key': 'bank-deposits-withdrawals',
        'name': '4. තැන්පත් කිරීම් සහ මුදල් ආපසු ගැනීම් / Deposits and withdrawals',
        'name_si': 'තැන්පත් කිරීම් සහ මුදල් ආපසු ගැනීම්',
        'name_en': 'Deposits and withdrawals',
        'icon': 'fa-money-bill-wave',
        'count': len(BANK_DEPOSITS_WITHDRAWALS_MESSAGES),
        'messages': BANK_DEPOSITS_WITHDRAWALS_MESSAGES
    },
    {
        'id': 'bank-cards-atm',
        'key': 'bank-cards-atm',
        'name': '5. කාඩ්පත් සහ ATM / Cards and ATM',
        'name_si': 'කාඩ්පත් සහ ATM',
        'name_en': 'Cards and ATM',
        'icon': 'fa-credit-card',
        'count': len(BANK_CARDS_ATM_MESSAGES),
        'messages': BANK_CARDS_ATM_MESSAGES
    },
    {
        'id': 'bank-loans',
        'key': 'bank-loans',
        'name': '6. ණය / Loans',
        'name_si': 'ණය',
        'name_en': 'Loans',
        'icon': 'fa-hand-holding-dollar',
        'count': len(BANK_LOANS_MESSAGES),
        'messages': BANK_LOANS_MESSAGES
    },
    {
        'id': 'bank-transfers-payments',
        'key': 'bank-transfers-payments',
        'name': '7. මාරු කිරීම් සහ ගෙවීම් / Transfers and payments',
        'name_si': 'මාරු කිරීම් සහ ගෙවීම්',
        'name_en': 'Transfers and payments',
        'icon': 'fa-arrow-right-arrow-left',
        'count': len(BANK_TRANSFERS_PAYMENTS_MESSAGES),
        'messages': BANK_TRANSFERS_PAYMENTS_MESSAGES
    },
    {
        'id': 'bank-account-services',
        'key': 'bank-account-services',
        'name': '8. ගිණුම් සේවා සහ ගැටළු / Account services and problems',
        'name_si': 'ගිණුම් සේවා සහ ගැටළු',
        'name_en': 'Account services and problems',
        'icon': 'fa-file-lines',
        'count': len(BANK_ACCOUNT_SERVICES_MESSAGES),
        'messages': BANK_ACCOUNT_SERVICES_MESSAGES
    },
    {
        'id': 'bank-security-fraud',
        'key': 'bank-security-fraud',
        'name': '9. ආරක්ෂාව සහ වංචා / Security and fraud',
        'name_si': 'ආරක්ෂාව සහ වංචා',
        'name_en': 'Security and fraud',
        'icon': 'fa-shield-halved',
        'count': len(BANK_SECURITY_FRAUD_MESSAGES),
        'messages': BANK_SECURITY_FRAUD_MESSAGES
    },
    {
        'id': 'bank-closing-courtesy',
        'key': 'bank-closing-courtesy',
        'name': '10. ආචාරශීලී වදන් සහ සමුගැනීම / Closing and courtesy',
        'name_si': 'ආචාරශීලී වදන් සහ සමුගැනීම',
        'name_en': 'Closing and courtesy',
        'icon': 'fa-handshake',
        'count': len(BANK_CLOSING_COURTESY_MESSAGES),
        'messages': BANK_CLOSING_COURTESY_MESSAGES
    }
]

# Restaurant Communication Messages
RESTAURANT_BASIC_COMMUNICATION_MESSAGES = [
    {
        "id": 1,
        "template": "A table for one, please.",
        "template_en": "A table for one, please.",
        "template_si": "කරුණාකර එක් අයෙකුට මේසයක් ලබාදෙන්න.",
        "icon": "fa-user",
        "category": "Basic communication"
    },
    {
        "id": 2,
        "template": "A table for two, please.",
        "template_en": "A table for two, please.",
        "template_si": "කරුණාකර දෙදෙනෙකුට මේසයක් ලබාදෙන්න.",
        "icon": "fa-user-group",
        "category": "Basic communication"
    },
    {
        "id": 3,
        "template": "I am deaf / non-verbal. Please write down instructions.",
        "template_en": "I am deaf / non-verbal. Please write down instructions.",
        "template_si": "මම බිහිරි/කතා කළ නොහැකි අයෙක්. කරුණාකර ලියා පෙන්වන්න.",
        "icon": "fa-ear-deaf",
        "category": "Basic communication"
    },
    {
        "id": 4,
        "template": "Can I see the menu, please?",
        "template_en": "Can I see the menu, please?",
        "template_si": "කරුණාකර මෙනුව බලන්න පුළුවන් ද?",
        "icon": "fa-book-open",
        "category": "Basic communication"
    },
    {
        "id": 5,
        "template": "Please wait a moment.",
        "template_en": "Please wait a moment.",
        "template_si": "කරුණාකර මොහොතක් රැඳී සිටින්න.",
        "icon": "fa-hourglass-half",
        "category": "Basic communication"
    },
    {
        "id": 6,
        "template": "Where is the restroom?",
        "template_en": "Where is the restroom?",
        "template_si": "වැසිකිළිය කොහෙද?",
        "icon": "fa-restroom",
        "category": "Basic communication"
    }
]

RESTAURANT_ORDERING_MESSAGES = [
    {
        "id": 1,
        "template": "I am ready to order.",
        "template_en": "I am ready to order.",
        "template_si": "මම ඇනවුම් කිරීමට සූදානම්.",
        "icon": "fa-circle-check",
        "category": "Ordering food"
    },
    {
        "id": 2,
        "template": "What do you recommend?",
        "template_en": "What do you recommend?",
        "template_si": "ඔබ නිර්දේශ කරන්නේ කුමන කෑමද?",
        "icon": "fa-star",
        "category": "Ordering food"
    },
    {
        "id": 3,
        "template": "I would like a glass of water, please.",
        "template_en": "I would like a glass of water, please.",
        "template_si": "කරුණාකර මට වතුර වීදුරුවක් දෙන්න.",
        "icon": "fa-glass-water",
        "category": "Ordering food"
    },
    {
        "id": 4,
        "template": "I would like to order rice.",
        "template_en": "I would like to order rice.",
        "template_si": "මට බත් ඇනවුම් කිරීමට අවශ්‍යයි.",
        "icon": "fa-bowl-rice",
        "category": "Ordering food"
    },
    {
        "id": 5,
        "template": "I would like to order noodles / pasta.",
        "template_en": "I would like to order noodles / pasta.",
        "template_si": "මට නූඩ්ල්ස් / පැස්ටා ඇනවුම් කිරීමට අවශ්‍යයි.",
        "icon": "fa-plate-wheat",
        "category": "Ordering food"
    },
    {
        "id": 6,
        "template": "Please make it less spicy.",
        "template_en": "Please make it less spicy.",
        "template_si": "කරුණාකර සැර අඩුවෙන් සාදන්න.",
        "icon": "fa-pepper-hot",
        "category": "Ordering food"
    },
    {
        "id": 7,
        "template": "Can I change my order?",
        "template_en": "Can I change my order?",
        "template_si": "මගේ ඇනවුම වෙනස් කළ හැකිද?",
        "icon": "fa-pen-to-square",
        "category": "Ordering food"
    },
    {
        "id": 8,
        "template": "How long will the food take?",
        "template_en": "How long will the food take?",
        "template_si": "කෑම ලැබීමට කොපමණ වේලාවක් ගතවේද?",
        "icon": "fa-clock",
        "category": "Ordering food"
    }
]

RESTAURANT_ALLERGIES_DIETARY_MESSAGES = [
    {
        "id": 1,
        "template": "I have a food allergy.",
        "template_en": "I have a food allergy.",
        "template_si": "මට ආහාර අසාත්මිකතාවයක් තියෙනවා.",
        "icon": "fa-triangle-exclamation",
        "category": "Allergies & Dietary"
    },
    {
        "id": 2,
        "template": "Is this dish vegetarian / vegan?",
        "template_en": "Is this dish vegetarian / vegan?",
        "template_si": "මෙම කෑම නිර්මාංශද?",
        "icon": "fa-seedling",
        "category": "Allergies & Dietary"
    },
    {
        "id": 3,
        "template": "Does this contain nuts or dairy?",
        "template_en": "Does this contain nuts or dairy?",
        "template_si": "මෙහි රටකජු හෝ කිරි අඩංගුද?",
        "icon": "fa-shield-halved",
        "category": "Allergies & Dietary"
    },
    {
        "id": 4,
        "template": "Does this contain seafood?",
        "template_en": "Does this contain seafood?",
        "template_si": "මෙහි මුහුදු ආහාර අඩංගුද?",
        "icon": "fa-shrimp",
        "category": "Allergies & Dietary"
    },
    {
        "id": 5,
        "template": "No sugar / less sugar, please.",
        "template_en": "No sugar / less sugar, please.",
        "template_si": "සීනි නොමැතිව / සීනි අඩුවෙන් දෙන්න.",
        "icon": "fa-cubes-stacked",
        "category": "Allergies & Dietary"
    },
    {
        "id": 6,
        "template": "Is this food Halal?",
        "template_en": "Is this food Halal?",
        "template_si": "මෙම ආහාර හලාල් ද?",
        "icon": "fa-certificate",
        "category": "Allergies & Dietary"
    }
]

RESTAURANT_BILLING_PAYMENT_MESSAGES = [
    {
        "id": 1,
        "template": "Can I have the bill, please?",
        "template_en": "Can I have the bill, please?",
        "template_si": "කරුණාකර බිල ලබාදෙන්න.",
        "icon": "fa-receipt",
        "category": "Payment & Service"
    },
    {
        "id": 2,
        "template": "Are card payments accepted?",
        "template_en": "Are card payments accepted?",
        "template_si": "කාඩ්පත් මඟින් ගෙවීම් පිළිගන්නවාද?",
        "icon": "fa-credit-card",
        "category": "Payment & Service"
    },
    {
        "id": 3,
        "template": "Can I pay by cash?",
        "template_en": "Can I pay by cash?",
        "template_si": "මට මුදලින් ගෙවිය හැකිද?",
        "icon": "fa-money-bill-wave",
        "category": "Payment & Service"
    },
    {
        "id": 4,
        "template": "Can I have a receipt?",
        "template_en": "Can I have a receipt?",
        "template_si": "කරුණාකර රිසිට්පතක් ලබාදෙන්න.",
        "icon": "fa-file-invoice",
        "category": "Payment & Service"
    },
    {
        "id": 5,
        "template": "Thank you, the food was delicious!",
        "template_en": "Thank you, the food was delicious!",
        "template_si": "ස්තූතියි, කෑම ඉතා රසවත්!",
        "icon": "fa-thumbs-up",
        "category": "Payment & Service"
    },
    {
        "id": 6,
        "template": "Thank you for your service.",
        "template_en": "Thank you for your service.",
        "template_si": "ඔබේ සේවයට ස්තූතියි.",
        "icon": "fa-heart",
        "category": "Payment & Service"
    }
]

RESTAURANT_COMMUNICATION_CATEGORIES = [
    {
        'id': 'rest-basic-comm',
        'key': 'rest-basic-comm',
        'name': '1. මූලික සන්නිවේදනය / Basic communication',
        'name_si': 'මූලික සන්නිවේදනය',
        'name_en': 'Basic communication',
        'icon': 'fa-comments',
        'count': len(RESTAURANT_BASIC_COMMUNICATION_MESSAGES),
        'messages': RESTAURANT_BASIC_COMMUNICATION_MESSAGES
    },
    {
        'id': 'rest-ordering',
        'key': 'rest-ordering',
        'name': '2. කෑම ඇනවුම් කිරීම / Ordering food',
        'name_si': 'කෑම ඇනවුම් කිරීම',
        'name_en': 'Ordering food',
        'icon': 'fa-bowl-food',
        'count': len(RESTAURANT_ORDERING_MESSAGES),
        'messages': RESTAURANT_ORDERING_MESSAGES
    },
    {
        'id': 'rest-allergies',
        'key': 'rest-allergies',
        'name': '3. අසාත්මිකතා සහ මනාපයන් / Allergies and preferences',
        'name_si': 'අසාත්මිකතා සහ මනාපයන්',
        'name_en': 'Allergies and preferences',
        'icon': 'fa-wheat-awn-circle-exclamation',
        'count': len(RESTAURANT_ALLERGIES_DIETARY_MESSAGES),
        'messages': RESTAURANT_ALLERGIES_DIETARY_MESSAGES
    },
    {
        'id': 'rest-billing',
        'key': 'rest-billing',
        'name': '4. ගෙවීම් සහ සමුගැනීම / Billing and payment',
        'name_si': 'ගෙවීම් සහ සමුගැනීම',
        'name_en': 'Billing and payment',
        'icon': 'fa-receipt',
        'count': len(RESTAURANT_BILLING_PAYMENT_MESSAGES),
        'messages': RESTAURANT_BILLING_PAYMENT_MESSAGES
    }
]

# Predefined location messages and styling presets
LOCATION_PRESETS = {
    'hospital': {
        'slug': 'hospital',
        'name': 'Hospital & Healthcare',
        'short_name': 'Hospital',
        'icon': 'fa-hospital',
        'badge_icon': 'fa-location-dot',
        'theme_color': '#f43f5e',
        'bg_color': '#ffe4e6',
        'category_name': '1. මූලික සන්නිවේදනය / Basic communication',
        'category_name_si': 'මූලික සන්නිවේදනය',
        'category_name_en': 'Basic communication',
        'categories': HOSPITAL_COMMUNICATION_CATEGORIES,
        'hospital_categories': {
            'basic-comm': HOSPITAL_BASIC_COMMUNICATION_MESSAGES,
            'reception': HOSPITAL_RECEPTION_MESSAGES,
            'directions': HOSPITAL_DIRECTIONS_MESSAGES,
            'symptoms': HOSPITAL_SYMPTOMS_MESSAGES,
            'emergency': HOSPITAL_EMERGENCY_MESSAGES,
            'medical-history': HOSPITAL_MEDICAL_HISTORY_MESSAGES,
            'doctor-consultation': HOSPITAL_DOCTOR_CONSULTATION_MESSAGES,
            'procedures-comfort': HOSPITAL_PROCEDURES_COMFORT_MESSAGES,
            'pharmacy-billing': HOSPITAL_PHARMACY_BILLING_MESSAGES
        },
        'messages': HOSPITAL_BASIC_COMMUNICATION_MESSAGES
    },
    'supermarket': {
        'slug': 'supermarket',
        'name': 'Supermarket & Groceries',
        'short_name': 'Supermarket',
        'icon': 'fa-cart-shopping',
        'badge_icon': 'fa-cart-shopping',
        'theme_color': '#10b981',
        'bg_color': '#d1fae5',
        'messages': []
    },
    'restaurant': {
        'slug': 'restaurant',
        'name': 'Popular Restaurant & Dining',
        'short_name': 'Restaurant',
        'icon': 'fa-utensils',
        'badge_icon': 'fa-utensils',
        'theme_color': '#f59e0b',
        'bg_color': '#fef3c7',
        'category_name': '1. මූලික සන්නිවේදනය / Basic communication',
        'category_name_si': 'මූලික සන්නිවේදනය',
        'category_name_en': 'Basic communication',
        'categories': RESTAURANT_COMMUNICATION_CATEGORIES,
        'restaurant_categories': {
            'rest-basic-comm': RESTAURANT_BASIC_COMMUNICATION_MESSAGES,
            'rest-ordering': RESTAURANT_ORDERING_MESSAGES,
            'rest-allergies': RESTAURANT_ALLERGIES_DIETARY_MESSAGES,
            'rest-billing': RESTAURANT_BILLING_PAYMENT_MESSAGES,
        },
        'messages': []
    },
    'bank': {
        'slug': 'bank',
        'name': 'Bank & Financial Services',
        'short_name': 'Bank',
        'icon': 'fa-building-columns',
        'badge_icon': 'fa-building-columns',
        'theme_color': '#2563eb',
        'bg_color': '#dbeafe',
        'category_name': '1. මූලික සන්නිවේදනය / Basic communication',
        'category_name_si': 'මූලික සන්නිවේදනය',
        'category_name_en': 'Basic communication',
        'categories': BANK_COMMUNICATION_CATEGORIES,
        'bank_categories': {
            'bank-basic-comm': BANK_BASIC_COMMUNICATION_MESSAGES,
            'bank-reception-queue': BANK_RECEPTION_QUEUE_MESSAGES,
            'bank-open-account': BANK_OPEN_ACCOUNT_MESSAGES,
            'bank-deposits-withdrawals': BANK_DEPOSITS_WITHDRAWALS_MESSAGES,
            'bank-cards-atm': BANK_CARDS_ATM_MESSAGES,
            'bank-loans': BANK_LOANS_MESSAGES,
            'bank-transfers-payments': BANK_TRANSFERS_PAYMENTS_MESSAGES,
            'bank-account-services': BANK_ACCOUNT_SERVICES_MESSAGES,
            'bank-security-fraud': BANK_SECURITY_FRAUD_MESSAGES,
            'bank-closing-courtesy': BANK_CLOSING_COURTESY_MESSAGES,
        },
        'messages': []
    },
    'pharmacy': {
        'slug': 'pharmacy',
        'name': 'Pharmacy & Chemist',
        'short_name': 'Pharmacy',
        'icon': 'fa-prescription-bottle-medical',
        'badge_icon': 'fa-prescription-bottle-medical',
        'theme_color': '#8b5cf6',
        'bg_color': '#ede9fe',
        'messages': []
    },
    'other': {
        'slug': 'other',
        'name': 'Outside Hospital',
        'short_name': 'Outside Hospital',
        'icon': 'fa-location-dot',
        'badge_icon': 'fa-location-dot',
        'theme_color': '#6366f1',
        'bg_color': '#e0e7ff',
        'messages': []
    }
}

def _attach_preset(result, slug, lat=None, lon=None):
    preset = LOCATION_PRESETS.get(slug, LOCATION_PRESETS['other'])
    result['location_name'] = preset['short_name']
    result['theme_color'] = preset['theme_color']
    result['bg_color'] = preset['bg_color']
    result['badge_icon'] = preset['badge_icon']
    result['category_name'] = preset.get('category_name', '')
    result['category_name_si'] = preset.get('category_name_si', '')
    result['category_name_en'] = preset.get('category_name_en', '')
    result['messages'] = preset['messages']
    result['categories'] = preset.get('categories', [])
    result['hospital_categories'] = preset.get('hospital_categories', {})
    result['bank_categories'] = preset.get('bank_categories', {})
    result['restaurant_categories'] = preset.get('restaurant_categories', {})
    result['is_hospital'] = (slug == 'hospital')
    result['is_bank'] = (slug == 'bank')
    result['is_restaurant'] = (slug == 'restaurant')
    result['is_predefined'] = (slug in ['hospital', 'supermarket', 'restaurant', 'bank', 'pharmacy'])
    if lat is not None:
        result['lat'] = float(lat)
    if lon is not None:
        result['lon'] = float(lon)
    result['predefined_coordinates'] = PREDEFINED_COORDINATES
    result['sri_lanka_hospitals'] = SRI_LANKA_HOSPITALS
    result['sri_lanka_banks'] = SRI_LANKA_BANKS
    result['sri_lanka_restaurants'] = SRI_LANKA_RESTAURANTS
    return result

def select_hospital_by_id(hospital_id=None, name=None):
    """
    Manually selects a Sri Lanka hospital by ID or name and returns
    preset payload with the 11 communication messages.
    """
    matched = None
    if hospital_id:
        for hosp in SRI_LANKA_HOSPITALS:
            if hosp['id'] == hospital_id:
                matched = hosp
                break
    if not matched and name:
        name_l = name.lower()
        for hosp in SRI_LANKA_HOSPITALS:
            if name_l in hosp['name'].lower() or name_l in hosp['short_name'].lower():
                matched = hosp
                break
    if not matched:
        matched = SRI_LANKA_HOSPITALS[0]

    lat = matched['lat']
    lon = matched['lon']
    res = {
        'success': True,
        'detected_slug': 'hospital',
        'is_hospital': True,
        'is_predefined': True,
        'manually_selected': True,
        'poi_name': matched['name'],
        'location_name': 'Hospital & Healthcare',
        'address': f"{matched['name']}, {matched['city']}, {matched['district']} District",
        'emergency_hotline': matched.get('emergency', '1990'),
        'hospital_info': matched,
        'area_name': f"{matched['city']}, Sri Lanka",
        'lat': lat,
        'lon': lon
    }
    return _attach_preset(res, 'hospital', lat, lon)

def select_bank_by_id(bank_id=None, name=None):
    """
    Manually selects a Sri Lanka bank by ID or name and returns
    preset payload.
    """
    matched = None
    if bank_id:
        for b in SRI_LANKA_BANKS:
            if b['id'] == bank_id:
                matched = b
                break
    if not matched and name:
        name_l = name.lower()
        for b in SRI_LANKA_BANKS:
            if name_l in b['name'].lower() or name_l in b['short_name'].lower() or name_l in b.get('bank_name', '').lower():
                matched = b
                break
    if not matched:
        matched = SRI_LANKA_BANKS[0]

    lat = matched['lat']
    lon = matched['lon']
    res = {
        'success': True,
        'detected_slug': 'bank',
        'is_bank': True,
        'is_predefined': True,
        'manually_selected': True,
        'poi_name': matched['name'],
        'location_name': 'Bank & Financial Services',
        'address': f"{matched['name']}, {matched['city']}, {matched['district']} District",
        'bank_hotline': matched.get('hotline', '1975'),
        'bank_info': matched,
        'area_name': f"{matched['city']}, Sri Lanka",
        'lat': lat,
        'lon': lon
    }
    return _attach_preset(res, 'bank', lat, lon)

def select_restaurant_by_id(restaurant_id=None, name=None):
    """
    Manually selects a Sri Lanka restaurant by ID or name and returns
    preset payload.
    """
    matched = None
    if restaurant_id:
        for r in SRI_LANKA_RESTAURANTS:
            if r['id'] == restaurant_id:
                matched = r
                break
    if not matched and name:
        name_l = name.lower()
        for r in SRI_LANKA_RESTAURANTS:
            if name_l in r['name'].lower() or name_l in r['short_name'].lower() or name_l in r.get('restaurant_name', '').lower():
                matched = r
                break
    if not matched:
        matched = SRI_LANKA_RESTAURANTS[0]

    lat = matched['lat']
    lon = matched['lon']
    res = {
        'success': True,
        'detected_slug': 'restaurant',
        'is_restaurant': True,
        'is_predefined': True,
        'manually_selected': True,
        'poi_name': matched['name'],
        'location_name': 'Popular Restaurant & Dining',
        'address': f"{matched['name']}, {matched['city']}, {matched['district']} District",
        'restaurant_phone': matched.get('phone', ''),
        'restaurant_info': matched,
        'area_name': f"{matched['city']}, Sri Lanka",
        'lat': lat,
        'lon': lon
    }
    return _attach_preset(res, 'restaurant', lat, lon)

def detect_place_by_coordinates(lat, lon):
    """
    Attempts to reverse geocode lat/lon into a location category:
    hospital, supermarket, restaurant, bank, pharmacy, or other.
    Uses OpenStreetMap Nominatim API with fallback support.
    """
    lat_f = float(lat)
    lon_f = float(lon)
    try:
        # Find closest venue among known Sri Lanka hospitals, banks, and restaurants within ~0.8km (800m)
        closest_candidates = []

        for hosp in SRI_LANKA_HOSPITALS:
            dist = calculate_distance_km(lat_f, lon_f, hosp['lat'], hosp['lon'])
            if dist <= 0.8:
                closest_candidates.append((dist, 'hospital', hosp))

        for bank in SRI_LANKA_BANKS:
            dist = calculate_distance_km(lat_f, lon_f, bank['lat'], bank['lon'])
            if dist <= 0.8:
                closest_candidates.append((dist, 'bank', bank))

        for rest in SRI_LANKA_RESTAURANTS:
            dist = calculate_distance_km(lat_f, lon_f, rest['lat'], rest['lon'])
            if dist <= 0.8:
                closest_candidates.append((dist, 'restaurant', rest))

        if closest_candidates:
            closest_candidates.sort(key=lambda x: x[0])
            best_dist, best_type, best_item = closest_candidates[0]
            if best_type == 'hospital':
                res = {
                    'success': True,
                    'detected_slug': 'hospital',
                    'is_hospital': True,
                    'poi_name': best_item['name'],
                    'address': f"{best_item['name']}, {best_item['city']} ({round(best_dist*1000)}m away)",
                    'emergency_hotline': best_item.get('emergency', '1990'),
                    'hospital_info': best_item
                }
                return _attach_preset(res, 'hospital', lat_f, lon_f)
            elif best_type == 'bank':
                res = {
                    'success': True,
                    'detected_slug': 'bank',
                    'is_bank': True,
                    'poi_name': best_item['name'],
                    'address': f"{best_item['name']}, {best_item['city']} ({round(best_dist*1000)}m away)",
                    'bank_hotline': best_item.get('hotline', '1975'),
                    'bank_info': best_item
                }
                return _attach_preset(res, 'bank', lat_f, lon_f)
            elif best_type == 'restaurant':
                res = {
                    'success': True,
                    'detected_slug': 'restaurant',
                    'is_restaurant': True,
                    'poi_name': best_item['name'],
                    'address': f"{best_item['name']}, {best_item['city']} ({round(best_dist*1000)}m away)",
                    'restaurant_phone': best_item.get('phone', ''),
                    'restaurant_info': best_item
                }
                return _attach_preset(res, 'restaurant', lat_f, lon_f)

        # Check if coordinates match predefined simulation points within ~0.005 deg (~500m)
        for key, ref in PREDEFINED_COORDINATES.items():
            if abs(lat_f - ref['lat']) < 0.005 and abs(lon_f - ref['lon']) < 0.005:
                res = {
                    'success': True,
                    'detected_slug': ref['slug'],
                    'poi_name': ref['name'],
                    'address': f"{ref['name']}, Detected via GPS"
                }
                return _attach_preset(res, ref['slug'], lat_f, lon_f)

        headers = {
            'User-Agent': 'DeafNonVerbalAccessibleCommsApp/2.0 (accessibility-app@example.com)'
        }
        params = {
            'lat': lat_f,
            'lon': lon_f,
            'format': 'json',
            'extratags': 1,
            'addressdetails': 1
        }
        response = requests.get(OSM_NOMINATIM_URL, params=params, headers=headers, timeout=4)
        if response.status_code == 200:
            data = response.json()
            category_slug = map_osm_data_to_slug(data)
            display_name = data.get('display_name', 'Current Area')
            address = data.get('address', {})

            suburb = (
                address.get('suburb')
                or address.get('neighbourhood')
                or address.get('residential')
                or address.get('village')
                or address.get('town')
                or address.get('city_district')
                or address.get('road')
            )
            city = address.get('city') or address.get('town') or address.get('county') or address.get('state')
            area_name = f"{suburb}, {city}" if (suburb and city and suburb != city) else (suburb or city or display_name.split(',')[0])

            poi_name = (
                data.get('name')
                or address.get('hospital')
                or address.get('supermarket')
                or address.get('restaurant')
                or address.get('bank')
                or address.get('pharmacy')
                or address.get('amenity')
                or address.get('shop')
                or area_name
            )

            # If category mapped to one of the predefined types
            if category_slug != 'other':
                res = {
                    'success': True,
                    'detected_slug': category_slug,
                    'poi_name': poi_name,
                    'address': display_name
                }
                return _attach_preset(res, category_slug, lat_f, lon_f)
            else:
                res = {
                    'success': True,
                    'detected_slug': 'other',
                    'poi_name': poi_name or area_name or 'General Area',
                    'address': display_name,
                    'area_name': area_name or 'General Area'
                }
                return _attach_preset(res, 'other', lat_f, lon_f)
    except Exception as e:
        print(f"Geo lookup error: {e}")

    res = {
        'success': True,
        'detected_slug': 'other',
        'poi_name': f"Coordinates ({round(lat_f, 4)}, {round(lon_f, 4)})",
        'address': f"Latitude: {lat_f}, Longitude: {lon_f}",
        'area_name': f"GPS Area ({round(lat_f, 4)}, {round(lon_f, 4)})"
    }
    return _attach_preset(res, 'other', lat_f, lon_f)

def map_osm_data_to_slug(osm_data):
    """
    Maps OpenStreetMap tags and reverse geocoding data to predefined location slugs:
    - hospital: Hospitals, clinics, doctors, emergency rooms
    - supermarket: Supermarkets, grocery stores, hypermarkets, convenience stores
    - restaurant: Restaurants, cafes, bistros, eateries, fast food, dining
    - bank: Banks, credit unions, ATMs, financial branches
    - pharmacy: Pharmacies, chemists, drugstores
    """
    address = osm_data.get('address', {})
    category = (osm_data.get('category') or osm_data.get('class') or '').lower()
    type_tag = (osm_data.get('type') or '').lower()
    name = (osm_data.get('name') or '').lower()
    display_name = (osm_data.get('display_name') or '').lower()

    amenity = address.get('amenity', '').lower()
    shop = address.get('shop', '').lower()
    healthcare = address.get('healthcare', '').lower()

    # 1. Hospital & Medical
    if (amenity in ['hospital', 'clinic', 'doctors', 'nursing_home', 'emergency']
        or healthcare in ['hospital', 'clinic', 'doctor']
        or type_tag in ['hospital', 'clinic', 'doctors']
        or category in ['healthcare', 'health']
        or any(w in name or w in display_name for w in ['hospital', 'clinic', 'medical center', 'health centre', 'infirmary'])):
        return 'hospital'

    # 2. Supermarkets & Groceries
    elif (shop in ['supermarket', 'grocery', 'convenience', 'department_store', 'greengrocer', 'deli', 'general']
          or type_tag in ['supermarket', 'grocery', 'convenience']
          or category in ['shop', 'retail']
          or any(w in name or w in display_name for w in ['supermarket', 'grocery', 'market', 'walmart', 'target', 'whole foods', 'costco', 'trader joe', 'tesco', 'carrefour', 'aldi', 'lidl', 'kroger'])):
        return 'supermarket'

    # 3. Restaurant & Dining
    elif (amenity in ['restaurant', 'fast_food', 'cafe', 'food_court', 'bar', 'pub', 'bistro', 'diner']
          or category in ['eating', 'food']
          or type_tag in ['restaurant', 'fast_food', 'cafe', 'food_court', 'diner']
          or any(w in name or w in display_name for w in ['restaurant', 'cafe', 'coffee', 'bistro', 'pizzeria', 'diner', 'bakery', 'grill', 'eatery', 'mc donald', 'starbucks', 'subway', 'pizza'])):
        return 'restaurant'

    # 4. Bank & Finance
    elif (amenity in ['bank', 'atm', 'bureau_de_change']
          or type_tag in ['bank', 'atm']
          or category in ['finance', 'bank']
          or any(w in name or w in display_name for w in ['bank', 'credit union', 'atm', 'savings', 'chase', 'wells fargo', 'barclays', 'hsbc', 'citibank', 'bank of america'])):
        return 'bank'

    # 5. Pharmacy
    elif (amenity == 'pharmacy' or shop in ['chemist', 'pharmacy'] or healthcare == 'pharmacy' or type_tag == 'pharmacy'
          or any(w in name or w in display_name for w in ['pharmacy', 'chemist', 'drugstore', 'walgreens', 'cvs', 'boots'])):
        return 'pharmacy'

    return 'other'
