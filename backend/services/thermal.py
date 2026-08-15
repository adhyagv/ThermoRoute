def calculate_segment_exposure(temperature, duration_minutes):
    """
    Calculate estimated thermal exposure for one route segment.

    This is a relative modeling score, not a medical risk measurement.
    """

    if temperature <= 30:
        heat_factor = 1
    elif temperature <= 35:
        heat_factor = 2
    elif temperature <= 40:
        heat_factor = 3
    else:
        heat_factor = 4

    return heat_factor * duration_minutes


def calculate_route_exposure(segments):
    """
    Calculate total estimated thermal exposure for a route.
    """

    total_exposure = 0

    for segment in segments:
        exposure = calculate_segment_exposure(
            segment["temperature"],
            segment["duration_minutes"]
        )

        total_exposure += exposure

    return round(total_exposure, 2)
if __name__ == "__main__":
    route_a = [
        {"temperature": 36, "duration_minutes": 5},
        {"temperature": 38, "duration_minutes": 6},
        {"temperature": 34, "duration_minutes": 5},
    ]

    exposure = calculate_route_exposure(route_a)

    print("Estimated thermal exposure:", exposure)