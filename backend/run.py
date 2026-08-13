"""
Backend entry point.
Run from research/ with:  python backend/run.py
"""
import sys
import os

# Ensure Python can find the backend/app package
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

from app import create_app

app = create_app()

if __name__ == '__main__':
    print("Starting AssistComm on http://127.0.0.1:5000 ...")
    app.run(host='127.0.0.1', port=5000, debug=True)
