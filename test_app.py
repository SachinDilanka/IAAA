import unittest
from app import create_app, db
from app.models.location import LocationType
from app.models.category import Category
from app.models.message import Message

class AccessibleCommsTestCase(unittest.TestCase):
    def setUp(self):
        self.app = create_app({
            'TESTING': True,
            'SQLALCHEMY_DATABASE_URI': 'sqlite:///:memory:'
        })
        self.client = self.app.test_client()
        with self.app.app_context():
            db.create_all()
            self._seed_test_db()

    def _seed_test_db(self):
        loc = LocationType(name="Hospital", slug="hospital", icon="fa-hospital")
        db.session.add(loc)
        db.session.flush()

        cat = Category(location_type_id=loc.id, name="Emergency", slug="emergency", icon="fa-truck-medical")
        db.session.add(cat)
        db.session.flush()

        msg1 = Message(category_id=cat.id, template="I need emergency care.", icon="fa-triangle-exclamation")
        msg2 = Message(category_id=cat.id, template="I need this item: {slot}", has_slot=True, slot_placeholder="Milk")
        db.session.add_all([msg1, msg2])
        db.session.commit()

    def test_locations_api(self):
        response = self.client.get('/api/locations')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(len(data), 1)
        self.assertEqual(data[0]['slug'], 'hospital')

    def test_location_messages_api(self):
        response = self.client.get('/api/locations/hospital')
        self.assertEqual(response.status_code, 200)
        data = response.get_json()
        self.assertEqual(data['location']['name'], 'Hospital')
        self.assertEqual(len(data['categories']), 1)
        self.assertEqual(data['categories'][0]['messages'][0]['template'], 'I need emergency care.')

    def test_index_page(self):
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'AssistComm', response.data)
        self.assertIn(b'Hospital', response.data)

    def test_location_page(self):
        response = self.client.get('/location/hospital')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'Emergency', response.data)
        self.assertIn(b'I need emergency care.', response.data)

    def test_card_show_page(self):
        response = self.client.get('/show?text=I+need+help&icon=fa-hand')
        self.assertEqual(response.status_code, 200)
        self.assertIn(b'I need help', response.data)

if __name__ == '__main__':
    unittest.main()
