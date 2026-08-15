from ..models.route_models import Route, RoutePoint


def build_route(
    route_id: str,
    points: list[RoutePoint],
    distance_m: float,
    estimated_time_s: float,
) -> Route:
    """
    Build a Route model from a sequence of geographic points.

    Only the first and last points are used, as the origin and
    destination of the route. The full points list is required
    (not just origin/destination) so callers pass the same raw
    point sequence used elsewhere in the pipeline, keeping origin/
    destination consistent with the source data. Intermediate
    points and route segmentation are handled separately by
    segmentation.py — this function only builds the top-level
    Route shell.
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

    ThermoRoute expects at least one usable route. Every route in
    the collection must have a unique, non-empty route_id and
    strictly positive distance/time.
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

    This does NOT choose the best thermal route.
    It only provides deterministic ordering.
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
    It is NOT ThermoRoute's final recommendation.
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
    Calculate how much longer a route is compared with
    a baseline route.

    Both routes are validated before the comparison is made, so
    this function never silently divides by an invalid value or
    returns a number computed from a malformed route.

    Returns:
        Percentage increase in travel time. Negative values mean
        the route is faster than the baseline (e.g. a "greener but
        slower" tradeoff route would return a positive value; a
        route that beats the baseline on time would return
        negative).
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
