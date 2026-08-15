from backend.services.thermal import calculate_route_exposure


# ============================================================
# MAXIMUM ALLOWED TRAVEL TIME
# ============================================================

def max_allowed_time(
    fastest_time,
    max_extra_time_percent
):
    """
    Calculate the maximum travel time allowed.

    Example:
        fastest_time = 20
        max_extra_time_percent = 20

        20 * (1 + 20/100) = 24 minutes
    """

    return round(
        fastest_time * (
            1 + max_extra_time_percent / 100
        ),
        2
    )


# ============================================================
# EVALUATE ALL ROUTE SCENARIOS
# ============================================================

def evaluate_scenarios(
    scenarios,
    fastest_time,
    max_extra_time_percent,
    thermal_exposure_budget
):
    """
    Evaluate every route scenario.

    Each route is checked against two independent constraints:

    1. Maximum allowed travel time
    2. Maximum thermal exposure budget

    Returns every route with:
        - travel time
        - distance
        - thermal exposure
        - time constraint result
        - exposure constraint result
        - validity
        - status
        - explanation

    This is a deterministic and explainable
    optimization engine. It is NOT a trained ML model.
    """

    # Calculate maximum permitted travel time
    allowed_time = max_allowed_time(
        fastest_time,
        max_extra_time_percent
    )

    evaluated_options = []

    for scenario in scenarios:

        # ----------------------------------------------------
        # BASIC ROUTE INFORMATION
        # ----------------------------------------------------

        route_name = scenario["route"]

        departure_time = scenario["departure_time"]

        travel_time = scenario["travel_time_min"]

        distance = scenario["distance_km"]

        segments = scenario["segments"]

        # ----------------------------------------------------
        # THERMAL EXPOSURE
        # ----------------------------------------------------

        exposure = calculate_route_exposure(
            segments
        )

        # ----------------------------------------------------
        # CHECK TIME CONSTRAINT
        # ----------------------------------------------------

        within_time = (
            travel_time <= allowed_time
        )

        # ----------------------------------------------------
        # CHECK THERMAL EXPOSURE CONSTRAINT
        # ----------------------------------------------------

        within_exposure = (
            exposure <= thermal_exposure_budget
        )

        # ----------------------------------------------------
        # FINAL VALIDITY
        # ----------------------------------------------------

        is_valid = (
            within_time
            and
            within_exposure
        )

        # ----------------------------------------------------
        # EXPLANATION
        # ----------------------------------------------------

        if is_valid:

            status = "valid"

            reason = (
                "Within travel-time and "
                "thermal-exposure limits."
            )

        elif (
            not within_time
            and
            not within_exposure
        ):

            status = "rejected"

            reason = (
                "Exceeds both the travel-time limit "
                "and thermal-exposure budget."
            )

        elif not within_time:

            status = "rejected"

            reason = (
                "Exceeds the maximum allowed "
                "travel time."
            )

        else:

            status = "rejected"

            reason = (
                "Exceeds the thermal-exposure budget."
            )

        # ----------------------------------------------------
        # STORE EVALUATED ROUTE
        # ----------------------------------------------------

        evaluated_options.append({

            "route": route_name,

            "departure_time": departure_time,

            "travel_time_min": travel_time,

            "distance_km": distance,

            "thermal_exposure": exposure,

            "within_time_limit": within_time,

            "within_exposure_budget": within_exposure,

            "valid": is_valid,

            "status": status,

            "reason": reason,

            "recommended": False
        })

    return evaluated_options


# ============================================================
# BASIC OPTIMIZATION
# ============================================================

def optimize_journey(
    scenarios,
    fastest_time,
    max_extra_time_percent,
    thermal_exposure_budget
):
    """
    Select the valid route with the lowest
    estimated thermal exposure.

    Only routes satisfying ALL constraints
    are considered.

    Returns:
        Recommended route dictionary

    Returns None when no route satisfies
    all constraints.
    """

    evaluated_options = evaluate_scenarios(
        scenarios=scenarios,
        fastest_time=fastest_time,
        max_extra_time_percent=max_extra_time_percent,
        thermal_exposure_budget=thermal_exposure_budget
    )

    # --------------------------------------------------------
    # FILTER ONLY VALID ROUTES
    # --------------------------------------------------------

    valid_options = [
        option
        for option in evaluated_options
        if option["valid"]
    ]

    # --------------------------------------------------------
    # NO VALID ROUTE
    # --------------------------------------------------------

    if not valid_options:
        return None

    # --------------------------------------------------------
    # SELECT LOWEST THERMAL EXPOSURE
    # --------------------------------------------------------

    best = min(
        valid_options,
        key=lambda option: option["thermal_exposure"]
    )

    return best


# ============================================================
# OPTIMIZATION WITH ALL OPTIONS
# ============================================================

def optimize_journey_with_options(
    scenarios,
    fastest_time,
    max_extra_time_percent,
    thermal_exposure_budget
):
    """
    Return:

    1. Recommended route
    2. All evaluated route options
    3. Optimization constraints

    This is useful for the ThermoRoute hackathon UI
    because judges can see:

        - which route was selected
        - which routes were rejected
        - why they were rejected
        - travel-time constraint
        - thermal-exposure constraint

    The optimization is deterministic and explainable.
    """

    # --------------------------------------------------------
    # EVALUATE ALL ROUTES
    # --------------------------------------------------------

    evaluated_options = evaluate_scenarios(
        scenarios=scenarios,
        fastest_time=fastest_time,
        max_extra_time_percent=max_extra_time_percent,
        thermal_exposure_budget=thermal_exposure_budget
    )

    # --------------------------------------------------------
    # FIND VALID ROUTES
    # --------------------------------------------------------

    valid_options = [
        option
        for option in evaluated_options
        if option["valid"]
    ]

    # --------------------------------------------------------
    # SELECT BEST ROUTE
    # --------------------------------------------------------

    if valid_options:

        best = min(
            valid_options,
            key=lambda option: option["thermal_exposure"]
        )

        recommended_route = best["route"]

        # Mark only the selected route
        for option in evaluated_options:

            option["recommended"] = (
                option["route"] == recommended_route
            )

    else:

        recommended_route = None

        for option in evaluated_options:

            option["recommended"] = False

    # --------------------------------------------------------
    # GET RECOMMENDED OPTION
    # --------------------------------------------------------

    recommended = next(
        (
            option
            for option in evaluated_options
            if option["recommended"]
        ),
        None
    )

    # --------------------------------------------------------
    # RETURN COMPLETE RESULT
    # --------------------------------------------------------

    return {

        "recommended": recommended,

        "options": evaluated_options,

        "constraints": {

            "fastest_time_min": fastest_time,

            "max_extra_time_percent":
                max_extra_time_percent,

            "max_allowed_time_min":
                max_allowed_time(
                    fastest_time,
                    max_extra_time_percent
                ),

            "thermal_exposure_budget":
                thermal_exposure_budget
        }
    }


# ============================================================
# DEMO / TEST DATA
# ============================================================

if __name__ == "__main__":

    # ========================================================
    # ROUTE SCENARIOS
    # ========================================================

    scenarios = [

        # ----------------------------------------------------
        # ROUTE A - FASTEST
        # ----------------------------------------------------

        {
            "route": "Route A",

            "departure_time": "14:00",

            "travel_time_min": 20,

            "distance_km": 2.4,

            "segments": [

                {
                    "temperature": 36,
                    "duration_minutes": 5
                },

                {
                    "temperature": 38,
                    "duration_minutes": 6
                },

                {
                    "temperature": 34,
                    "duration_minutes": 5
                }
            ]
        },

        # ----------------------------------------------------
        # ROUTE B - RECOMMENDED
        # ----------------------------------------------------

        {
            "route": "Route B",

            "departure_time": "16:00",

            "travel_time_min": 23,

            "distance_km": 2.7,

            "segments": [

                {
                    "temperature": 31,
                    "duration_minutes": 7
                },

                {
                    "temperature": 32,
                    "duration_minutes": 8
                },

                {
                    "temperature": 33,
                    "duration_minutes": 6
                }
            ]
        },

        # ----------------------------------------------------
        # ROUTE C - LOWEST EXPOSURE
        # BUT TOO SLOW
        # ----------------------------------------------------

        {
            "route": "Route C",

            "departure_time": "16:00",

            "travel_time_min": 25,

            "distance_km": 3.1,

            "segments": [

                {
                    "temperature": 31,
                    "duration_minutes": 8
                },

                {
                    "temperature": 30,
                    "duration_minutes": 8
                },

                {
                    "temperature": 31,
                    "duration_minutes": 7
                }
            ]
        }
    ]

    # ========================================================
    # OPTIMIZATION SETTINGS
    # ========================================================

    FASTEST_TIME = 20

    MAX_EXTRA_TIME_PERCENT = 20

    THERMAL_EXPOSURE_BUDGET = 50

    # ========================================================
    # RUN OPTIMIZATION
    # ========================================================

    result = optimize_journey_with_options(

        scenarios=scenarios,

        fastest_time=FASTEST_TIME,

        max_extra_time_percent=
            MAX_EXTRA_TIME_PERCENT,

        thermal_exposure_budget=
            THERMAL_EXPOSURE_BUDGET
    )

    # ========================================================
    # PRINT HEADER
    # ========================================================

    print()

    print("THERMOROUTE OPTIMIZATION")

    print("=" * 60)

    # ========================================================
    # PRINT CONSTRAINTS
    # ========================================================

    print()

    print(
        "Fastest travel time: "
        f"{result['constraints']['fastest_time_min']} min"
    )

    print(
        "Maximum extra travel time: "
        f"{result['constraints']['max_extra_time_percent']}%"
    )

    print(
        "Maximum allowed travel time: "
        f"{result['constraints']['max_allowed_time_min']} min"
    )

    print(
        "Thermal exposure budget: "
        f"{result['constraints']['thermal_exposure_budget']}"
    )

    # ========================================================
    # PRINT ROUTE OPTIONS
    # ========================================================

    print()

    print("ROUTE OPTIONS")

    print("-" * 60)

    for option in result["options"]:

        if option["recommended"]:

            recommended_text = " <-- RECOMMENDED"

        else:

            recommended_text = ""

        print()

        print(
            f"{option['route']}"
            f"{recommended_text}"
        )

        print(
            f"  Departure: "
            f"{option['departure_time']}"
        )

        print(
            f"  Travel time: "
            f"{option['travel_time_min']} min"
        )

        print(
            f"  Distance: "
            f"{option['distance_km']} km"
        )

        print(
            f"  Thermal exposure: "
            f"{option['thermal_exposure']}"
        )

        print(
            f"  Time limit: "
            f"{'PASS' if option['within_time_limit'] else 'FAIL'}"
        )

        print(
            f"  Exposure budget: "
            f"{'PASS' if option['within_exposure_budget'] else 'FAIL'}"
        )

        print(
            f"  Status: "
            f"{option['status']}"
        )

        print(
            f"  Reason: "
            f"{option['reason']}"
        )

    # ========================================================
    # FINAL DECISION
    # ========================================================

    print()

    print("FINAL DECISION")

    print("-" * 60)

    if result["recommended"]:

        recommended = result["recommended"]

        print(
            "Recommended route: "
            f"{recommended['route']}"
        )

        print(
            "Travel time: "
            f"{recommended['travel_time_min']} min"
        )

        print(
            "Distance: "
            f"{recommended['distance_km']} km"
        )

        print(
            "Thermal exposure: "
            f"{recommended['thermal_exposure']}"
        )

        print(
            "Reason: "
            f"{recommended['reason']}"
        )

    else:

        print(
            "No route satisfies all constraints."
        )

    print()