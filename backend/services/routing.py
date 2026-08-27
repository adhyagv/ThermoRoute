# backend/services/routing.py

from datetime import datetime

from .temperature_provider import get_temperature_for_segment
from .thermal import (
    calculate_route_exposure,
    exposure_level,
    explain_exposure,
)


# ============================================================
# FORTYGUARD ENVIRONMENT ENRICHMENT
# ============================================================

def enrich_segment_environment(segment):
    """
    Fetch real environmental data from FortyGuard
    for one route segment.

    If FortyGuard fails, the original fallback
    temperature remains available.
    """

    latitude = segment.get("latitude")
    longitude = segment.get("longitude")

    fallback_temperature = segment.get(
        "temperature",
        35,
    )

    # --------------------------------------------------------
    # If coordinates are missing, use fallback
    # --------------------------------------------------------

    if latitude is None or longitude is None:

        segment["environment_source"] = "fallback"

        return segment

    try:

        environmental_data = get_temperature_for_segment(
            latitude=latitude,
            longitude=longitude,
            fallback_temperature=fallback_temperature,
        )

        # ----------------------------------------------------
        # Update temperature
        # ----------------------------------------------------

        segment["temperature"] = environmental_data.get(
            "temperature",
            fallback_temperature,
        )

        # ----------------------------------------------------
        # Update thermal parameters
        # ----------------------------------------------------

        heat_index = environmental_data.get(
            "heat_index"
        )

        apparent_temperature = environmental_data.get(
            "apparent_temperature"
        )

        wet_bulb_temperature = environmental_data.get(
            "wet_bulb_temperature"
        )

        if heat_index is not None:
            segment["heat_index"] = heat_index

        if apparent_temperature is not None:
            segment["apparent_temperature"] = (
                apparent_temperature
            )

        if wet_bulb_temperature is not None:
            segment["wet_bulb_temperature"] = (
                wet_bulb_temperature
            )

        # ----------------------------------------------------
        # Solar information
        # ----------------------------------------------------

        if environmental_data.get("ghi") is not None:
            segment["ghi"] = environmental_data["ghi"]

        if environmental_data.get("dni") is not None:
            segment["dni"] = environmental_data["dni"]

        if environmental_data.get("dhi") is not None:
            segment["dhi"] = environmental_data["dhi"]

        # ----------------------------------------------------
        # Source
        # ----------------------------------------------------

        segment["environment_source"] = environmental_data.get(
            "source",
            "fortyguard",
        )

        # Keep activity ID if available
        if environmental_data.get("activity_id"):
            segment["activity_id"] = (
                environmental_data["activity_id"]
            )

    except Exception as error:

        # ----------------------------------------------------
        # Keep demo system working if FortyGuard fails
        # ----------------------------------------------------

        segment["environment_source"] = "fallback"

        segment["environment_error"] = str(error)

    return segment


# ============================================================
# ENRICH COMPLETE ROUTE
# ============================================================

def enrich_route_environment(route):
    """
    Fetch FortyGuard environmental data for every
    segment in a route and calculate thermal exposure.
    """

    enriched_route = dict(route)

    enriched_segments = []

    for segment in route.get("segments", []):

        segment_copy = dict(segment)

        segment_copy = enrich_segment_environment(
            segment_copy
        )

        enriched_segments.append(
            segment_copy
        )

    enriched_route["segments"] = enriched_segments

    # --------------------------------------------------------
    # Calculate total route exposure
    # --------------------------------------------------------

    thermal_exposure = calculate_route_exposure(
        enriched_segments
    )

    enriched_route["thermal_exposure"] = thermal_exposure

    enriched_route["thermal_level"] = exposure_level(
        thermal_exposure
    )

    enriched_route["thermal_explanation"] = explain_exposure(
        thermal_exposure
    )

    return enriched_route


# ============================================================
# ROUTE SCENARIO CREATION
# ============================================================

def create_route_scenario(
    route,
    travel_time_min,
    distance_km,
    departure_time,
    segments,
    hazards=None,
):
    """
    Create a standardized ThermoRoute journey scenario.
    """

    return {
        "route": route,
        "travel_time_min": travel_time_min,
        "distance_km": distance_km,
        "departure_time": departure_time,
        "segments": segments,
        "hazards": hazards or [],
    }


# ============================================================
# GENERATE STANDARDIZED ROUTE SCENARIOS
# ============================================================

def generate_route_scenarios(
    origin,
    destination,
    departure_time,
    routes,
):
    """
    Convert route dictionaries into standardized
    ThermoRoute journey scenarios.

    FortyGuard environmental data is fetched before
    creating the final scenarios.
    """

    scenarios = []

    for route in routes:

        # ----------------------------------------------------
        # Enrich route using FortyGuard
        # ----------------------------------------------------

        enriched_route = enrich_route_environment(
            route
        )

        # ----------------------------------------------------
        # Create standardized scenario
        # ----------------------------------------------------

        scenario = create_route_scenario(

            route=enriched_route.get(
                "route",
                [origin, destination],
            ),

            travel_time_min=enriched_route.get(
                "travel_time_min",
                0,
            ),

            distance_km=enriched_route.get(
                "distance_km",
                0,
            ),

            departure_time=enriched_route.get(
                "departure_time",
                departure_time,
            ),

            segments=enriched_route.get(
                "segments",
                [],
            ),

            hazards=enriched_route.get(
                "hazards",
                [],
            ),
        )

        # ----------------------------------------------------
        # Preserve calculated thermal information
        # ----------------------------------------------------

        scenario["thermal_exposure"] = enriched_route.get(
            "thermal_exposure",
            0,
        )

        scenario["thermal_level"] = enriched_route.get(
            "thermal_level",
            "LOW",
        )

        scenario["thermal_explanation"] = (
            enriched_route.get(
                "thermal_explanation",
                "",
            )
        )

        scenarios.append(
            scenario
        )

    return scenarios


# ============================================================
# BUILD ROUTE SCENARIOS
# ============================================================

def build_route_scenarios(
    from_location,
    destination,
    departure_time,
):
    """
    Build route scenarios for ThermoRoute.

    Currently uses Arizona demo routes.
    """

    routes = create_demo_routes(
        origin=from_location,
        destination=destination,
        departure_time=departure_time,
    )

    return generate_route_scenarios(
        origin=from_location,
        destination=destination,
        departure_time=departure_time,
        routes=routes,
    )


# ============================================================
# ARIZONA DEMO ROUTES
# ============================================================

def create_demo_routes(
    origin,
    destination,
    departure_time,
):
    """
    Create demo routes with representative coordinates.

    The coordinates allow FortyGuard to retrieve
    environmental information for each segment.
    """

    routes = [

        # ====================================================
        # ROUTE 1
        # FASTEST BUT HIGHER HEAT EXPOSURE
        # ====================================================

        {
            "route": [
                origin,
                "Major Highway",
                destination,
            ],

            "travel_time_min": 30,

            "distance_km": 12.0,

            "departure_time": departure_time,

            "hazards": [
                "Low shade",
                "High traffic",
                "High heat exposure",
            ],

            "segments": [

                {
                    "location": "Major Highway",

                    "latitude": 33.4484,
                    "longitude": -112.0740,

                    "temperature": 42,

                    "duration_minutes": 10,

                    "heat_index": 45,

                    "hazards": [
                        "Low shade",
                        "High traffic",
                    ],
                },

                {
                    "location": "Major Highway",

                    "latitude": 33.4650,
                    "longitude": -112.0500,

                    "temperature": 40,

                    "duration_minutes": 20,

                    "heat_index": 43,

                    "hazards": [
                        "Heat-exposed road",
                    ],
                },
            ],
        },


        # ====================================================
        # ROUTE 2
        # SLIGHTLY LONGER BUT LOWER HEAT
        # ====================================================

        {
            "route": [
                origin,
                "Alternative Highway",
                destination,
            ],

            "travel_time_min": 35,

            "distance_km": 13.5,

            "departure_time": departure_time,

            "hazards": [
                "Moderate traffic",
                "Partial shade",
            ],

            "segments": [

                {
                    "location": "Alternative Highway",

                    "latitude": 33.4350,
                    "longitude": -111.9500,

                    "temperature": 38,

                    "duration_minutes": 15,

                    "heat_index": 40,

                    "hazards": [
                        "Partial shade",
                    ],
                },

                {
                    "location": "Alternative Highway",

                    "latitude": 33.4700,
                    "longitude": -111.9200,

                    "temperature": 37,

                    "duration_minutes": 20,

                    "heat_index": 39,

                    "hazards": [],
                },
            ],
        },


        # ====================================================
        # ROUTE 3
        # LONGER BUT LOWEST HEAT EXPOSURE
        # ====================================================

        {
            "route": [
                origin,
                "Lower-Exposure Corridor",
                destination,
            ],

            "travel_time_min": 42,

            "distance_km": 15.0,

            "departure_time": departure_time,

            "hazards": [
                "Low traffic",
                "Better shade coverage",
                "Lower heat exposure",
            ],

            "segments": [

                {
                    "location": "Lower-Exposure Corridor",

                    "latitude": 33.4550,
                    "longitude": -111.9000,

                    "temperature": 35,

                    "duration_minutes": 20,

                    "heat_index": 37,

                    "hazards": [
                        "Good shade coverage",
                    ],
                },

                {
                    "location": "Lower-Exposure Corridor",

                    "latitude": 33.4900,
                    "longitude": -111.8800,

                    "temperature": 34,

                    "duration_minutes": 22,

                    "heat_index": 36,

                    "hazards": [
                        "Low traffic",
                    ],
                },
            ],
        },
    ]

    return routes


# ============================================================
# CREATE DEMO SCENARIOS DIRECTLY
# ============================================================

def create_demo_scenarios(
    origin,
    destination,
    departure_time,
):
    """
    Create Arizona demo routes and convert them
    into standardized ThermoRoute scenarios.
    """

    routes = create_demo_routes(
        origin=origin,
        destination=destination,
        departure_time=departure_time,
    )

    return generate_route_scenarios(
        origin=origin,
        destination=destination,
        departure_time=departure_time,
        routes=routes,
    )