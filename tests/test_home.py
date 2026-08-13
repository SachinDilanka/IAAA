import unittest
from app import create_app

class TestHomePage(unittest.TestCase):
    def setUp(self):
        self.app = create_app({'TESTING': True})
        self.client = self.app.test_client()

    def test_home_page_status_and_content(self):
        response = self.client.get('/')
        self.assertEqual(response.status_code, 200)
        
        # Check Application Name / Title
        self.assertIn(b'AssistComm', response.data)
        
        # Check explanation
        self.assertIn(b'Accessible Communication Assistant', response.data)
        
        # Check Detect My Location button
        self.assertIn(b'Detect My Location', response.data)
        
        # Check Select Location Manually section
        self.assertIn(b'Select Location Manually', response.data)
        
        # Check required location cards: Hospital, Restaurant, Supermarket
        self.assertIn(b'Hospital', response.data)
        self.assertIn(b'Restaurant', response.data)
        self.assertIn(b'Supermarket', response.data)

if __name__ == '__main__':
    unittest.main()
