from app import db

class LocationType(db.Model):
    __tablename__ = 'location_types'
    
    id = db.Column(db.Integer, primary_key=True)
    name = db.Column(db.String(100), nullable=False)
    slug = db.Column(db.String(100), unique=True, nullable=False)
    icon = db.Column(db.String(50), nullable=False, default='fa-location-dot')
    description = db.Column(db.String(255), nullable=True)
    osm_tags = db.Column(db.String(255), nullable=True)
    display_order = db.Column(db.Integer, default=0)
    
    categories = db.relationship('Category', backref='location_type', lazy=True, cascade='all, delete-orphan', order_by='Category.display_order')

    def to_dict(self):
        return {
            'id': self.id,
            'name': self.name,
            'slug': self.slug,
            'icon': self.icon,
            'description': self.description,
            'osm_tags': self.osm_tags,
            'categories_count': len(self.categories)
        }
