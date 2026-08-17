from datetime import datetime

from .fortyguard import get_environmental_data


def get_temperature_for_segment(
    latitude: float,
    longitude: float,
    fallback_temperature: float,
):
    """
    Return temperature information for one route segment.

    Today:
        Uses fallback demo temperature because the API key
        is not available.

    Tomorrow:
        Automatically attempts FortyGuard when the API key
        is configured.
    """

    today = datetime.now().strftime("%Y-%m-%d")

    result = get_environmental_data(
        latitude=latitude,
        longitude=longitude,
        temperature=fallback_temperature,
        date=today,
    )

    return result