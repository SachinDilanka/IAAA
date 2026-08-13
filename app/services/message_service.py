from app.models.location import LocationType
from app.models.category import Category
from app.models.message import Message

def get_all_locations():
    return LocationType.query.order_by(LocationType.display_order).all()

def get_location_by_slug(slug):
    return LocationType.query.filter_by(slug=slug).first()

def get_location_messages(location_slug, search_query=None):
    location = LocationType.query.filter_by(slug=location_slug).first()
    if not location:
        return None
    
    categories = Category.query.filter_by(location_type_id=location.id).order_by(Category.display_order).all()
    
    result = []
    for cat in categories:
        messages_query = Message.query.filter_by(category_id=cat.id)
        if search_query:
            messages_query = messages_query.filter(Message.template.ilike(f'%{search_query}%'))
        messages = messages_query.order_by(Message.priority.desc()).all()
        
        if messages:
            result.append({
                'category': cat,
                'messages': messages
            })
            
    return {
        'location': location,
        'categories_with_messages': result
    }
