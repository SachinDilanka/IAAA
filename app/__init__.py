import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

def create_app(test_config=None):
    app = Flask(__name__, instance_relative_config=True)
    
    db_path = os.path.join(app.instance_path, 'comms_app.db')
    app.config.from_mapping(
        SECRET_KEY=os.getenv('SECRET_KEY', 'dev-secret-accessible-comms'),
        SQLALCHEMY_DATABASE_URI=f'sqlite:///{db_path}',
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
    )

    if test_config:
        app.config.update(test_config)

    os.makedirs(app.instance_path, exist_ok=True)
    db.init_app(app)

    with app.app_context():
        # Models
        from app.models.location import LocationType  # noqa: F401
        from app.models.category import Category      # noqa: F401
        from app.models.message import Message        # noqa: F401

        # Register Blueprints
        from app.routes.views import views_bp
        from app.routes.api import api_bp

        app.register_blueprint(views_bp)
        app.register_blueprint(api_bp, url_prefix='/api')

        db.create_all()

    return app

