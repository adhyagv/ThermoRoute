import pytest
from datetime import datetime, timezone

from backend.models.climate_models import ClimateReading
from backend.models.route_models import RoutePoint, RouteSegment
from backend.services.anomaly import analyze_segment_anomaly


def make_segment() -> RouteSegment:
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
        distance_m=100.0,
        estimated_time_s=60.0,
    )


def make_reading(temperature_c: float) -> ClimateReading:
    return ClimateReading(
        latitude=33.4492,
        longitude=-112.0730,
        timestamp=datetime.now(timezone.utc),
        temperature_c=temperature_c,
        source="test",
    )


def test_normal_temperature():
    result = analyze_segment_anomaly(
        segment=make_segment(),
        reading=make_reading(30.0),
        baseline_c=30.0,
        anomaly_threshold_c=3.0,
        extreme_threshold_c=40.0,
    )

    assert result["anomaly_c"] == 0.0
    assert result["baseline_anomaly_detected"] is False
    assert result["condition"] == "normal"
    assert result["overall_anomaly_detected"] is False


def test_baseline_anomaly():
    result = analyze_segment_anomaly(
        segment=make_segment(),
        reading=make_reading(35.0),
        baseline_c=30.0,
        anomaly_threshold_c=3.0,
        extreme_threshold_c=40.0,
    )

    assert result["anomaly_c"] == 5.0
    assert result["baseline_anomaly_detected"] is True
    assert result["overall_anomaly_detected"] is True


def test_extreme_condition():
    result = analyze_segment_anomaly(
        segment=make_segment(),
        reading=make_reading(42.0),
        baseline_c=30.0,
        anomaly_threshold_c=3.0,
        extreme_threshold_c=40.0,
    )

    assert result["condition"] == "extreme"
    assert result["baseline_anomaly_detected"] is True
    assert result["overall_anomaly_detected"] is True


def test_historical_zscore():
    result = analyze_segment_anomaly(
        segment=make_segment(),
        reading=make_reading(40.0),
        baseline_c=30.0,
        anomaly_threshold_c=20.0,
        extreme_threshold_c=45.0,
        historical_temperatures_c=[
            29.0,
            30.0,
            30.0,
            31.0,
            30.0,
        ],
        zscore_threshold=2.0,
    )

    assert result["historical_mean_c"] is not None
    assert result["historical_std_c"] is not None
    assert result["zscore"] is not None
    assert result["zscore_anomaly_detected"] is True
    assert result["overall_anomaly_detected"] is True
