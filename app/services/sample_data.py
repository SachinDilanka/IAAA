# Sample temporary data for initial interface development (No database connected yet)

SAMPLE_LOCATIONS = [
    {
        "id": 1,
        "name": "Hospital",
        "slug": "hospital",
        "icon": "fa-hospital",
        "description": "Medical emergency, doctor visits, appointments, and hospital directions."
    },
    {
        "id": 2,
        "name": "Restaurant",
        "slug": "restaurant",
        "icon": "fa-utensils",
        "description": "Ordering meals, specifying food allergies, and requesting the bill."
    },
    {
        "id": 3,
        "name": "Supermarket",
        "slug": "supermarket",
        "icon": "fa-cart-shopping",
        "description": "Finding products, grocery sections, assistance, and checkout."
    }
]

def get_sample_locations():
    return SAMPLE_LOCATIONS
