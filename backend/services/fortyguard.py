import os
from dotenv import load_dotenv

from ..fortyguard.client import FortyGuardClient

load_dotenv()


def fortyguard_available() -> bool:
    """Check whether a FortyGuard API key is configured."""
    return bool(os.getenv("FORTYGUARD_API_KEY"))


def get_client():
    """Create the official FortyGuard client."""
    if not fortyguard_available():
        return None

    return FortyGuardClient(
        api_key=os.getenv("FORTYGUARD_API_KEY"),
        base_url=os.getenv(
            "FORTYGUARD_BASE_URL",
            "https://api.fortyguard.com",
        ),
    )


def get_environmental_data(
    latitude: float,
    longitude: float,
    temperature: float,
    date: str,
    start_time: str | None = None,
    end_time: str | None = None,
):
    """
    Get FortyGuard environmental parameters.

    Until the API key is available, returns demo mode.
    """

    client = get_client()

    # ---------------------------------------------------------
    # DEMO / FALLBACK MODE
    # ---------------------------------------------------------
    if client is None:
        return {
            "status": "demo",
            "source": "demo",
            "temperature": temperature,
            "latitude": latitude,
            "longitude": longitude,
        }

    # ---------------------------------------------------------
    # LIVE FORTYGUARD MODE
    # ---------------------------------------------------------
    try:
        result = client.environmental_parameters(
            latitude=latitude,
            longitude=longitude,
            temperature=temperature,
            start_date=date,
            filter_type=1,
            start_time=start_time,
            end_time=end_time,
            analysis=[
                "heat_index_celsius",
                "apparent_temperature_celsius",
                "wet_bulb_temperature_celsius",
                "relative_humidity_percent",
                "solar_irradiance",
            ],
            wait=True,
            verbose=False,
        )

        return {
            "status": "success",
            "source": "FortyGuard",
            "temperature": temperature,
            "latitude": latitude,
            "longitude": longitude,
            "data": result,
        }

    except Exception as exc:
        return {
            "status": "error",
            "source": "FortyGuard",
            "message": str(exc),
        }