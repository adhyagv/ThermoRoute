from thermal import calculate_route_exposure


def optimize_journey(
    scenarios,
    fastest_time,
    max_extra_time_percent,
    thermal_exposure_budget
):
    """
    Find the route + departure time with the lowest
    estimated thermal exposure while respecting constraints.
    """

    # Maximum travel time the user is willing to accept
    max_allowed_time = fastest_time * (
        1 + max_extra_time_percent / 100
    )

    valid_options = []

    for scenario in scenarios:

        travel_time = scenario["travel_time_min"]

        # Constraint 1: travel-time limit
        if travel_time > max_allowed_time:
            continue

        # Calculate thermal exposure
        exposure = calculate_route_exposure(
            scenario["segments"]
        )

        # Constraint 2: thermal exposure budget
        if exposure > thermal_exposure_budget:
            continue

        valid_options.append({
            "route": scenario["route"],
            "departure_time": scenario["departure_time"],
            "travel_time_min": travel_time,
            "distance_km": scenario["distance_km"],
            "thermal_exposure": exposure
        })

    # No option satisfies both constraints
    if not valid_options:
        return None

    # Select the option with minimum thermal exposure
    best = min(
        valid_options,
        key=lambda option: option["thermal_exposure"]
    )

    return best
if __name__ == "__main__":

    scenarios = [

        {
            "route": "Route A",
            "departure_time": "14:00",
            "travel_time_min": 20,
            "distance_km": 2.4,
            "segments": [
                {"temperature": 36, "duration_minutes": 5},
                {"temperature": 38, "duration_minutes": 6},
                {"temperature": 34, "duration_minutes": 5}
            ]
        },

        {
            "route": "Route B",
            "departure_time": "16:00",
            "travel_time_min": 23,
            "distance_km": 2.7,
            "segments": [
                {"temperature": 31, "duration_minutes": 7},
                {"temperature": 32, "duration_minutes": 8},
                {"temperature": 33, "duration_minutes": 6}
            ]
        }
    ]

    result = optimize_journey(
        scenarios=scenarios,
        fastest_time=20,
        max_extra_time_percent=20,
        thermal_exposure_budget=50
    )

    print("Recommended journey:")
    print(result)