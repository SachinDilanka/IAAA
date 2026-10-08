import unittest
import json
from app import create_app

class TestBasicCommunicationButton(unittest.TestCase):
    def setUp(self):
        self.app = create_app()
        self.app.config['TESTING'] = True
        self.client = self.app.test_client()

    def test_hospital_page_initial_view(self):
        """Verify that initially only the basic communication button is available and messages grid is hidden."""
        resp = self.client.get('/mobile/hospital')
        self.assertEqual(resp.status_code, 200)
        html = resp.data.decode('utf-8')
        
        # Verify all 9 category buttons exist
        self.assertIn('id="btn-cat-basic-comm"', html)
        self.assertIn('1. මූලික සන්නිවේදනය / Basic communication', html)
        self.assertIn('id="btn-cat-reception"', html)
        self.assertIn('2. පිළිගැනීම සහ ලියාපදිංචිය / Reception and registration', html)
        self.assertIn('id="btn-cat-directions"', html)
        self.assertIn('3. දිශාවන් / Directions', html)
        self.assertIn('id="btn-cat-symptoms"', html)
        self.assertIn('4. රෝග ලක්ෂණ / Symptoms', html)
        self.assertIn('id="btn-cat-emergency"', html)
        self.assertIn('5. හදිසි අවස්ථාව / Emergency', html)
        self.assertIn('id="btn-cat-medical-history"', html)
        self.assertIn('6. වෛද්ය ඉතිහාසය / Medical history', html)
        self.assertIn('id="btn-cat-doctor-consultation"', html)
        self.assertIn('7. වෛද්ය උපදේශනය / Doctor consultation', html)
        self.assertIn('id="btn-cat-procedures-comfort"', html)
        self.assertIn('8. ක්රියාපටිපාටි සහ පහසුව / Procedures and comfort', html)
        self.assertIn('id="btn-cat-pharmacy-billing"', html)
        self.assertIn('9. ඖෂධ ශාලාව, බිල්පත් කිරීම සහ බැහැර කිරීම / Pharmacy, billing and discharge', html)
        
        # Verify hint text is present
        self.assertIn('id="category-hint-text"', html)
        self.assertIn('Press a category button above to suggest communication messages', html)
        
        # Verify messages-grid has initial style display: none
        self.assertIn('id="messages-grid"', html)
        self.assertIn('style="display: none;"', html)
        
        # Verify messages do NOT have card-num-pill numbers 1-10
        self.assertNotIn('card-num-pill', html)

    def test_api_select_hospital_categories(self):
        """Verify selecting a hospital returns all 9 hospital categories."""
        resp = self.client.post('/api/select-hospital', 
                                data=json.dumps({'hospital_id': 'nhsl-colombo'}),
                                content_type='application/json')
        self.assertEqual(resp.status_code, 200)
        data = resp.get_json()
        self.assertTrue(data.get('success'))
        self.assertEqual(data.get('detected_slug'), 'hospital')
        self.assertEqual(len(data.get('messages', [])), 10)
        self.assertIn('hospital_categories', data)
        self.assertEqual(len(data['hospital_categories']['basic-comm']), 10)
        self.assertEqual(len(data['hospital_categories']['reception']), 10)
        self.assertEqual(len(data['hospital_categories']['directions']), 10)
        self.assertEqual(len(data['hospital_categories']['symptoms']), 19)
        self.assertEqual(len(data['hospital_categories']['emergency']), 8)
        self.assertEqual(len(data['hospital_categories']['medical-history']), 14)
        self.assertEqual(len(data['hospital_categories']['doctor-consultation']), 14)
        self.assertEqual(len(data['hospital_categories']['procedures-comfort']), 8)
        self.assertEqual(len(data['hospital_categories']['pharmacy-billing']), 6)

if __name__ == '__main__':
    unittest.main()
