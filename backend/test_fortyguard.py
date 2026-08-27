import os
import json
import requests
from dotenv import load_dotenv
load_dotenv()


API_KEY = os.getenv("FORTYGUARD_API_KEY")

if not API_KEY:
    raise RuntimeError(
        "FORTYGUARD_API_KEY is not set. "
        "Set your FortyGuard API key as an environment variable first."
    )


url = "https://api.fortyguard.com/v1/heatmap"

headers = {
    "api-key": API_KEY,
    "Content-Type": "application/json",
}

payload = {
    "polygon_aoi": {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {},
                "geometry": {
                    "type": "Polygon",
                    "coordinates": [[
                        [55.2708, 25.2048],
                        [55.2808, 25.2048],
                        [55.2808, 25.2148],
                        [55.2708, 25.2148],
                        [55.2708, 25.2048]
                    ]]
                }
            }
        ]
    },

    "date_time": {
        "start_date": "2026-08-15",
        "start_time": "14:00",
        "filter_type": 1
    },

    "granularity": 100,

    "analytic_type": "tcm"
}


print("Sending request to FortyGuard...")

response = requests.post(
    url,
    headers=headers,
    json=payload,
    timeout=60
)

print("\nHTTP STATUS:")
print(response.status_code)

print("\nRESPONSE:")

try:
    data = response.json()
    print(json.dumps(data, indent=2))
except Exception:
    print(response.text)