import pytest

from backend.models.climate_models import ClimateReading
from backend.models.route_models import RoutePoint
from backend.services.routing import build_route
from backend.services.segmentation import create_route_segments
from backend.utils.validation import (
    validate_climate_reading,
    validate_route,
    validate_route_segment,
)


def make_point():
    return RoutePoint(
        latitude=33.4484,
        longitude=-112.0740,
    )


def make_segment():
    points = [
        make_point(),
        RoutePoint(
            latitude=33.4500,
            longitude=-112.0720,
        ),
    ]

    segments = create_route_segments(
        points=points,
        distances=[100.0],
        times=[60.0],
    )

    return segments[0]


def make_reading():
    return ClimateReading(
        latitude=33.4492,
        longitude=-112.0730,
        timestamp="2026-08-30T14:00:00+00:00",
        temperature_c=35.0,
        source="test",
    )


def test_valid_route_segment():
    segment = make_segment()

    assert validate_route_segment(segment) is None


def test_valid_climate_reading():
    reading = make_reading()

    assert validate_climate_reading(reading) is None


def test_invalid_climate_reading_temperature():
    reading = make_reading()

    reading = reading.model_copy(
        update={
            "temperature_c": -300.0,
        }
    )

    with pytest.raises((ValueError, TypeError)):
        validate_climate_reading(reading)


def test_valid_route():
    points = [
        make_point(),
        RoutePoint(
            latitude=33.4500,
            longitude=-112.0720,
        ),
    ]

    route = build_route(
        route_id="test_route",
        points=points,
        distance_m=100.0,
        estimated_time_s=60.0,
    )

    segments = create_route_segments(
        points=points,
        distances=[100.0],
        times=[60.0],
    )

    route = route.model_copy(
        update={
            "segments": segments,
        }
    )

    assert validate_route(route) is None