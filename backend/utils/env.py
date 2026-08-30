import os
from pathlib import Path

from dotenv import load_dotenv

BASE_DIR = Path(__file__).resolve().parents[1]
load_dotenv(BASE_DIR / ".env")

FORTYGUARD_API_KEY = os.getenv("FORTYGUARD_API_KEY")
FORTYGUARD_BASE_URL = os.getenv(
    "FORTYGUARD_BASE_URL",
    "https://api.fortyguard.com",
)

if not FORTYGUARD_API_KEY:
    raise RuntimeError(
        "FORTYGUARD_API_KEY is not set in the .env file."
    )