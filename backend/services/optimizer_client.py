from typing import Any


class OptimizerError(Exception):
    """Raised when route optimization fails."""


def _risk_score(risk_level: str) -> float:
    """
    Convert a heat-risk level into a numeric penalty.
    """
    scores = {
        "low": 0.0,
        "moderate": 1.0,
        "high": 2.0,
        "extreme": 3.0,
    }

    return scores.get(
        risk_level.lower(),
        3.0,
    )


def calculate_route_optimization_score(
    travel_time_s: float,
    total_thermal_exposure: float,
    maximum_segment_exposure: float,
    anomaly_segment_count: int,
    extreme_segment_count: int,
    segment_count: int,
    maximum_heat_risk_level: str,
) -> float:
    """
    Calculate a normalized route score.

    Lower score = better route.

    The score balances:
        - travel time
        - cumulative thermal exposure
        - worst segment exposure
        - anomalous segments
        - extreme-heat segments
        - overall heat-risk level

    This is an internal routing objective, not a medical metric.
    """
    if travel_time_s <= 0:
        raise OptimizerError(
            "Travel time must be greater than zero."
        )

    if segment_count <= 0:
        raise OptimizerError(
            "Segment count must be greater than zero."
        )

    if total_thermal_exposure < 0:
        raise OptimizerError(
            "Thermal exposure cannot be negative."
        )

    if maximum_segment_exposure < 0:
        raise OptimizerError(
            "Maximum segment exposure cannot be negative."
        )

    if anomaly_segment_count < 0:
        raise OptimizerError(
            "Anomaly segment count cannot be negative."
        )

    if extreme_segment_count < 0:
        raise OptimizerError(
            "Extreme segment count cannot be negative."
        )

    if anomaly_segment_count > segment_count:
        raise OptimizerError(
            "Anomaly segment count cannot exceed "
            "segment count."
        )

    if extreme_segment_count > segment_count:
        raise OptimizerError(
            "Extreme segment count cannot exceed "
            "segment count."
        )

    normalized_exposure = (
        total_thermal_exposure
        / segment_count
    )

    normalized_anomaly = (
        anomaly_segment_count
        / segment_count
    )

    normalized_extreme = (
        extreme_segment_count
        / segment_count
    )

    risk_penalty = _risk_score(
        maximum_heat_risk_level
    )

    time_penalty = travel_time_s / 60.0

    score = (
        time_penalty * 0.20
        + normalized_exposure * 0.45
        + maximum_segment_exposure * 0.15
        + normalized_anomaly * 10.0 * 0.10
        + normalized_extreme * 10.0 * 0.07
        + risk_penalty * 0.03
    )

    return round(score, 6)


def optimize_routes(
    routes: list[dict[str, Any]],
) -> dict[str, Any]:
    """
    Rank multiple route candidates using their climate features.

    Each route must contain:
        route_id
        estimated_time_s
        climate_features
    """
    if not routes:
        raise OptimizerError(
            "At least one route is required."
        )

    scored_routes: list[dict[str, Any]] = []

    for route in routes:
        route_id = str(
            route.get("route_id", "")
        ).strip()

        if not route_id:
            raise OptimizerError(
                "Every route must have a route_id."
            )

        travel_time_s = float(
            route.get("estimated_time_s", 0)
        )

        climate = (
            route.get("climate_features")
            or {}
        )

        if not climate:
            raise OptimizerError(
                f"Route '{route_id}' has no climate features."
            )

        score = calculate_route_optimization_score(
            travel_time_s=travel_time_s,
            total_thermal_exposure=float(
                climate.get(
                    "total_thermal_exposure",
                    0,
                )
            ),
            maximum_segment_exposure=float(
                climate.get(
                    "maximum_segment_exposure",
                    0,
                )
            ),
            anomaly_segment_count=int(
                climate.get(
                    "anomaly_segment_count",
                    0,
                )
            ),
            extreme_segment_count=int(
                climate.get(
                    "extreme_segment_count",
                    0,
                )
            ),
            segment_count=int(
                climate.get(
                    "segment_count",
                    0,
                )
            ),
            maximum_heat_risk_level=str(
                climate.get(
                    "maximum_heat_risk_level",
                    "unknown",
                )
            ),
        )

        scored_routes.append(
            {
                "route_id": route_id,
                "optimization_score": score,
                "travel_time_s": travel_time_s,
                "total_thermal_exposure": climate.get(
                    "total_thermal_exposure"
                ),
                "maximum_segment_exposure": climate.get(
                    "maximum_segment_exposure"
                ),
                "maximum_heat_risk_level": climate.get(
                    "maximum_heat_risk_level"
                ),
                "anomaly_segment_count": climate.get(
                    "anomaly_segment_count"
                ),
                "extreme_segment_count": climate.get(
                    "extreme_segment_count"
                ),
            }
        )

    scored_routes.sort(
        key=lambda item: item[
            "optimization_score"
        ]
    )

    recommended = scored_routes[0]

    return {
        "recommended_route_id": (
            recommended["route_id"]
        ),
        "optimization_method": (
            "climate_aware_weighted_scoring"
        ),
        "routes_ranked": scored_routes,
    }