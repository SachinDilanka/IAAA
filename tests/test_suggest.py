import unittest
from unittest.mock import patch, MagicMock
import requests
from app import create_app

class TestSuggestApi(unittest.TestCase):
    def setUp(self):
        self.app = create_app({'TESTING': True})
        self.client = self.app.test_client()

    @patch('app.routes.api.requests.post')
    def test_suggest_success(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 200
        mock_resp.json.return_value = {
            'pinned': [
                {'english': 'I am deaf.', 'sinhala': 'මම බිහිරි කෙනෙක්.'},
                {'english': 'I cannot speak.', 'sinhala': 'මට කතා කරන්න බැහැ.'}
            ],
            'results': [
                {'english': 'Where is the rice?', 'sinhala': 'සහල් කොහෙද?', 'score': 0.95}
            ],
            'low_confidence': False
        }
        mock_post.return_value = mock_resp

        res = self.client.post('/api/suggest', json={
            'category': 'supermarket',
            'query': 'rice',
            'top_k': 5
        })

        self.assertEqual(res.status_code, 200)
        data = res.get_json()
        self.assertIn('pinned', data)
        self.assertEqual(len(data['pinned']), 2)
        self.assertIn('results', data)
        self.assertEqual(data['results'][0]['english'], 'Where is the rice?')
        self.assertFalse(data['low_confidence'])

        # Verify requests.post was called with expected url and payload
        mock_post.assert_called_once()
        args, kwargs = mock_post.call_args
        self.assertEqual(args[0], 'http://127.0.0.1:8000/suggest')
        self.assertEqual(kwargs['json'], {
            'category': 'supermarket',
            'query': 'rice',
            'top_k': 5
        })
        self.assertEqual(kwargs['timeout'], 5.0)

    @patch('app.routes.api.requests.post')
    def test_suggest_timeout(self, mock_post):
        mock_post.side_effect = requests.exceptions.Timeout('Connection timed out')

        res = self.client.post('/api/suggest', json={
            'category': 'hospital',
            'query': 'fever'
        })

        self.assertEqual(res.status_code, 503)
        data = res.get_json()
        self.assertIn('error', data)
        self.assertIn('unavailable', data['error'].lower())

    @patch('app.routes.api.requests.post')
    def test_suggest_connection_error(self, mock_post):
        mock_post.side_effect = requests.exceptions.ConnectionError('Failed to establish a new connection')

        res = self.client.post('/api/suggest', json={
            'category': 'bank',
            'query': 'deposit'
        })

        self.assertEqual(res.status_code, 503)
        data = res.get_json()
        self.assertIn('error', data)
        self.assertIn('unavailable', data['error'].lower())

    @patch('app.routes.api.requests.post')
    def test_suggest_service_error_status(self, mock_post):
        mock_resp = MagicMock()
        mock_resp.status_code = 500
        mock_post.return_value = mock_resp

        res = self.client.post('/api/suggest', json={
            'category': 'restaurant',
            'query': 'water'
        })

        self.assertEqual(res.status_code, 503)
        data = res.get_json()
        self.assertIn('error', data)


if __name__ == '__main__':
    unittest.main()
