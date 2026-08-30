from backend.models.route_models import RoutePoint
from backend.services.routing import (
    build_route,
    calculate_time_increase_percentage,
    get_fastest_route,
    sort_routes_by_travel_time,
)


def make_route(route_id: str, time_s: float):
    points = [
        RoutePoint(latitude=33.4484, longitude=-112.0740),
        RoutePoint(latitude=33.4650, longitude=-112.0600),
    ]

    return build_route(
        route_id=route_id,
        points=points,
        distance_m=3000.0,
        estimated_time_s=time_s,
    )


def test_build_route_creates_origin_and_destination():
    route = make_route("route_a", 1200.0)

    assert route.route_id == "route_a"
    assert route.origin.latitude == 33.4484
    assert route.destination.latitude == 33.4650
    assert route.distance_m == 3000.0
    assert route.estimated_time_s == 1200.0
    assert route.segments == []


def test_build_route_rejects_invalid_points():
    points = [
        RoutePoint(latitude=33.4484, longitude=-112.0740),
    ]

    try:
        build_route(
            route_id="route_a",
            points=points,
            distance_m=3000.0,
            estimated_time_s=1200.0,
        )
    except ValueError as exc:
        assert "At least two route points" in str(exc)
    else:
        raise AssertionError("Expected ValueError")


def test_sort_routes_by_travel_time():
    routes = [
        make_route("route_a", 1800.0),
        make_route("route_b", 1200.0),
        make_route("route_c", 1500.0),
    ]

    sorted_routes = sort_routes_by_travel_time(routes)

    assert [route.route_id for route in sorted_routes] == [
        "route_b",
        "route_c",
        "route_a",
    ]


def test_get_fastest_route():
    routes = [
        make_route("route_a", 1800.0),
        make_route("route_b", 1200.0),
    ]

    fastest = get_fastest_route(routes)

    assert fastest.route_id == "route_b"


def test_calculate_time_increase_percentage():
    route = make_route("route_b", 1500.0)
    baseline = make_route("route_a", 1200.0)

    increase = calculate_time_increase_percentage(
        route,
        baseline,
    )

    assert increase == 25.0