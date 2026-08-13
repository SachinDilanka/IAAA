import os
from flask import Flask
from flask_sqlalchemy import SQLAlchemy

db = SQLAlchemy()

def create_app(test_config=None):
    # backend/app/ → backend/ → research/
    backend_dir   = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    workspace_root = os.path.dirname(backend_dir)

    template_dir = os.path.join(workspace_root, 'frontend', 'templates')
    static_dir   = os.path.join(workspace_root, 'frontend', 'static')
    instance_dir = os.path.join(backend_dir, 'instance')

    app = Flask(
        __name__,
        template_folder=template_dir,
        static_folder=static_dir,
        instance_path=instance_dir,
        instance_relative_config=False,
    )

    os.makedirs(instance_dir, exist_ok=True)

    db_path = os.path.join(instance_dir, 'comms_app.db')
    app.config.from_mapping(
        SECRET_KEY=os.getenv('SECRET_KEY', 'dev-secret-accessible-comms'),
        SQLALCHEMY_DATABASE_URI=f'sqlite:///{db_path}',
        SQLALCHEMY_TRACK_MODIFICATIONS=False,
    )

    if test_config:
        app.config.update(test_config)

    db.init_app(app)

    with app.app_context():
        from app.models.location import LocationType  # noqa: F401
        from app.models.category import Category      # noqa: F401
        from app.models.message import Message        # noqa: F401

        from app.routes.views import views_bp
        from app.routes.api import api_bp

        app.register_blueprint(views_bp)
        app.register_blueprint(api_bp, url_prefix='/api')

        db.create_all()

    return app
