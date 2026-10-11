import unittest
from app import create_app

class TestMobileInterface(unittest.TestCase):
    def setUp(self):
        self.app = create_app({'TESTING': True})
        self.client = self.app.test_client()

    def test_mobile_wireframe_interface_hospital(self):
        # 1. Test auto-detect /mobile page starts in scanning state
        response_root = self.client.get('/mobile')
        self.assertEqual(response_root.status_code, 200)
        self.assertIn(b'AI Communication Assistant', response_root.data)
        self.assertIn(b'waiting-hospital-state', response_root.data)
        self.assertIn(b'btn-quick-sim-nhsl', response_root.data)
        self.assertIn(b'area-map-card', response_root.data)

        # 2. Test direct hospital route /mobile/hospital renders category button & all 11 dual-language messages
        response = self.client.get('/mobile/hospital')
        self.assertEqual(response.status_code, 200)

        # Wireframe Header & Title
        self.assertIn(b'AI Communication Assistant', response.data)

        # Location Banner & GPS Detection
        self.assertIn(b'CURRENT LOCATION', response.data)
        self.assertIn(b'Hospital', response.data)

        # Category Button
        self.assertIn("1. මූලික සන්නිවේදනය / Basic communication".encode('utf-8'), response.data)

        # All 11 Dual-Language Messages in both English and Sinhala
        self.assertIn(b'I am deaf.', response.data)
        self.assertIn("මම බිහිරි කෙනෙක්.".encode('utf-8'), response.data)

        self.assertIn(b'I cannot speak.', response.data)
        self.assertIn("මට කතා කරන්න බැහැ.".encode('utf-8'), response.data)

        self.assertIn(b'Please write down your message.', response.data)
        self.assertIn("කරුණාකර ඔබේ පණිවිඩය ලියන්න.".encode('utf-8'), response.data)

        self.assertIn(b'Please speak slowly and face me.', response.data)
        self.assertIn("කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.".encode('utf-8'), response.data)

        self.assertIn(b'Please wait a moment.', response.data)
        self.assertIn("කරුණාකර මොහොතක් \xe0\xb7\x80\xe0\xb7\x90\xe0\xb6\xb3\xe0\xb7\x93".decode('unicode_escape').encode('utf-8') if False else "කරුණාකර මොහොතක් රැඳී සිටින්න.".encode('utf-8'), response.data)

        self.assertIn(b'Thank you.', response.data)
        self.assertIn("ස්තූතියි.".encode('utf-8'), response.data)

        self.assertIn(b'Yes.', response.data)
        self.assertIn("ඔව්.".encode('utf-8'), response.data)

        self.assertIn(b'No.', response.data)
        self.assertIn("නැහැ.".encode('utf-8'), response.data)

        self.assertIn(b'I do not understand.', response.data)
        self.assertIn("මට තේරෙන්නේ නැහැ.".encode('utf-8'), response.data)

        self.assertIn(b'Please repeat that.', response.data)
        self.assertIn("කරුණාකර නැවත කියන්න.".encode('utf-8'), response.data)

        # Custom Typing Card
        self.assertIn(b'Custom Typing', response.data)
        self.assertIn(b'Type your own message', response.data)

        # Bottom Navigation Items
        self.assertIn(b'Home', response.data)
        self.assertIn(b'Categories', response.data)
        self.assertIn(b'History', response.data)
        self.assertIn(b'Favorites', response.data)

    def test_mobile_bank(self):
        resp = self.client.get('/mobile/bank')
        self.assertEqual(resp.status_code, 200)
        self.assertIn(b'Bank', resp.data)

    def test_mobile_supermarket(self):
        resp = self.client.get('/mobile/supermarket')
        self.assertEqual(resp.status_code, 200)
        self.assertIn(b'Supermarket', resp.data)

    def test_mobile_restaurant(self):
        resp = self.client.get('/mobile/restaurant')
        self.assertEqual(resp.status_code, 200)
        self.assertIn(b'Restaurant', resp.data)

    def test_gps_detection_api_predefined_places(self):
        # 1. Hospital Coordinates -> Delivers 11 Dual-Language Hospital Messages under Basic Communication
        res_hosp = self.client.post('/api/detect-location', json={'lat': 40.739, 'lon': -73.975})
        self.assertEqual(res_hosp.status_code, 200)
        data_hosp = res_hosp.get_json()
        self.assertTrue(data_hosp['success'])
        self.assertEqual(data_hosp['detected_slug'], 'hospital')
        self.assertTrue(data_hosp['is_hospital'])
        self.assertEqual(data_hosp['category_name'], '1. මූලික සන්නිවේදනය / Basic communication')
        self.assertIn('messages', data_hosp)
        self.assertEqual(len(data_hosp['messages']), 10)
        self.assertEqual(data_hosp['messages'][0]['template_en'], 'I am deaf.')
        self.assertEqual(data_hosp['messages'][0]['template_si'], 'මම බිහිරි කෙනෙක්.')
        self.assertEqual(data_hosp['messages'][9]['template_en'], 'Please repeat that.')
        self.assertEqual(data_hosp['messages'][9]['template_si'], 'කරුණාකර නැවත කියන්න.')
        self.assertIn('hospital_categories', data_hosp)
        self.assertEqual(len(data_hosp['hospital_categories']['directions']), 10)
        self.assertEqual(len(data_hosp['hospital_categories']['symptoms']), 19)

        # 2. Non-hospital locations -> Previously suggested messages removed (0 messages suggested until hospital)
        res_sup = self.client.post('/api/detect-location', json={'lat': 51.515, 'lon': -0.141})
        self.assertEqual(res_sup.status_code, 200)
        data_sup = res_sup.get_json()
        self.assertTrue(data_sup['success'])
        self.assertEqual(data_sup['detected_slug'], 'supermarket')
        self.assertEqual(len(data_sup['messages']), 0)
        self.assertFalse(data_sup['is_hospital'])

        # 3. Restaurant Coordinates
        res_rest = self.client.post('/api/detect-location', json={'lat': 48.858, 'lon': 2.294})
        self.assertEqual(res_rest.status_code, 200)
        data_rest = res_rest.get_json()
        self.assertTrue(data_rest['success'])
        self.assertEqual(data_rest['detected_slug'], 'restaurant')
        self.assertEqual(len(data_rest['messages']), 0)

        # 4. Bank Coordinates
        res_bank = self.client.post('/api/detect-location', json={'lat': 51.513, 'lon': -0.088})
        self.assertEqual(res_bank.status_code, 200)
        data_bank = res_bank.get_json()
        self.assertTrue(data_bank['success'])
        self.assertEqual(data_bank['detected_slug'], 'bank')
        self.assertEqual(len(data_bank['messages']), 0)

    def test_location_presets_api(self):
        res = self.client.get('/api/location-presets')
        self.assertEqual(res.status_code, 200)
        presets = res.get_json()
        self.assertIn('hospital', presets)
        self.assertIn('supermarket', presets)
        self.assertIn('restaurant', presets)
        self.assertIn('bank', presets)
        self.assertIn('pharmacy', presets)

    def test_single_interface_gps_elements(self):
        # Ensure single mobile interface contains GPS live strip, map hospital selector strip, and instruction badge
        resp = self.client.get('/mobile')
        self.assertEqual(resp.status_code, 200)
        self.assertIn(b'gps-live-strip', resp.data)
        self.assertIn(b'gps-dialog-backdrop', resp.data)
        self.assertIn(b'GPS Auto-Detecting', resp.data)
        self.assertIn(b'map-hospital-selector-strip', resp.data)
        self.assertIn(b'map-hospital-pills-row', resp.data)
        self.assertIn(b'map-tap-instruction-badge', resp.data)
        self.assertIn(b'modal-manual-hospital-select', resp.data)

    def test_manual_hospital_selection_api(self):
        # 1. Manually select NHSL Colombo by hospital_id
        res = self.client.post('/api/select-hospital', json={'hospital_id': 'nhsl-colombo'})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertTrue(data['is_hospital'])
        self.assertTrue(data['manually_selected'])
        self.assertIn('National Hospital', data['poi_name'])
        self.assertEqual(data['category_name'], '1. මූලික සන්නිවේදනය / Basic communication')
        self.assertEqual(len(data['messages']), 10)
        self.assertEqual(data['messages'][0]['template_en'], 'I am deaf.')
        self.assertEqual(data['messages'][0]['template_si'], 'මම බිහිරි කෙනෙක්.')
        self.assertEqual(data['messages'][9]['template_en'], 'Please repeat that.')
        self.assertEqual(data['messages'][9]['template_si'], 'කරුණාකර නැවත කියන්න.')

        # 2. Manually select Kandy Teaching Hospital
        res_kandy = self.client.post('/api/select-hospital', json={'hospital_id': 'kandy-teaching'})
        self.assertEqual(res_kandy.status_code, 200)
        data_kandy = res_kandy.get_json()
        self.assertTrue(data_kandy['success'])
        self.assertTrue(data_kandy['is_hospital'])
        self.assertIn('Kandy', data_kandy['poi_name'])
        self.assertEqual(len(data_kandy['messages']), 10)

    def test_area_map_elements_present_on_mobile(self):
        # Verify Area Map widget, leaflet canvas, controls, and scripts are present in mobile view
        resp = self.client.get('/mobile')
        self.assertEqual(resp.status_code, 200)
        self.assertIn(b'area-map-card', resp.data)
        self.assertIn(b'leaflet-area-map', resp.data)
        self.assertIn(b'map-recenter-btn', resp.data)
        self.assertIn(b'map-status-bar', resp.data)
        self.assertIn(b'leaflet.js', resp.data)
        self.assertIn(b'leaflet.css', resp.data)

    def test_outside_predefined_places_detection(self):
        # Verify coordinates outside hospital return is_hospital: False and 0 messages until hospital is detected
        res_outside = self.client.post('/api/detect-location', json={'lat': 6.8400, 'lon': 79.9200})
        self.assertEqual(res_outside.status_code, 200)
        data = res_outside.get_json()
        self.assertTrue(data['success'])
        self.assertFalse(data['is_predefined'])
        self.assertEqual(data['detected_slug'], 'other')
        self.assertFalse(data['is_hospital'])
        # Messages removed when outside hospital
        self.assertEqual(len(data['messages']), 0)
        # Must provide predefined coordinates and SL hospitals for map plotting
        self.assertIn('predefined_coordinates', data)
        self.assertIn('sri_lanka_hospitals', data)
        self.assertEqual(len(data['sri_lanka_hospitals']), 20)

    def test_sri_lanka_hospitals_api(self):
        # Verify /api/sri-lanka-hospitals returns all 20 hospitals and calculates distances
        res = self.client.get('/api/sri-lanka-hospitals?lat=6.9271&lon=79.8612')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['count'], 20)
        hospitals = data['hospitals']
        hosp_names = [h['short_name'] for h in hospitals]
        self.assertIn('NHSL Colombo', hosp_names)
        self.assertIn('Asiri Central', hosp_names)
        self.assertIn('Kalubowila Hospital', hosp_names)
        self.assertIn('Kandy National Hospital', hosp_names)
        # Check distance was computed
        self.assertIn('distance_km', hospitals[0])

    def test_sri_lanka_hospital_proximity_detection(self):
        # When user GPS is near NHSL Colombo (6.9197, 79.8693)
        res = self.client.post('/api/detect-location', json={'lat': 6.9197, 'lon': 79.8693})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['detected_slug'], 'hospital')
        self.assertTrue(data['is_hospital'])
        self.assertTrue(data['is_predefined'])
        self.assertIn('National Hospital', data['poi_name'])
        self.assertEqual(len(data['messages']), 10)

    def test_sri_lanka_banks_api(self):
        # Verify /api/sri-lanka-banks returns all 25 banks and calculates distances
        res = self.client.get('/api/sri-lanka-banks?lat=6.9348&lon=79.8436')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['count'], 25)
        banks = data['banks']
        bank_names = [b['short_name'] for b in banks]
        self.assertIn('BOC Head Office', bank_names)
        self.assertIn('Commercial Bank HQ', bank_names)
        self.assertIn("People's Bank HQ", bank_names)
        self.assertIn('HNB Towers Colombo', bank_names)
        self.assertIn('Sampath Bank HQ', bank_names)
        # Check distance was computed
        self.assertIn('distance_km', banks[0])
        self.assertEqual(banks[0]['short_name'], 'BOC Head Office')

    def test_sri_lanka_bank_proximity_detection(self):
        # When user GPS is near BOC Head Office (6.9348, 79.8436)
        res = self.client.post('/api/detect-location', json={'lat': 6.9348, 'lon': 79.8436})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['detected_slug'], 'bank')
        self.assertTrue(data['is_bank'])
        self.assertTrue(data['is_predefined'])
        self.assertIn('Bank of Ceylon', data['poi_name'])

    def test_manual_bank_selection_api(self):
        # Select Commercial Bank Head Office
        res = self.client.post('/api/select-bank', json={'bank_id': 'combank-head-office'})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['detected_slug'], 'bank')
        self.assertTrue(data['is_bank'])
        self.assertTrue(data['manually_selected'])
        self.assertIn('Commercial Bank', data['poi_name'])
        # Verify bank categories and messages attached
        self.assertIn('bank_categories', data)
        bank_cats = data['bank_categories']
        self.assertIn('bank-basic-comm', bank_cats)
        self.assertIn('bank-reception-queue', bank_cats)
        self.assertIn('bank-open-account', bank_cats)
        self.assertIn('bank-deposits-withdrawals', bank_cats)
        self.assertIn('bank-cards-atm', bank_cats)
        self.assertIn('bank-loans', bank_cats)
        self.assertIn('bank-transfers-payments', bank_cats)
        self.assertIn('bank-account-services', bank_cats)
        self.assertIn('bank-security-fraud', bank_cats)
        self.assertIn('bank-closing-courtesy', bank_cats)
        self.assertEqual(len(bank_cats['bank-basic-comm']), 7)
        self.assertEqual(len(bank_cats['bank-reception-queue']), 8)
        self.assertEqual(len(bank_cats['bank-open-account']), 12)
        self.assertEqual(len(bank_cats['bank-deposits-withdrawals']), 12)
        self.assertEqual(len(bank_cats['bank-cards-atm']), 12)
        self.assertEqual(len(bank_cats['bank-loans']), 12)
        self.assertEqual(len(bank_cats['bank-transfers-payments']), 10)
        self.assertEqual(len(bank_cats['bank-account-services']), 12)
        self.assertEqual(len(bank_cats['bank-security-fraud']), 6)
        self.assertEqual(len(bank_cats['bank-closing-courtesy']), 6)

    def test_bank_communication_messages_content(self):
        # Verify Bank Category 1: Basic communication (7 messages)
        res = self.client.post('/api/select-bank', json={'bank_id': 'boc-head-office'})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        basic_msgs = data['bank_categories']['bank-basic-comm']
        self.assertEqual(len(basic_msgs), 7)
        self.assertEqual(basic_msgs[0]['template_en'], 'I am deaf.')
        self.assertEqual(basic_msgs[0]['template_si'], 'මම බිහිරි කෙනෙක්.')
        self.assertEqual(basic_msgs[1]['template_en'], 'I cannot speak.')
        self.assertEqual(basic_msgs[1]['template_si'], 'මට කතා කරන්න බැහැ.')
        self.assertEqual(basic_msgs[2]['template_en'], 'Please write down your message.')
        self.assertEqual(basic_msgs[2]['template_si'], 'කරුණාකර ඔබේ පණිවිඩය ලියන්න.')
        self.assertEqual(basic_msgs[3]['template_en'], 'Please speak slowly and face me.')
        self.assertEqual(basic_msgs[3]['template_si'], 'කරුණාකර සෙමින් කතා කර මා දෙස බලන්න.')
        self.assertEqual(basic_msgs[4]['template_en'], 'Please wait a moment.')
        self.assertEqual(basic_msgs[4]['template_si'], 'කරුණාකර මොහොතක් රැඳී සිටින්න.')
        self.assertEqual(basic_msgs[5]['template_en'], 'Please repeat that.')
        self.assertEqual(basic_msgs[5]['template_si'], 'කරුණාකර නැවත කියන්න.')
        self.assertEqual(basic_msgs[6]['template_en'], 'I do not understand.')
        self.assertEqual(basic_msgs[6]['template_si'], 'මට තේරෙන්නේ නැහැ.')

        # Verify Bank Category 2: Reception and queue (8 messages)
        queue_msgs = data['bank_categories']['bank-reception-queue']
        self.assertEqual(len(queue_msgs), 8)
        self.assertEqual(queue_msgs[0]['template_en'], 'I need help.')
        self.assertEqual(queue_msgs[0]['template_si'], 'මට උදව්වක් අවශ්යයි.')
        self.assertEqual(queue_msgs[1]['template_en'], 'Where is the customer service desk?')
        self.assertEqual(queue_msgs[1]['template_si'], 'ගනුදෙනුකරු සේවා මේසය කොහෙද?')
        self.assertEqual(queue_msgs[2]['template_en'], 'Where do I get a queue token?')
        self.assertEqual(queue_msgs[2]['template_si'], 'පෝලිම් ටෝකන් අංකය ලබාගන්නේ කොහෙන්ද?')
        self.assertEqual(queue_msgs[3]['template_en'], 'Which counter should I go to?')
        self.assertEqual(queue_msgs[3]['template_si'], 'මම යා යුත්තේ කුමන කවුන්ටරයට ද?')
        self.assertEqual(queue_msgs[4]['template_en'], 'How long is the waiting time?')
        self.assertEqual(queue_msgs[4]['template_si'], 'බලා සිටිය යුතු කාලය කොපමණ ද?')
        self.assertEqual(queue_msgs[5]['template_en'], 'Please tap my shoulder when it is my turn.')
        self.assertEqual(queue_msgs[5]['template_si'], 'මගේ වාරය පැමිණි විට කරුණාකර මගේ උරහිසට තට්ටු කරන්න.')
        self.assertEqual(queue_msgs[6]['template_en'], 'Please let me know when my number is called.')
        self.assertEqual(queue_msgs[6]['template_si'], 'මගේ අංකය කැඳවන විට කරුණාකර මට දන්වන්න.')
        self.assertEqual(queue_msgs[7]['template_en'], 'May I speak to the manager?')
        self.assertEqual(queue_msgs[7]['template_si'], 'මට කළමනාකරු හමුවීමට පුළුවන් ද?')

        # Verify Bank Category 3: Opening an account (12 messages)
        open_msgs = data['bank_categories']['bank-open-account']
        self.assertEqual(len(open_msgs), 12)
        self.assertEqual(open_msgs[0]['template_en'], 'I want to open a new account.')
        self.assertEqual(open_msgs[0]['template_si'], 'මට නව ගිණුමක් විවෘත කිරීමට අවශ්යයි.')
        self.assertEqual(open_msgs[11]['template_en'], 'Can I have a copy of the form?')
        self.assertEqual(open_msgs[11]['template_si'], 'ෆෝරමයේ පිටපතක් ලබාගන්න පුළුවන් ද?')

        # Verify Bank Category 4: Deposits and withdrawals (12 messages)
        dep_msgs = data['bank_categories']['bank-deposits-withdrawals']
        self.assertEqual(len(dep_msgs), 12)
        self.assertEqual(dep_msgs[0]['template_en'], 'I want to deposit money.')
        self.assertEqual(dep_msgs[0]['template_si'], 'මට මුදල් තැන්පත් කිරීමට අවශ්යයි.')
        self.assertEqual(dep_msgs[11]['template_en'], 'Please update my passbook.')
        self.assertEqual(dep_msgs[11]['template_si'], 'කරුණාකර මගේ බැංකු පොත යාවත්කාලීන කරන්න.')

        # Verify Bank Category 5: Cards and ATM (12 messages)
        card_msgs = data['bank_categories']['bank-cards-atm']
        self.assertEqual(len(card_msgs), 12)
        self.assertEqual(card_msgs[0]['template_en'], 'I want to apply for a debit card.')
        self.assertEqual(card_msgs[0]['template_si'], 'මට ඩෙබිට් කාඩ්පතක් සඳහා අයදුම් කිරීමට අවශ්යයි.')
        self.assertEqual(card_msgs[11]['template_en'], 'I want to activate my card.')
        self.assertEqual(card_msgs[11]['template_si'], 'මට මගේ කාඩ්පත සක්රිය කිරීමට අවශ්යයි.')

        # Verify Bank Category 6: Loans (12 messages)
        loan_msgs = data['bank_categories']['bank-loans']
        self.assertEqual(len(loan_msgs), 12)
        self.assertEqual(loan_msgs[0]['template_en'], 'I want to apply for a loan.')
        self.assertEqual(loan_msgs[0]['template_si'], 'මට ණයක් සඳහා අයදුම් කිරීමට අවශ්යයි.')
        self.assertEqual(loan_msgs[11]['template_en'], 'Can I get a loan statement?')
        self.assertEqual(loan_msgs[11]['template_si'], 'මට ණය ප්රකාශයක් ලබාගත හැකිද?')

        # Verify Bank Category 7: Transfers and payments (10 messages)
        tf_msgs = data['bank_categories']['bank-transfers-payments']
        self.assertEqual(len(tf_msgs), 10)
        self.assertEqual(tf_msgs[0]['template_en'], 'I want to transfer money.')
        self.assertEqual(tf_msgs[0]['template_si'], 'මට මුදල් මාරු කිරීමට අවශ්යයි.')
        self.assertEqual(tf_msgs[9]['template_en'], 'I want to exchange foreign currency.')
        self.assertEqual(tf_msgs[9]['template_si'], 'මට විදේශ මුදල් මාරු කරගැනීමට අවශ්යයි.')

        # Verify Bank Category 8: Account services and problems (12 messages)
        acct_msgs = data['bank_categories']['bank-account-services']
        self.assertEqual(len(acct_msgs), 12)
        self.assertEqual(acct_msgs[0]['template_en'], 'I need a bank statement.')
        self.assertEqual(acct_msgs[0]['template_si'], 'මට ගිණුම් ප්රකාශයක් අවශ්යයි.')
        self.assertEqual(acct_msgs[11]['template_en'], 'I want to close my account.')
        self.assertEqual(acct_msgs[11]['template_si'], 'මට මගේ ගිණුම වසා දැමීමට අවශ්යයි.')

        # Verify Bank Category 9: Security and fraud (6 messages)
        sec_msgs = data['bank_categories']['bank-security-fraud']
        self.assertEqual(len(sec_msgs), 6)
        self.assertEqual(sec_msgs[0]['template_en'], 'I think someone has accessed my account without permission.')
        self.assertEqual(sec_msgs[0]['template_si'], 'මගේ ගිණුමට අවසරයකින් තොරව කවුරුහරි ඇතුළු වී ඇති බව මට හැඟෙනවා.')
        self.assertEqual(sec_msgs[5]['template_en'], 'Please do not share my details with anyone.')
        self.assertEqual(sec_msgs[5]['template_si'], 'කරුණාකර මගේ තොරතුරු කිසිවෙකු සමඟ බෙදා නොගන්න.')

        # Verify Bank Category 10: Closing and courtesy (6 messages)
        close_msgs = data['bank_categories']['bank-closing-courtesy']
        self.assertEqual(len(close_msgs), 6)
        self.assertEqual(close_msgs[0]['template_en'], 'Can you explain this in writing?')
        self.assertEqual(close_msgs[0]['template_si'], 'මෙය ලියා පැහැදිලි කරන්න පුළුවන් ද?')
        self.assertEqual(close_msgs[5]['template_en'], 'Thank you for your help.')
        self.assertEqual(close_msgs[5]['template_si'], 'ඔබේ උදව්වට ස්තූතියි.')

    def test_mobile_bank_ui_elements(self):
        # Verify /mobile/bank renders all 10 bank category buttons and badge
        resp = self.client.get('/mobile/bank')
        self.assertEqual(resp.status_code, 200)
        self.assertIn(b'id="bank-category-selector-bar"', resp.data)
        self.assertIn(b'id="btn-cat-bank-basic-comm"', resp.data)
        self.assertIn(b'id="btn-cat-bank-reception-queue"', resp.data)
        self.assertIn(b'id="btn-cat-bank-open-account"', resp.data)
        self.assertIn(b'id="btn-cat-bank-deposits-withdrawals"', resp.data)
        self.assertIn(b'id="btn-cat-bank-cards-atm"', resp.data)
        self.assertIn(b'id="btn-cat-bank-loans"', resp.data)
        self.assertIn(b'id="btn-cat-bank-transfers-payments"', resp.data)
        self.assertIn(b'id="btn-cat-bank-account-services"', resp.data)
        self.assertIn(b'id="btn-cat-bank-security-fraud"', resp.data)
        self.assertIn(b'id="btn-cat-bank-closing-courtesy"', resp.data)
        self.assertIn(b'Bank Message Criteria', resp.data)
        self.assertIn(b'10 Categories', resp.data)
        self.assertIn(b'id="modal-manual-bank-select"', resp.data)
        self.assertIn(b'gps-bank-sim-chip', resp.data)

    def test_sri_lanka_restaurants_api(self):
        # Verify /api/sri-lanka-restaurants returns all 25 restaurants and calculates distances
        res = self.client.get('/api/sri-lanka-restaurants?lat=6.9115&lon=79.8635')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['count'], 25)
        restaurants = data['restaurants']
        rest_names = [r['short_name'] for r in restaurants]
        self.assertIn("Upali's Colombo", rest_names)
        self.assertIn('Ministry of Crab', rest_names)
        self.assertIn('Kaema Sutra', rest_names)
        self.assertIn('The Lagoon', rest_names)
        self.assertIn('Shanmugas', rest_names)
        # Check distance was computed
        self.assertIn('distance_km', restaurants[0])
        self.assertEqual(restaurants[0]['short_name'], "Upali's Colombo")

    def test_sri_lanka_restaurant_proximity_detection(self):
        # When user GPS is near Upali's Colombo (6.9115, 79.8635)
        res = self.client.post('/api/detect-location', json={'lat': 6.9115, 'lon': 79.8635})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['detected_slug'], 'restaurant')
        self.assertTrue(data['is_restaurant'])
        self.assertTrue(data['is_predefined'])
        self.assertIn("Upali's", data['poi_name'])
        self.assertIn('restaurant_categories', data)
        self.assertEqual(len(data['restaurant_categories']), 9)

    def test_manual_restaurant_selection_api(self):
        # Select Ministry of Crab
        res = self.client.post('/api/select-restaurant', json={'restaurant_id': 'ministry-of-crab'})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['detected_slug'], 'restaurant')
        self.assertTrue(data['is_restaurant'])
        self.assertTrue(data['manually_selected'])
        self.assertIn('Ministry of Crab', data['poi_name'])
        # Verify all 9 restaurant categories and 100 messages attached
        self.assertIn('restaurant_categories', data)
        rest_cats = data['restaurant_categories']
        self.assertEqual(len(rest_cats), 9)
        self.assertIn('rest-basic-comm', rest_cats)
        self.assertIn('rest-seating', rest_cats)
        self.assertIn('rest-menu-ordering', rest_cats)
        self.assertIn('rest-drinks', rest_cats)
        self.assertIn('rest-dietary-allergies', rest_cats)
        self.assertIn('rest-customizing', rest_cats)
        self.assertIn('rest-during-meal', rest_cats)
        self.assertIn('rest-takeaway-requests', rest_cats)
        self.assertIn('rest-bill-payment', rest_cats)
        self.assertEqual(len(rest_cats['rest-basic-comm']), 10)
        self.assertEqual(len(rest_cats['rest-seating']), 12)
        self.assertEqual(len(rest_cats['rest-menu-ordering']), 18)
        self.assertEqual(len(rest_cats['rest-drinks']), 10)
        self.assertEqual(len(rest_cats['rest-dietary-allergies']), 14)
        self.assertEqual(len(rest_cats['rest-customizing']), 12)
        self.assertEqual(len(rest_cats['rest-during-meal']), 10)
        self.assertEqual(len(rest_cats['rest-takeaway-requests']), 6)
        self.assertEqual(len(rest_cats['rest-bill-payment']), 8)
        self.assertEqual(sum(len(msgs) for msgs in rest_cats.values()), 100)

    def test_restaurant_communication_messages_content(self):
        # Verify Restaurant Category messages in dual-language English & Sinhala (100 total)
        res = self.client.post('/api/select-restaurant', json={'restaurant_id': 'upalis-colombo'})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        cats = data['restaurant_categories']
        self.assertEqual(sum(len(msgs) for msgs in cats.values()), 100)

        # Category 1: Basic communication (1-10)
        basic_msgs = cats['rest-basic-comm']
        self.assertEqual(len(basic_msgs), 10)
        self.assertEqual(basic_msgs[0]['template_en'], 'I am deaf.')
        self.assertEqual(basic_msgs[0]['template_si'], 'මම බිහිරි කෙනෙක්.')
        self.assertEqual(basic_msgs[9]['template_en'], 'Thank you.')
        self.assertEqual(basic_msgs[9]['template_si'], 'ස්තූතියි.')

        # Category 2: Arrival and seating (11-22)
        seating_msgs = cats['rest-seating']
        self.assertEqual(len(seating_msgs), 12)
        self.assertEqual(seating_msgs[0]['template_en'], 'A table for one, please.')
        self.assertEqual(seating_msgs[0]['template_si'], 'කරුණාකර එක් අයෙකුට මේසයක් දෙන්න.')
        self.assertEqual(seating_msgs[11]['template_en'], 'Where is the toilet?')
        self.assertEqual(seating_msgs[11]['template_si'], 'වැසිකිළිය කොහෙද?')

        # Category 3: Menu and ordering (23-40)
        menu_msgs = cats['rest-menu-ordering']
        self.assertEqual(len(menu_msgs), 18)
        self.assertEqual(menu_msgs[0]['template_en'], 'May I see the menu, please?')
        self.assertEqual(menu_msgs[0]['template_si'], 'කරුණාකර මට මෙනුව බලන්න පුළුවන් ද?')
        self.assertEqual(menu_msgs[9]['template_en'], 'I would like kottu.')
        self.assertEqual(menu_msgs[9]['template_si'], 'මට කොත්තු අවශ්යයි.')

        # Category 4: Drinks (41-50)
        drink_msgs = cats['rest-drinks']
        self.assertEqual(len(drink_msgs), 10)
        self.assertEqual(drink_msgs[0]['template_en'], 'May I have some water, please?')
        self.assertEqual(drink_msgs[0]['template_si'], 'කරුණාකර මට වතුර ටිකක් දෙන්න.')
        self.assertEqual(drink_msgs[6]['template_en'], 'I would like a king coconut.')
        self.assertEqual(drink_msgs[6]['template_si'], 'මට තැඹිලි පොල් එකක් අවශ්යයි.')

        # Category 5: Dietary needs and allergies (51-64)
        diet_msgs = cats['rest-dietary-allergies']
        self.assertEqual(len(diet_msgs), 14)
        self.assertEqual(diet_msgs[0]['template_en'], 'I am vegetarian.')
        self.assertEqual(diet_msgs[0]['template_si'], 'මම නිර්මාංශිකයි.')
        self.assertEqual(diet_msgs[5]['template_en'], 'Is this halal?')
        self.assertEqual(diet_msgs[5]['template_si'], 'මෙය හලාල් ද?')

        # Category 6: Customizing the food (65-76)
        custom_msgs = cats['rest-customizing']
        self.assertEqual(len(custom_msgs), 12)
        self.assertEqual(custom_msgs[0]['template_en'], 'Not too spicy, please.')
        self.assertEqual(custom_msgs[0]['template_si'], 'කරුණාකර වැඩි ඇඹුල් හෝ සැර නැතිව.')
        self.assertEqual(custom_msgs[2]['template_en'], 'I like it spicy.')
        self.assertEqual(custom_msgs[2]['template_si'], 'මම සැර කෑම කැමතියි.')

        # Category 7: During the meal (77-86)
        meal_msgs = cats['rest-during-meal']
        self.assertEqual(len(meal_msgs), 10)
        self.assertEqual(meal_msgs[0]['template_en'], 'How long will my food take?')
        self.assertEqual(meal_msgs[0]['template_si'], 'මගේ කෑම ලැබෙන්න කොපමණ කාලයක් යයිද?')
        self.assertEqual(meal_msgs[7]['template_en'], 'The food is delicious.')
        self.assertEqual(meal_msgs[7]['template_si'], 'කෑම ඉතා රසයි.')

        # Category 8: Takeaway and special requests (87-92)
        takeaway_msgs = cats['rest-takeaway-requests']
        self.assertEqual(len(takeaway_msgs), 6)
        self.assertEqual(takeaway_msgs[0]['template_en'], 'May I have this packed to take away?')
        self.assertEqual(takeaway_msgs[0]['template_si'], 'මට මෙය රැගෙන යාමට ඇසුරුම් කරන්න පුළුවන් ද?')
        self.assertEqual(takeaway_msgs[3]['template_en'], 'Is there Wi-Fi?')
        self.assertEqual(takeaway_msgs[3]['template_si'], 'Wi-Fi තියෙනවා ද?')

        # Category 9: Bill and payment (93-100)
        bill_msgs = cats['rest-bill-payment']
        self.assertEqual(len(bill_msgs), 8)
        self.assertEqual(bill_msgs[0]['template_en'], 'May I have the bill, please?')
        self.assertEqual(bill_msgs[0]['template_si'], 'කරුණාකර මට බිල දෙන්න.')
        self.assertEqual(bill_msgs[7]['template_en'], 'Thank you, we enjoyed the meal.')
        self.assertEqual(bill_msgs[7]['template_si'], 'ස්තූතියි, අපි කෑම රස විඳිමු.')

    def test_mobile_restaurant_ui_elements(self):
        # Verify /mobile/restaurant renders all 9 restaurant category buttons and badge
        resp = self.client.get('/mobile/restaurant')
        self.assertEqual(resp.status_code, 200)
        self.assertIn(b'id="restaurant-category-selector-bar"', resp.data)
        self.assertIn(b'id="btn-cat-rest-basic-comm"', resp.data)
        self.assertIn(b'id="btn-cat-rest-seating"', resp.data)
        self.assertIn(b'id="btn-cat-rest-menu-ordering"', resp.data)
        self.assertIn(b'id="btn-cat-rest-drinks"', resp.data)
        self.assertIn(b'id="btn-cat-rest-dietary-allergies"', resp.data)
        self.assertIn(b'id="btn-cat-rest-customizing"', resp.data)
        self.assertIn(b'id="btn-cat-rest-during-meal"', resp.data)
        self.assertIn(b'id="btn-cat-rest-takeaway-requests"', resp.data)
        self.assertIn(b'id="btn-cat-rest-bill-payment"', resp.data)
        self.assertIn(b'Restaurant Message Criteria', resp.data)
        self.assertIn(b'9 Categories', resp.data)
        self.assertIn(b'id="modal-manual-restaurant-select"', resp.data)
        self.assertIn(b'gps-restaurant-sim-chip', resp.data)

    def test_sri_lanka_supermarkets_api(self):
        # Verify /api/sri-lanka-supermarkets returns all 25 outlets and calculates distances
        res = self.client.get('/api/sri-lanka-supermarkets?lat=6.9180&lon=79.8620')
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['count'], 25)
        supermarkets = data['supermarkets']
        sm_names = [s['short_name'] for s in supermarkets]
        self.assertIn('Cargills Staples St', sm_names)
        self.assertIn('Keells Crescat', sm_names)
        self.assertIn('Arpico Hyde Park', sm_names)
        self.assertIn('SPAR Thalawathugoda', sm_names)
        self.assertIn('GLOMARK Kynsey Rd', sm_names)
        self.assertIn('Laugfs Havelock', sm_names)
        # Check distance was computed
        self.assertIn('distance_km', supermarkets[0])

    def test_sri_lanka_supermarket_proximity_detection(self):
        # When user GPS is near Arpico Supercentre Hyde Park / Cargills Staples (6.9180, 79.8620)
        res = self.client.post('/api/detect-location', json={'lat': 6.9180, 'lon': 79.8620})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertEqual(data['detected_slug'], 'supermarket')
        self.assertTrue(data['is_supermarket'])
        self.assertTrue(data['is_predefined'])
        self.assertIn('Supercentre', data['poi_name'])
        self.assertEqual(len(data['messages']), 0)
        self.assertIn('supermarket_categories', data)
        self.assertEqual(len(data['supermarket_categories']), 4)

    def test_manual_supermarket_selection_api(self):
        # 1. Manually select Cargills Food City Staples by supermarket_id
        res = self.client.post('/api/select-supermarket', json={'supermarket_id': 'cargills-food-city-staples'})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertTrue(data['is_supermarket'])
        self.assertTrue(data['manually_selected'])
        self.assertIn('Cargills Food City', data['poi_name'])
        self.assertEqual(data['category_name'], '1. මූලික සන්නිවේදනය / Basic communication')
        self.assertIn('supermarket_categories', data)
        cats = data['supermarket_categories']
        self.assertEqual(len(cats['sm-basic-comm']), 6)
        self.assertEqual(cats['sm-basic-comm'][0]['template_en'], 'I am deaf / non-verbal.')
        self.assertEqual(cats['sm-basic-comm'][0]['template_si'], 'මම බිහිරි / කතා කිරීමට අපහසු අයෙක්.')

        # 2. Manually select Keells Crescat Colombo
        res_keells = self.client.post('/api/select-supermarket', json={'supermarket_id': 'keells-crescat-colombo'})
        self.assertEqual(res_keells.status_code, 200)
        data_keells = res_keells.get_json()
        self.assertTrue(data_keells['success'])
        self.assertTrue(data_keells['is_supermarket'])
        self.assertIn('Keells', data_keells['poi_name'])
        self.assertIn('supermarket_categories', data_keells)
        self.assertEqual(len(data_keells['supermarket_categories']['sm-basic-comm']), 6)

    def test_supermarket_all_4_categories_messages(self):
        res = self.client.post('/api/select-supermarket', json={'supermarket_id': 'arpico-supercentre-hyde-park'})
        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertTrue(data['success'])
        self.assertIn('supermarket_categories', data)
        cats = data['supermarket_categories']

        # Verify all 4 categories exist
        expected_cats = [
            'sm-basic-comm',
            'sm-finding-items',
            'sm-pricing-weights',
            'sm-checkout-payment'
        ]
        for c in expected_cats:
            self.assertIn(c, cats)

        # Category 1: Basic communication (6)
        basic_msgs = cats['sm-basic-comm']
        self.assertEqual(len(basic_msgs), 6)
        self.assertEqual(basic_msgs[0]['template_en'], 'I am deaf / non-verbal.')
        self.assertEqual(basic_msgs[0]['template_si'], 'මම බිහිරි / කතා කිරීමට අපහසු අයෙක්.')
        self.assertEqual(basic_msgs[5]['template_en'], 'Thank you for your assistance.')
        self.assertEqual(basic_msgs[5]['template_si'], 'ඔබගේ උදව්වට ස්තූතියි.')

        # Category 2: Finding items & aisles (9)
        finding_msgs = cats['sm-finding-items']
        self.assertEqual(len(finding_msgs), 9)
        self.assertEqual(finding_msgs[0]['template_en'], 'Where can I find milk and dairy products?')
        self.assertEqual(finding_msgs[0]['template_si'], 'කිරි සහ කිරි නිෂ්පාදන තිබෙන්නේ කොහේද?')
        self.assertEqual(finding_msgs[8]['template_en'], 'Can you check the back storeroom for more?')
        self.assertEqual(finding_msgs[8]['template_si'], 'තව තිබේදැයි පසුපස ගබඩාව පරීක්ෂා කළ හැකිද?')

        # Category 3: Pricing & weighing (6)
        pricing_msgs = cats['sm-pricing-weights']
        self.assertEqual(len(pricing_msgs), 6)
        self.assertEqual(pricing_msgs[0]['template_en'], 'How much does this item cost?')
        self.assertEqual(pricing_msgs[0]['template_si'], 'මේ භාණ්ඩයේ මිල කීයද?')
        self.assertEqual(pricing_msgs[5]['template_en'], 'Can I return or exchange this item?')
        self.assertEqual(pricing_msgs[5]['template_si'], 'මට මෙම භාණ්ඩය මාරු කිරීමට හෝ ආපසු දීමට හැකිද?')

        # Category 4: Checkout & payment (7)
        checkout_msgs = cats['sm-checkout-payment']
        self.assertEqual(len(checkout_msgs), 7)
        self.assertEqual(checkout_msgs[0]['template_en'], 'I would like to check out now.')
        self.assertEqual(checkout_msgs[0]['template_si'], 'මට දැන් මුදල් ගෙවීමට අවශ්‍යයි.')
        self.assertEqual(checkout_msgs[6]['template_en'], 'Can you help me pack the groceries?')
        self.assertEqual(checkout_msgs[6]['template_si'], 'බඩු බෑග්වලට අසුරා ගැනීමට උදව් කළ හැකිද?')

    def test_mobile_supermarket_ui_elements(self):
        # Verify /mobile/supermarket renders all 4 supermarket category buttons and badge
        resp = self.client.get('/mobile/supermarket')
        self.assertEqual(resp.status_code, 200)
        self.assertIn(b'id="supermarket-category-selector-bar"', resp.data)
        self.assertIn(b'id="btn-cat-sm-basic-comm"', resp.data)
        self.assertIn(b'id="btn-cat-sm-finding-items"', resp.data)
        self.assertIn(b'id="btn-cat-sm-pricing-weights"', resp.data)
        self.assertIn(b'id="btn-cat-sm-checkout-payment"', resp.data)
        self.assertIn(b'Supermarket Message Criteria', resp.data)
        self.assertIn(b'4 Categories', resp.data)
        self.assertIn(b'id="modal-manual-supermarket-select"', resp.data)
        self.assertIn(b'gps-supermarket-sim-chip', resp.data)
        self.assertIn(b'map-sl-supermarkets-quick-btn', resp.data)


if __name__ == '__main__':
    unittest.main()



