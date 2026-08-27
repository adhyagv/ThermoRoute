def clamp(value, minimum=0, maximum=100):
    return max(minimum, min(maximum, value))


def calculate_segment_exposure(
    temperature,
    duration_minutes,
    heat_index=None,
    apparent_temperature=None,
    wet_bulb_temperature=None,
):
    """
    Calculate thermal exposure for one journey segment.

    Priority:
    1. Heat Index
    2. Apparent Temperature
    3. Wet Bulb Temperature
    4. Raw Temperature

    This is an explainable exposure score,
    not a medical risk prediction.
    """

    effective_temperature = temperature

    if heat_index is not None:
        effective_temperature = heat_index

    elif apparent_temperature is not None:
        effective_temperature = apparent_temperature

    elif wet_bulb_temperature is not None:
        effective_temperature = wet_bulb_temperature

    baseline = 25

    thermal_intensity = max(
        0,
        effective_temperature - baseline
    )

    exposure = (
        thermal_intensity
        * duration_minutes
        / 10
    )

    return round(exposure, 2)


def calculate_route_exposure(segments):
    """
    Calculate total thermal exposure for a journey.
    Final score is normalized between 0 and 100.
    """

    total_exposure = 0

    for segment in segments:

        total_exposure += calculate_segment_exposure(
            temperature=segment.get(
                "temperature",
                0
            ),
            duration_minutes=segment.get(
                "duration_minutes",
                0
            ),
            heat_index=segment.get(
                "heat_index"
            ),
            apparent_temperature=segment.get(
                "apparent_temperature"
            ),
            wet_bulb_temperature=segment.get(
                "wet_bulb_temperature"
            ),
        )

    return round(
        clamp(total_exposure),
        2
    )


def exposure_level(score):

    score = clamp(score)

    if score < 30:
        return "LOW"

    if score < 50:
        return "MODERATE"

    if score < 70:
        return "HIGH"

    return "EXTREME"


def explain_exposure(score):

    level = exposure_level(score)

    explanations = {

        "LOW":
            "Low estimated thermal exposure.",

        "MODERATE":
            "Moderate estimated thermal exposure. "
            "Consider reducing prolonged outdoor exposure.",

        "HIGH":
            "High estimated thermal exposure. "
            "Consider taking a cooling break or "
            "choosing a lower-exposure journey.",

        "EXTREME":
            "Extreme estimated thermal exposure. "
            "Consider avoiding prolonged outdoor exposure "
            "and finding a cooler location.",
    }

    return explanations[level]