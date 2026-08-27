from backend.services.thermal import (
    calculate_route_exposure,
    exposure_level,
    explain_exposure,
)


def optimize_journey(
    scenarios,
    fastest_time,
    max_extra_time_percent,
    thermal_exposure_budget,
):
    """
    Select the best journey based on:

    1. Maximum allowed travel time
    2. Thermal exposure budget
    3. Lowest thermal exposure

    The fastest route is used as the baseline.
    """

    max_allowed_time = fastest_time * (
        1 + max_extra_time_percent / 100
    )

    valid_options = []

    for scenario in scenarios:

        travel_time = scenario.get(
            "travel_time_min",
            0
        )

        # Reject routes that take too long
        if travel_time > max_allowed_time:
            continue

        # Calculate thermal exposure
        exposure = calculate_route_exposure(
            scenario.get("segments", [])
        )

        # Reject routes exceeding heat budget
        if exposure > thermal_exposure_budget:
            continue

        option = {
            "route": scenario.get(
                "route",
                []
            ),

            "departure_time": scenario.get(
                "departure_time"
            ),

            "travel_time_min": travel_time,

            "distance_km": scenario.get(
                "distance_km",
                0
            ),

            "thermal_exposure": exposure,

            "thermal_level": exposure_level(
                exposure
            ),

            "thermal_explanation":
                explain_exposure(exposure),
        }

        valid_options.append(option)

    # No route satisfies the constraints
    if not valid_options:

        return {
            "found": False,

            "message": (
                "No journey satisfies both "
                "the travel-time and thermal "
                "exposure constraints."
            ),

            "options": [],
        }

    # Best route = lowest thermal exposure
    # while satisfying travel-time constraint
    best = min(
        valid_options,
        key=lambda option:
        option["thermal_exposure"]
    )

    return {
        "found": True,

        "best_journey": best,

        "options": valid_options,

        "constraints": {
            "fastest_time_min": fastest_time,

            "max_extra_time_percent":
                max_extra_time_percent,

            "max_allowed_time_min":
                round(max_allowed_time, 2),

            "thermal_exposure_budget":
                thermal_exposure_budget,
        },
    }