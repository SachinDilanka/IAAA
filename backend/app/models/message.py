from app import db

class Message(db.Model):
    __tablename__ = 'messages'
    
    id = db.Column(db.Integer, primary_key=True)
    category_id = db.Column(db.Integer, db.ForeignKey('categories.id'), nullable=False)
    template = db.Column(db.Text, nullable=False)
    has_slot = db.Column(db.Boolean, default=False)
    slot_placeholder = db.Column(db.String(100), nullable=True)
    icon = db.Column(db.String(50), nullable=False, default='fa-comment')
    priority = db.Column(db.Integer, default=0)

    def to_dict(self):
        return {
            'id': self.id,
            'category_id': self.category_id,
            'template': self.template,
            'has_slot': self.has_slot,
            'slot_placeholder': self.slot_placeholder,
            'icon': self.icon,
            'priority': self.priority
        }
