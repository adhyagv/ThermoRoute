import pytest

from backend.models.route_models import RoutePoint
from backend.services.segmentation import create_route_segments


def make_points():
    return [
        RoutePoint(latitude=33.4484, longitude=-112.0740),
        RoutePoint(latitude=33.4500, longitude=-112.0720),
        RoutePoint(latitude=33.4520, longitude=-112.0700),
    ]


def test_create_route_segments():
    points = make_points()

    distances = [100.0, 200.0]
    times = [10.0, 20.0]

    segments = create_route_segments(
        points=points,
        distances=distances,
        times=times,
    )

    assert len(segments) == 2

    assert segments[0].segment_id == "segment_1"
    assert segments[1].segment_id == "segment_2"

    assert segments[0].origin == points[0]
    assert segments[0].destination == points[1]

    assert segments[1].origin == points[1]
    assert segments[1].destination == points[2]

    assert segments[0].distance_m == 100.0
    assert segments[1].distance_m == 200.0

    assert segments[0].estimated_time_s == 10.0
    assert segments[1].estimated_time_s == 20.0


def test_create_route_segments_rejects_mismatched_lengths():
    points = make_points()

    with pytest.raises(ValueError):
        create_route_segments(
            points=points,
            distances=[100.0],
            times=[10.0, 20.0],
        )


def test_create_route_segments_requires_two_points():
    points = [
        RoutePoint(
            latitude=33.4484,
            longitude=-112.0740,
        )
    ]

    with pytest.raises(ValueError):
        create_route_segments(
            points=points,
            distances=[],
            times=[],
        )