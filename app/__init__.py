import os
from flask import Flask

def create_app(test_config=None):
    app = Flask(__name__, instance_relative_config=True)
    
    app.config.from_mapping(
        SECRET_KEY=os.getenv('SECRET_KEY', 'dev-secret-accessible-comms'),
    )

    if test_config:
        app.config.update(test_config)

    # Register Main Blueprint
    from app.routes.main import main_bp
    app.register_blueprint(main_bp)

    return app
