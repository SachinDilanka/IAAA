from app import db

class Category(db.Model):
    __tablename__ = 'categories'
    
    id = db.Column(db.Integer, primary_key=True)
    location_type_id = db.Column(db.Integer, db.ForeignKey('location_types.id'), nullable=False)
    name = db.Column(db.String(100), nullable=False)
    slug = db.Column(db.String(100), nullable=False)
    icon = db.Column(db.String(50), nullable=False, default='fa-folder')
    display_order = db.Column(db.Integer, default=0)
    
    messages = db.relationship('Message', backref='category', lazy=True, cascade='all, delete-orphan', order_by='Message.priority.desc()')

    def to_dict(self):
        return {
            'id': self.id,
            'location_type_id': self.location_type_id,
            'name': self.name,
            'slug': self.slug,
            'icon': self.icon,
            'display_order': self.display_order,
            'messages': [m.to_dict() for m in self.messages]
        }
