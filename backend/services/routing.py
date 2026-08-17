import requests

from ..models.route_models import Route, RoutePoint


# ============================================================
# ROUTE MODEL FUNCTIONS
# ============================================================


def build_route(
    route_id: str,
    points: list[RoutePoint],
    distance_m: float,
    estimated_time_s: float,
) -> Route:
    """
    Build a Route model from a sequence of geographic points.
    """

    if len(points) < 2:
        raise ValueError(
            "At least two route points are required."
        )

    if distance_m <= 0:
        raise ValueError(
            "Route distance must be greater than zero."
        )

    if estimated_time_s <= 0:
        raise ValueError(
            "Route travel time must be greater than zero."
        )

    if not route_id.strip():
        raise ValueError(
            "Route ID cannot be empty."
        )

    return Route(
        route_id=route_id,
        origin=points[0],
        destination=points[-1],
        distance_m=distance_m,
        estimated_time_s=estimated_time_s,
        segments=[],
    )


def validate_route_alternatives(
    routes: list[Route],
) -> list[Route]:
    """
    Validate a collection of route alternatives.
    """

    if not routes:
        raise ValueError(
            "At least one route alternative is required."
        )

    route_ids = set()

    for route in routes:

        if not route.route_id.strip():
            raise ValueError(
                "Route ID cannot be empty."
            )

        if route.route_id in route_ids:
            raise ValueError(
                f"Duplicate route ID: {route.route_id}"
            )

        route_ids.add(route.route_id)

        if route.distance_m <= 0:
            raise ValueError(
                f"Route {route.route_id} must have "
                "a positive distance."
            )

        if route.estimated_time_s <= 0:
            raise ValueError(
                f"Route {route.route_id} must have "
                "a positive travel time."
            )

    return routes


def sort_routes_by_travel_time(
    routes: list[Route],
) -> list[Route]:
    """
    Return route alternatives ordered from fastest to slowest.
    """

    validate_route_alternatives(routes)

    return sorted(
        routes,
        key=lambda route: route.estimated_time_s,
    )


def get_fastest_route(
    routes: list[Route],
) -> Route:
    """
    Return the fastest route.

    This is a baseline/reference route only.
    """

    validate_route_alternatives(routes)

    return min(
        routes,
        key=lambda route: route.estimated_time_s,
    )


def calculate_time_increase_percentage(
    route: Route,
    baseline_route: Route,
) -> float:
    """
    Calculate percentage travel-time increase
    compared with a baseline route.
    """

    if route.estimated_time_s <= 0:
        raise ValueError(
            "Route travel time must be greater than zero."
        )

    if baseline_route.estimated_time_s <= 0:
        raise ValueError(
            "Baseline route travel time must be greater than zero."
        )

    return (
        (
            route.estimated_time_s
            - baseline_route.estimated_time_s
        )
        / baseline_route.estimated_time_s
    ) * 100.0


# ============================================================
# REAL ROUTING
# ============================================================

OSRM_BASE_URL = (
    "https://router.project-osrm.org"
)

NOMINATIM_URL = (
    "https://nominatim.openstreetmap.org/search"
)


# ============================================================
# GEOCODING
# ============================================================

def geocode_location(
    location: str,
) -> tuple[float, float]:
    """
    Convert a location name into latitude and longitude.

    Known ThermoRoute demo locations are handled directly.
    Other locations use OpenStreetMap Nominatim.
    """

    location_lower = location.lower().strip()

    # ========================================================
    # KNOWN DEMO LOCATIONS
    # ========================================================

    if "pes university" in location_lower:
        return (
            12.9341811,
            77.5347038,
        )

    if "jp nagar metro" in location_lower:
        return (
            12.907299,
            77.573133,
        )

    # ========================================================
    # OPENSTREETMAP FALLBACK
    # ========================================================

    response = requests.get(
        NOMINATIM_URL,
        params={
            "q": location,
            "format": "json",
            "limit": 1,
        },
        headers={
            "User-Agent": (
                "ThermoRoute-Hackathon/1.0"
            )
        },
        timeout=10,
    )

    response.raise_for_status()

    results = response.json()

    if not results:
        raise ValueError(
            f"Could not find location: {location}"
        )

    latitude = float(
        results[0]["lat"]
    )

    longitude = float(
        results[0]["lon"]
    )

    return latitude, longitude


# ============================================================
# BUILD THERMAL SEGMENTS
# ============================================================

def _build_thermal_segments(
    route: dict,
    max_segments: int = 20,
) -> list[dict]:
    """
    Convert real OSRM route geometry into thermal-analysis
    segments.

    Temperature is currently demo fallback.
    FortyGuard will replace it when the API key is available.
    """

    geometry = route.get(
        "geometry",
        {},
    )

    coordinates = geometry.get(
        "coordinates",
        [],
    )

    if len(coordinates) < 2:
        return []

    total_duration_minutes = (
        route["duration"] / 60.0
    )

    total_distance_m = route["distance"]

    # ========================================================
    # DOWNSAMPLE LONG ROUTES
    # ========================================================

    if len(coordinates) > max_segments + 1:

        step = (
            len(coordinates) - 1
        ) / max_segments

        sampled_coordinates = []

        for i in range(max_segments + 1):

            index = round(
                i * step
            )

            index = min(
                index,
                len(coordinates) - 1,
            )

            sampled_coordinates.append(
                coordinates[index]
            )

        coordinates = sampled_coordinates

    number_of_segments = (
        len(coordinates) - 1
    )

    if number_of_segments <= 0:
        return []

    segment_duration = (
        total_duration_minutes
        / number_of_segments
    )

    segment_distance = (
        total_distance_m
        / number_of_segments
    )

    segments = []

    # ========================================================
    # CREATE SEGMENTS
    # ========================================================

    for i in range(number_of_segments):

        longitude, latitude = coordinates[i]

        segments.append(
            {
                "latitude": latitude,

                "longitude": longitude,

                # =================================================
                # DEMO TEMPERATURE
                # =================================================
                # Tomorrow this will come from FortyGuard.
                # =================================================

                "temperature": 32,

                "duration_minutes": round(
                    segment_duration,
                    2,
                ),

                "distance_m": round(
                    segment_distance,
                    2,
                ),
            }
        )

    return segments


# ============================================================
# GET REAL ROUTES
# ============================================================
def get_real_routes(
    from_location: str,
    destination: str,
    departure_time: str,
) -> list[dict]:
    """
    Get 3 real-road route alternatives using OSRM.

    Uses:
    1. Native OSRM alternatives
    2. Real-road waypoint variations when OSRM returns fewer than 3
    """

    # ------------------------------------------------------------
    # GEOCODE LOCATIONS
    # ------------------------------------------------------------

    start_latitude, start_longitude = geocode_location(
        from_location
    )

    destination_latitude, destination_longitude = geocode_location(
        destination
    )

    start_coordinate = (
        f"{start_longitude},{start_latitude}"
    )

    destination_coordinate = (
        f"{destination_longitude},{destination_latitude}"
    )

    coordinates = (
        f"{start_coordinate};"
        f"{destination_coordinate}"
    )

    # ------------------------------------------------------------
    # ASK OSRM FOR ALTERNATIVES
    # ------------------------------------------------------------

    url = (
        f"{OSRM_BASE_URL}"
        f"/route/v1/driving/"
        f"{coordinates}"
    )

    response = requests.get(
        url,
        params={
            "alternatives": "true",
            "overview": "full",
            "geometries": "geojson",
            "steps": "false",
        },
        timeout=20,
    )

    response.raise_for_status()

    data = response.json()

    if data.get("code") != "Ok":
        raise ValueError(
            f"OSRM routing failed: {data.get('code')}"
        )

    routes = data.get("routes", [])

    if not routes:
        raise ValueError(
            "No routes found between the selected locations."
        )

    # ------------------------------------------------------------
    # START WITH ALL ROUTES RETURNED BY OSRM
    # ------------------------------------------------------------

    candidate_routes = list(routes)

    # ------------------------------------------------------------
    # GET BASE ROUTE GEOMETRY
    # ------------------------------------------------------------

    base_geometry = (
        routes[0]
        .get("geometry", {})
        .get("coordinates", [])
    )

    # ------------------------------------------------------------
    # CREATE EXTRA REAL-ROAD ROUTES
    #
    # We force OSRM through different points on the
    # REAL road geometry.
    # ------------------------------------------------------------

    if len(candidate_routes) < 3 and len(base_geometry) >= 6:

        waypoint_indexes = [
            len(base_geometry) // 4,
            len(base_geometry) // 3,
            len(base_geometry) // 2,
            (len(base_geometry) * 2) // 3,
            (len(base_geometry) * 3) // 4,
        ]

        for waypoint_index in waypoint_indexes:

            if len(candidate_routes) >= 3:
                break

            waypoint_index = max(
                1,
                min(
                    waypoint_index,
                    len(base_geometry) - 2,
                ),
            )

            waypoint = base_geometry[waypoint_index]

            waypoint_coordinate = (
                f"{waypoint[0]},{waypoint[1]}"
            )

            waypoint_url = (
                f"{OSRM_BASE_URL}"
                f"/route/v1/driving/"
                f"{start_coordinate};"
                f"{waypoint_coordinate};"
                f"{destination_coordinate}"
            )

            try:

                waypoint_response = requests.get(
                    waypoint_url,
                    params={
                        "overview": "full",
                        "geometries": "geojson",
                        "steps": "false",
                    },
                    timeout=20,
                )

                waypoint_response.raise_for_status()

                waypoint_data = waypoint_response.json()

                if waypoint_data.get("code") != "Ok":
                    continue

                waypoint_routes = waypoint_data.get(
                    "routes",
                    [],
                )

                if not waypoint_routes:
                    continue

                new_route = waypoint_routes[0]

                # ------------------------------------------------
                # ADD THE REAL ROUTE
                #
                # For the demo we intentionally allow routes
                # with similar distance/time if their geometry
                # came from a different real-road waypoint.
                # ------------------------------------------------

                candidate_routes.append(new_route)

            except Exception:
                continue

    # ------------------------------------------------------------
    # SAFETY FALLBACK
    #
    # If OSRM only gives one route, request several real-road
    # waypoint routes directly.
    # ------------------------------------------------------------

    if len(candidate_routes) < 3 and len(base_geometry) >= 4:

        extra_indexes = [
            len(base_geometry) // 5,
            (len(base_geometry) * 2) // 5,
            (len(base_geometry) * 3) // 5,
            (len(base_geometry) * 4) // 5,
        ]

        for waypoint_index in extra_indexes:

            if len(candidate_routes) >= 3:
                break

            waypoint_index = max(
                1,
                min(
                    waypoint_index,
                    len(base_geometry) - 2,
                ),
            )

            waypoint = base_geometry[waypoint_index]

            waypoint_coordinate = (
                f"{waypoint[0]},{waypoint[1]}"
            )

            waypoint_url = (
                f"{OSRM_BASE_URL}"
                f"/route/v1/driving/"
                f"{start_coordinate};"
                f"{waypoint_coordinate};"
                f"{destination_coordinate}"
            )

            try:

                waypoint_response = requests.get(
                    waypoint_url,
                    params={
                        "overview": "full",
                        "geometries": "geojson",
                        "steps": "false",
                    },
                    timeout=20,
                )

                waypoint_response.raise_for_status()

                waypoint_data = waypoint_response.json()

                if waypoint_data.get("code") != "Ok":
                    continue

                waypoint_routes = waypoint_data.get(
                    "routes",
                    [],
                )

                if waypoint_routes:
                    candidate_routes.append(
                        waypoint_routes[0]
                    )

            except Exception:
                continue

    # ------------------------------------------------------------
    # BUILD THERMOROUTE SCENARIOS
    # ------------------------------------------------------------

    scenarios = []

    for index, route in enumerate(
        candidate_routes[:3]
    ):

        route_name = (
            f"Route {chr(65 + index)}"
        )

        distance_km = (
            route["distance"] / 1000.0
        )

        travel_time_min = (
            route["duration"] / 60.0
        )

        geometry = route.get(
            "geometry",
            {},
        )

        segments = _build_thermal_segments(
            route,
            max_segments=20,
        )

        scenarios.append(
            {
                "route": route_name,

                "departure_time": departure_time,

                "travel_time_min": round(
                    travel_time_min,
                    2,
                ),

                "distance_km": round(
                    distance_km,
                    2,
                ),

                "segments": segments,

                "geometry": geometry,

                "routing_source": "OSRM",
            }
        )

    # ------------------------------------------------------------
    # GUARANTEE AT LEAST ONE ROUTE
    # ------------------------------------------------------------

    if not scenarios:
        raise ValueError(
            "ThermoRoute could not create a route."
        )

    return scenarios