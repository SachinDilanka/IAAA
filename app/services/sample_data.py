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
    },
    {
        "id": 4,
        "name": "Bank",
        "slug": "bank",
        "icon": "fa-building-columns",
        "description": "Account inquiries, cash deposits, withdrawals, and ATM directions."
    },
    {
        "id": 5,
        "name": "Pharmacy",
        "slug": "pharmacy",
        "icon": "fa-prescription-bottle-medical",
        "description": "Prescriptions, over-the-counter medicine, and health supplies."
    }
]

def get_sample_locations():
    return SAMPLE_LOCATIONS
