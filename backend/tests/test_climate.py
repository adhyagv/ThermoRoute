import pytest
from datetime import datetime, timezone

from backend.models.climate_models import ClimateReading
from backend.models.route_models import RoutePoint, RouteSegment
from backend.services.climate import (
    calculate_heat_risk_level,
    calculate_segment_exposure,
)


def make_segment(
    distance_m: float = 100.0,
    estimated_time_s: float = 60.0,
) -> RouteSegment:
    return RouteSegment(
        segment_id="segment_1",
        origin=RoutePoint(
            latitude=33.4484,
            longitude=-112.0740,
        ),
        destination=RoutePoint(
            latitude=33.4500,
            longitude=-112.0720,
        ),
        distance_m=distance_m,
        estimated_time_s=estimated_time_s,
    )


def make_reading(
    temperature_c: float,
) -> ClimateReading:
    return ClimateReading(
        latitude=33.4492,
        longitude=-112.0730,
        timestamp=datetime.now(timezone.utc),
        temperature_c=temperature_c,
        source="test",
    )


def test_heat_risk_levels():
    assert calculate_heat_risk_level(20.0) == "low"
    assert calculate_heat_risk_level(30.0) == "moderate"
    assert calculate_heat_risk_level(35.0) == "high"
    assert calculate_heat_risk_level(40.0) == "extreme"


def test_heat_risk_level_boundaries():
    assert calculate_heat_risk_level(24.9) == "low"
    assert calculate_heat_risk_level(25.0) == "low"
    assert calculate_heat_risk_level(32.0) == "moderate"
    assert calculate_heat_risk_level(32.1) == "moderate"
    assert calculate_heat_risk_level(38.0) == "high"
    assert calculate_heat_risk_level(38.1) == "high"


def test_segment_exposure_returns_positive_value():
    segment = make_segment()
    reading = make_reading(35.0)

    exposure = calculate_segment_exposure(
        segment=segment,
        reading=reading,
        baseline_c=30.0,
    )

    assert exposure > 0


def test_segment_exposure_increases_with_temperature():
    segment = make_segment()

    normal = calculate_segment_exposure(
        segment=segment,
        reading=make_reading(30.0),
        baseline_c=30.0,
    )

    hot = calculate_segment_exposure(
        segment=segment,
        reading=make_reading(40.0),
        baseline_c=30.0,
    )

    assert hot > normal


def test_segment_exposure_rejects_invalid_segment_distance():
    segment = make_segment(distance_m=0.0)
    reading = make_reading(35.0)

    with pytest.raises(ValueError):
        calculate_segment_exposure(
            segment=segment,
            reading=reading,
            baseline_c=30.0,
        )