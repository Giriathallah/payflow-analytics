import os

# Superset Configuration for PayFlow Analytics
ROW_LIMIT = 50000

# Security & CORS settings
ENABLE_CORS = True
CORS_OPTIONS = {
    "supports_credentials": True,
    "allow_headers": ["*"],
    "resources": ["*"],
    "origins": ["*"]
}

# Feature Flags
FEATURE_FLAGS = {
    "DASHBOARD_NATIVE_FILTERS": True,
    "DASHBOARD_CROSS_FILTERS": True,
    "ENABLE_TEMPLATE_PROCESSING": True,
    "GENERIC_CHART_AXES": True,
}

# Application branding
APP_NAME = "PayFlow Analytics"
APP_ICON = "/static/assets/images/superset-logo-horiz.png"

# Flask Secret Key
SECRET_KEY = os.environ.get("SUPERSET_SECRET_KEY", "payflow_superset_secret_key_2026_change_in_prod")
