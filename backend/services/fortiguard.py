import hashlib
import json
import os
import threading
import time
from datetime import datetime
from pathlib import Path
from typing import Any

import requests

from ..utils.env import (
    FORTYGUARD_API_KEY,
    FORTYGUARD_BASE_URL,
)
from ..models.climate_models import ClimateReading

DEFAULT_POLL_INTERVAL_SECONDS = 5
DEFAULT_MAX_POLL_ATTEMPTS = 120
DEFAULT_REQUEST_TIMEOUT_SECONDS = 60

# Successful heatmaps are cached in-process to prevent repeated frontend
# retries from creating duplicate FortyGuard jobs. Set the TTL to 0 to disable.
DEFAULT_HEATMAP_CACHE_TTL_SECONDS = int(
    os.getenv("FORTYGUARD_HEATMAP_CACHE_TTL_SECONDS", "600")
)

_HEATMAP_CACHE: dict[str, tuple[float, dict[str, Any]]] = {}
_HEATMAP_CACHE_LOCK = threading.Lock()

VALID_HEATMAP_FILTER_TYPES = {1, 2, 3, 4}
VALID_ENV_FILTER_TYPES = {1, 2, 3}
VALID_HEATMAP_GRANULARITIES = {60, 80, 100}

VALID_HEATMAP_ANALYTIC_TYPES = {
    "tcm",
    "time_of_measure",
    "exceedance",
    "persistence",
}

VALID_HEAT_INTELLIGENCE_ANALYSES = {
    "geographic",
    "environmental",
    "urban",
    "events",
    "anthropogenic",
}


class FortyGuardError(Exception):
    """Raised when a FortyGuard API request fails."""


class FortyGuardCoverageError(FortyGuardError):
    """
    Raised when FortyGuard cannot provide usable heatmap
    data for the requested location or route.
    """


def _headers() -> dict[str, str]:
    """Return headers required for FortyGuard API requests."""
    return {
        "api-key": FORTYGUARD_API_KEY,
        "Content-Type": "application/json",
    }


def _url(endpoint: str) -> str:
    """Build a full FortyGuard API URL."""
    return f"{FORTYGUARD_BASE_URL.rstrip('/')}{endpoint}"


def _validate_coordinates(
    latitude: float,
    longitude: float,
) -> None:
    """Validate latitude and longitude ranges."""
    if not -90.0 <= latitude <= 90.0:
        raise ValueError(
            f"Latitude must be between -90 and 90. Got {latitude}."
        )

    if not -180.0 <= longitude <= 180.0:
        raise ValueError(
            f"Longitude must be between -180 and 180. Got {longitude}."
        )


def _validate_temperature_c(
    temperature_c: float,
) -> None:
    """Validate a Celsius temperature."""
    if temperature_c < -273.15:
        raise ValueError(
            "Temperature cannot be below absolute zero."
        )


def _validate_api_response(
    response: requests.Response,
    operation: str,
) -> dict[str, Any]:
    """Validate HTTP response and parse JSON."""
    if not response.ok:
        body = response.text[:500]
        raise FortyGuardError(
            f"{operation} failed "
            f"({response.status_code}): {body}"
        )

    try:
        data = response.json()
    except ValueError as exc:
        raise FortyGuardError(
            f"{operation} returned a non-JSON response."
        ) from exc

    if not isinstance(data, dict):
        raise FortyGuardError(
            f"{operation} returned an unexpected response format."
        )

    if data.get("error") is True:
        raise FortyGuardError(
            f"{operation} returned an API error: "
            f"{data.get('message', 'Unknown error')}"
        )

    return data


def get_status(
    activity_id: str,
) -> dict[str, Any]:
    """
    Get the current status of a FortyGuard activity.
    """
    if not activity_id.strip():
        raise ValueError("activity_id cannot be empty.")

    try:
        response = requests.get(
            _url(f"/v1/status/{activity_id}"),
            headers=_headers(),
            timeout=DEFAULT_REQUEST_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise FortyGuardError(
            f"FortyGuard status request failed: {exc}"
        ) from exc

    return _validate_api_response(
        response,
        "FortyGuard status request",
    )


def request_heatmap(
    polygon_aoi: dict[str, Any],
    start_date: str,
    start_time: str | None = None,
    end_time: str | None = None,
    end_date: str | None = None,
    filter_type: int = 1,
    granularity: int = 100,
    analytic_type: str = "tcm",
    threshold: float | None = None,
    direction: str = "above",
) -> dict[str, Any]:
    """
    Submit a FortyGuard heatmap generation request.

    filter_type:
        1 = Single Hour
        2 = Range of Hours
        3 = Single Day
        4 = Range of Days

    analytic_type:
        tcm
        time_of_measure
        exceedance
        persistence
    """
    if not isinstance(polygon_aoi, dict):
        raise ValueError(
            "polygon_aoi must be a GeoJSON object."
        )

    if not start_date.strip():
        raise ValueError(
            "start_date cannot be empty."
        )

    if filter_type not in VALID_HEATMAP_FILTER_TYPES:
        raise ValueError(
            "Heatmap filter_type must be 1, 2, 3, or 4."
        )

    if granularity not in VALID_HEATMAP_GRANULARITIES:
        raise ValueError(
            "Heatmap granularity must be 60, 80, or 100."
        )

    # FortyGuard requirements:
    # 1 = start_date + start_time
    # 2 = start_date + start_time + end_time
    # 3 = start_date only
    # 4 = start_date + end_date
    if filter_type == 1 and not start_time:
        raise ValueError(
            "start_time is required for filter_type 1."
        )

    if filter_type == 2:
        if not start_time:
            raise ValueError(
                "start_time is required for filter_type 2."
            )
        if not end_time:
            raise ValueError(
                "end_time is required for filter_type 2."
            )

    if filter_type == 4 and not end_date:
        raise ValueError(
            "end_date is required for filter_type 4."
        )

    if analytic_type not in VALID_HEATMAP_ANALYTIC_TYPES:
        raise ValueError(
            "Invalid heatmap analytic_type."
        )

    if analytic_type in {"exceedance", "persistence"}:
        if threshold is None:
            raise ValueError(
                "threshold is required for "
                "exceedance/persistence."
            )

        if direction not in {"above", "below"}:
            raise ValueError(
                "direction must be 'above' or 'below'."
            )

    date_time: dict[str, Any] = {
        "start_date": start_date,
        "filter_type": filter_type,
    }

    if start_time is not None:
        date_time["start_time"] = start_time

    if end_time is not None:
        date_time["end_time"] = end_time

    if end_date is not None:
        date_time["end_date"] = end_date

    payload: dict[str, Any] = {
        "polygon_aoi": polygon_aoi,
        "date_time": date_time,
        "granularity": granularity,
        "analytic_type": analytic_type,
    }

    if threshold is not None:
        payload["threshold"] = threshold

    if analytic_type in {"exceedance", "persistence"}:
        payload["direction"] = direction

    try:
        response = requests.post(
            _url("/v1/heatmap"),
            headers=_headers(),
            json=payload,
            timeout=DEFAULT_REQUEST_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise FortyGuardError(
            f"FortyGuard heatmap request failed: {exc}"
        ) from exc

    return _validate_api_response(
        response,
        "FortyGuard heatmap request",
    )


def request_environmental_parameters(
    latitude: float,
    longitude: float,
    temperature_c: float,
    start_date: str,
    filter_type: int = 1,
    start_time: str | None = None,
    end_time: str | None = None,
    analysis: list[str] | None = None,
) -> dict[str, Any]:
    """
    Submit an Environmental Parameters analysis.
    """
    _validate_coordinates(latitude, longitude)
    _validate_temperature_c(temperature_c)

    if filter_type not in VALID_ENV_FILTER_TYPES:
        raise ValueError(
            "Environmental Parameters filter_type "
            "must be 1, 2, or 3."
        )

    if not start_date.strip():
        raise ValueError(
            "start_date cannot be empty."
        )

    if filter_type == 1 and not start_time:
        raise ValueError(
            "start_time is required for filter_type 1."
        )

    if filter_type == 2:
        if not start_time:
            raise ValueError(
                "start_time is required for filter_type 2."
            )
        if not end_time:
            raise ValueError(
                "end_time is required for filter_type 2."
            )

    date_time: dict[str, Any] = {
        "start_date": start_date,
        "filter_type": filter_type,
    }

    if start_time is not None:
        date_time["start_time"] = start_time

    if end_time is not None:
        date_time["end_time"] = end_time

    payload: dict[str, Any] = {
        "latitude": latitude,
        "longitude": longitude,
        "temperature": temperature_c,
        "date_time": date_time,
    }

    if analysis:
        payload["analysis"] = analysis

    try:
        response = requests.post(
            _url("/v1/env_params"),
            headers=_headers(),
            json=payload,
            timeout=DEFAULT_REQUEST_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise FortyGuardError(
            f"FortyGuard Environmental Parameters request "
            f"failed: {exc}"
        ) from exc

    return _validate_api_response(
        response,
        "FortyGuard Environmental Parameters request",
    )


def request_heat_intelligence(
    latitude: float,
    longitude: float,
    temperature_f: float,
    date: str,
    analysis: list[str] | None = None,
) -> dict[str, Any]:
    """
    Submit a FortyGuard Heat Intelligence analysis.

    Temperature must be provided in Fahrenheit.
    """
    _validate_coordinates(latitude, longitude)

    if not date.strip():
        raise ValueError(
            "date cannot be empty."
        )

    if analysis is None:
        analysis = [
            "geographic",
            "environmental",
            "urban",
            "events",
            "anthropogenic",
        ]
    else:
        invalid = (
            set(analysis)
            - VALID_HEAT_INTELLIGENCE_ANALYSES
        )

        if invalid:
            raise ValueError(
                "Invalid Heat Intelligence analysis option(s): "
                + ", ".join(sorted(invalid))
            )

    payload = {
        "latitude": latitude,
        "longitude": longitude,
        "temperature": temperature_f,
        "date": date,
        "analysis": analysis,
    }

    try:
        response = requests.post(
            _url("/v1/heat_intelligence"),
            headers=_headers(),
            json=payload,
            timeout=DEFAULT_REQUEST_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise FortyGuardError(
            f"FortyGuard Heat Intelligence request "
            f"failed: {exc}"
        ) from exc

    return _validate_api_response(
        response,
        "FortyGuard Heat Intelligence request",
    )


def wait_for_activity(
    activity_id: str,
    poll_interval: int = DEFAULT_POLL_INTERVAL_SECONDS,
    max_attempts: int = DEFAULT_MAX_POLL_ATTEMPTS,
) -> dict[str, Any]:
    """
    Poll a FortyGuard activity until it completes or fails.

    FortyGuard may temporarily return 404 immediately after
    an activity is submitted. In that case, retry rather than
    treating the activity as permanently failed.
    """
    if not activity_id.strip():
        raise ValueError(
            "activity_id cannot be empty."
        )

    if poll_interval <= 0:
        raise ValueError(
            "poll_interval must be greater than zero."
        )

    if max_attempts <= 0:
        raise ValueError(
            "max_attempts must be greater than zero."
        )

    last_error: Exception | None = None

    for _ in range(max_attempts):
        try:
            result = get_status(activity_id)

            data = result.get("data") or {}
            status = str(
                data.get("status", "")
            ).lower()

            if status in {
                "completed",
                "succeeded",
            }:
                return result

            if status in {
                "failed",
                "error",
            }:
                raise FortyGuardError(
                    f"FortyGuard activity failed: {activity_id}"
                )

            last_error = None

        except FortyGuardError as exc:
            last_error = exc

            # FortyGuard documents that an activity can
            # temporarily return 404 immediately after submission.
            if "404" not in str(exc):
                raise

        time.sleep(poll_interval)

    if last_error is not None:
        raise FortyGuardError(
            f"FortyGuard activity {activity_id} "
            f"remained unavailable after "
            f"{poll_interval * max_attempts} seconds: "
            f"{last_error}"
        )

    raise TimeoutError(
        f"FortyGuard activity {activity_id} "
        f"did not complete within "
        f"{poll_interval * max_attempts} seconds."
    )

def extract_activity_id(
    submission_response: dict[str, Any],
) -> str:
    """
    Extract activity_id from a successful submission.
    """
    data = submission_response.get("data") or {}
    activity_id = data.get("activity_id")

    if not isinstance(activity_id, str):
        raise FortyGuardError(
            "FortyGuard submission did not return "
            "a valid activity_id."
        )

    if not activity_id.strip():
        raise FortyGuardError(
            "FortyGuard submission returned an empty activity_id."
        )

    return activity_id


def get_completed_heatmap(
    activity_id: str,
    poll_interval: int = DEFAULT_POLL_INTERVAL_SECONDS,
    max_attempts: int = DEFAULT_MAX_POLL_ATTEMPTS,
) -> dict[str, Any]:
    """
    Wait for a heatmap task and validate its completed result.
    """
    completed = wait_for_activity(
        activity_id=activity_id,
        poll_interval=poll_interval,
        max_attempts=max_attempts,
    )

    data = completed.get("data") or {}
    result = data.get("result")

    if not isinstance(result, dict):
        raise FortyGuardError(
            "Completed heatmap response did not contain "
            "a valid result object."
        )

    if "map_data" not in result:
        raise FortyGuardCoverageError(
            "FortyGuard did not return heatmap data "
            "for the requested route area."
        )

    map_data = result.get("map_data")
    if not isinstance(map_data, dict):
        raise FortyGuardCoverageError(
            "FortyGuard returned invalid heatmap data "
            "for the requested route area."
        )

    features = map_data.get("features")
    if not isinstance(features, list) or not features:
        raise FortyGuardCoverageError(
            "FortyGuard has no usable heatmap data "
            "for the requested route area."
        )

    return completed


def get_completed_environmental_parameters(
    activity_id: str,
    poll_interval: int = DEFAULT_POLL_INTERVAL_SECONDS,
    max_attempts: int = DEFAULT_MAX_POLL_ATTEMPTS,
) -> dict[str, Any]:
    """
    Wait for Environmental Parameters to complete.
    """
    return wait_for_activity(
        activity_id=activity_id,
        poll_interval=poll_interval,
        max_attempts=max_attempts,
    )


def get_completed_heat_intelligence(
    activity_id: str,
    poll_interval: int = DEFAULT_POLL_INTERVAL_SECONDS,
    max_attempts: int = DEFAULT_MAX_POLL_ATTEMPTS,
) -> dict[str, Any]:
    """
    Wait for Heat Intelligence to complete.
    """
    completed = wait_for_activity(
        activity_id=activity_id,
        poll_interval=poll_interval,
        max_attempts=max_attempts,
    )

    data = completed.get("data") or {}
    result = data.get("result") or {}
    download_link = result.get("download_link")

    if not isinstance(download_link, str):
        raise FortyGuardError(
            "Completed Heat Intelligence response did not "
            "contain a valid download_link."
        )

    if not download_link.strip():
        raise FortyGuardError(
            "Completed Heat Intelligence response did not "
            "contain a valid download_link."
        )

    return completed


def download_heat_intelligence_report(
    activity_id: str,
    output_path: str | Path,
) -> Path:
    """
    Download a completed Heat Intelligence PDF report.
    """
    completed = get_completed_heat_intelligence(
        activity_id=activity_id,
    )

    data = completed.get("data") or {}
    result = data.get("result") or {}
    download_link = result.get("download_link")

    try:
        response = requests.get(
            download_link,
            timeout=DEFAULT_REQUEST_TIMEOUT_SECONDS,
        )
    except requests.RequestException as exc:
        raise FortyGuardError(
            "Heat Intelligence report download failed."
        ) from exc

    if not response.ok:
        raise FortyGuardError(
            "Heat Intelligence report download failed "
            f"({response.status_code})."
        )

    output = Path(output_path)
    output.parent.mkdir(
        parents=True,
        exist_ok=True,
    )
    output.write_bytes(response.content)

    return output


def build_route_aoi(
    points: list[dict[str, float]],
    padding_degrees: float = 0.002,
) -> dict[str, Any]:
    """
    Build a closed GeoJSON FeatureCollection around a route.

    GeoJSON coordinate order is:
        [longitude, latitude]
    """
    if len(points) < 2:
        raise ValueError(
            "At least two route points are required."
        )

    if padding_degrees <= 0:
        raise ValueError(
            "padding_degrees must be greater than zero."
        )

    latitudes: list[float] = []
    longitudes: list[float] = []

    for point in points:
        if "latitude" not in point:
            raise ValueError(
                "Route point is missing latitude."
            )

        if "longitude" not in point:
            raise ValueError(
                "Route point is missing longitude."
            )

        latitude = float(point["latitude"])
        longitude = float(point["longitude"])

        _validate_coordinates(
            latitude=latitude,
            longitude=longitude,
        )

        latitudes.append(latitude)
        longitudes.append(longitude)

    min_lat = min(latitudes) - padding_degrees
    max_lat = max(latitudes) + padding_degrees
    min_lon = min(longitudes) - padding_degrees
    max_lon = max(longitudes) + padding_degrees

    coordinates = [[
        [min_lon, min_lat],
        [max_lon, min_lat],
        [max_lon, max_lat],
        [min_lon, max_lat],
        [min_lon, min_lat],
    ]]

    return {
        "type": "FeatureCollection",
        "features": [
            {
                "type": "Feature",
                "properties": {},
                "geometry": {
                    "type": "Polygon",
                    "coordinates": coordinates,
                },
            }
        ],
    }


def request_route_heatmap(
    route_points: list[dict[str, float]],
    start_date: str,
    start_time: str,
    granularity: int = 100,
) -> dict[str, Any]:
    """
    Submit a FortyGuard temperature heatmap for a route.

    Uses analytic_type='tcm', which returns
    temperature values in degrees Celsius.
    """
    if not start_time.strip():
        raise ValueError(
            "start_time cannot be empty."
        )

    polygon_aoi = build_route_aoi(
        points=route_points,
    )

    return request_heatmap(
        polygon_aoi=polygon_aoi,
        start_date=start_date,
        start_time=start_time,
        filter_type=1,
        granularity=granularity,
        analytic_type="tcm",
    )
def get_route_heatmap_map_data(
    route_points: list[dict[str, float]],
    start_date: str,
    start_time: str,
    granularity: int = 100,
    cache_ttl_seconds: int | None = None,
) -> dict[str, Any]:
    """
    Return completed FortyGuard route heatmap map_data with a small
    in-process TTL cache. Only successful heatmaps are cached.

    The cache key includes the route geometry, date, time, and granularity,
    so climate data is never reused for a different request.
    """
    if not start_date.strip():
        raise ValueError("start_date cannot be empty.")
    if not start_time.strip():
        raise ValueError("start_time cannot be empty.")
    if not route_points:
        raise ValueError("route_points cannot be empty.")

    ttl = (
        DEFAULT_HEATMAP_CACHE_TTL_SECONDS
        if cache_ttl_seconds is None
        else cache_ttl_seconds
    )
    if ttl < 0:
        raise ValueError("cache_ttl_seconds cannot be negative.")

    polygon_aoi = build_route_aoi(route_points)

    cache_payload = {
        "polygon_aoi": polygon_aoi,
        "start_date": start_date,
        "start_time": start_time,
        "granularity": granularity,
        "analytic_type": "tcm",
        "filter_type": 1,
    }
    cache_key = hashlib.sha256(
        json.dumps(
            cache_payload,
            sort_keys=True,
            separators=(",", ":"),
        ).encode("utf-8")
    ).hexdigest()

    now = time.monotonic()

    if ttl > 0:
        with _HEATMAP_CACHE_LOCK:
            cached = _HEATMAP_CACHE.get(cache_key)
            if cached is not None:
                cached_at, cached_map_data = cached
                if now - cached_at < ttl:
                    return cached_map_data
                _HEATMAP_CACHE.pop(cache_key, None)

    submission = request_heatmap(
        polygon_aoi=polygon_aoi,
        start_date=start_date,
        start_time=start_time,
        filter_type=1,
        granularity=granularity,
        analytic_type="tcm",
    )

    activity_id = extract_activity_id(submission)
    completed = get_completed_heatmap(
        activity_id=activity_id,
        poll_interval=DEFAULT_POLL_INTERVAL_SECONDS,
        max_attempts=24,
    )

    result = completed.get("data", {}).get("result", {})
    map_data = result.get("map_data")

    if not isinstance(map_data, dict):
        raise FortyGuardCoverageError(
            "FortyGuard returned invalid heatmap data "
            "for the requested route area."
        )

    features = map_data.get("features")
    if not isinstance(features, list) or not features:
        raise FortyGuardCoverageError(
            "FortyGuard has no usable heatmap data "
            "for the requested route area."
        )

    if ttl > 0:
        with _HEATMAP_CACHE_LOCK:
            _HEATMAP_CACHE[cache_key] = (
                time.monotonic(),
                map_data,
            )

    return map_data


def _point_in_polygon(
    longitude: float,
    latitude: float,
    polygon: list[list[float]],
) -> bool:
    """
    Check whether a longitude/latitude point is inside
    a GeoJSON polygon using the ray-casting algorithm.

    Polygon coordinates are [longitude, latitude].
    """
    inside = False

    if len(polygon) < 3:
        return False

    j = len(polygon) - 1

    for i in range(len(polygon)):
        xi, yi = polygon[i][0], polygon[i][1]
        xj, yj = polygon[j][0], polygon[j][1]

        intersects = (
            ((yi > latitude) != (yj > latitude))
            and (
                longitude
                < (xj - xi)
                * (latitude - yi)
                / ((yj - yi) or 1e-15)
                + xi
            )
        )

        if intersects:
            inside = not inside

        j = i

    return inside


def _point_in_geometry(
    longitude: float,
    latitude: float,
    geometry: dict[str, Any],
) -> bool:
    """
    Check whether a point is inside a GeoJSON Polygon
    or MultiPolygon geometry.
    """
    geometry_type = geometry.get("type")
    coordinates = geometry.get("coordinates")

    if geometry_type == "Polygon":
        if not coordinates:
            return False

        outer_ring = coordinates[0]

        return _point_in_polygon(
            longitude=longitude,
            latitude=latitude,
            polygon=outer_ring,
        )

    if geometry_type == "MultiPolygon":
        if not coordinates:
            return False

        for polygon in coordinates:
            if not polygon:
                continue

            outer_ring = polygon[0]

            if _point_in_polygon(
                longitude=longitude,
                latitude=latitude,
                polygon=outer_ring,
            ):
                return True

    return False


def find_heatmap_temperature(
    longitude: float,
    latitude: float,
    map_data: dict[str, Any],
) -> dict[str, Any]:
    """
    Find the FortyGuard heatmap tile containing a point.

    If the point falls exactly on/outside a polygon boundary,
    fall back to the nearest heatmap tile. This prevents tiny
    geometric boundary errors from invalidating an otherwise
    valid route.
    """
    features = map_data.get("features", [])

    if not isinstance(features, list) or not features:
        raise FortyGuardCoverageError(
            "FortyGuard has no usable heatmap data "
            "for the requested location."
        )

    def tile_temperature(
        properties: dict[str, Any],
        match_method: str,
    ) -> dict[str, Any]:
        temperature = properties.get(
            "average_temperature"
        )

        if temperature is None:
            temperature = properties.get(
                "max_temperature"
            )

        if temperature is None:
            raise FortyGuardError(
                "Heatmap tile does not contain "
                "a temperature value."
            )

        return {
            "tile_id": properties.get("tile_id"),
            "temperature_c": float(temperature),
            "min_temperature_c": (
                float(properties["min_temperature"])
                if properties.get("min_temperature") is not None
                else None
            ),
            "max_temperature_c": (
                float(properties["max_temperature"])
                if properties.get("max_temperature") is not None
                else None
            ),
            "source": "fortyguard_heatmap",
            "match_method": match_method,
        }

    # ---------------------------------------------------------
    # 1. Exact polygon containment
    # ---------------------------------------------------------
    for feature in features:
        geometry = feature.get("geometry") or {}
        properties = feature.get("properties") or {}

        if _point_in_geometry(
            longitude=longitude,
            latitude=latitude,
            geometry=geometry,
        ):
            return tile_temperature(
                properties=properties,
                match_method="polygon",
            )

    # ---------------------------------------------------------
    # 2. Boundary-safe nearest tile fallback
    # ---------------------------------------------------------
    nearest_feature = None
    nearest_distance = None

    for feature in features:
        geometry = feature.get("geometry") or {}
        coordinates = geometry.get("coordinates")

        if not coordinates:
            continue

        geometry_type = geometry.get("type")

        rings = []

        if geometry_type == "Polygon":
            if coordinates:
                rings.append(coordinates[0])

        elif geometry_type == "MultiPolygon":
            for polygon in coordinates:
                if polygon:
                    rings.append(polygon[0])

        for ring in rings:
            if not ring:
                continue

            # Approximate tile centroid from the outer ring.
            center_lon = sum(
                point[0] for point in ring
            ) / len(ring)

            center_lat = sum(
                point[1] for point in ring
            ) / len(ring)

            distance_sq = (
                (longitude - center_lon) ** 2
                + (latitude - center_lat) ** 2
            )

            if (
                nearest_distance is None
                or distance_sq < nearest_distance
            ):
                nearest_distance = distance_sq
                nearest_feature = feature

    if nearest_feature is None:
        raise FortyGuardCoverageError(
            "FortyGuard has no usable heatmap tiles "
            "for the requested location."
        )

    properties = (
        nearest_feature.get("properties") or {}
    )

    # Refuse obviously unrelated points.
    # ~0.01 degrees is roughly around 1 km depending
    # on latitude, so this is only a boundary safety net.
    max_distance_sq = 0.01 ** 2

    if (
        nearest_distance is None
        or nearest_distance > max_distance_sq
    ):
        raise FortyGuardCoverageError(
            "Point is outside the usable FortyGuard "
            "heatmap coverage: "
            f"latitude={latitude}, "
            f"longitude={longitude}."
        )

    return tile_temperature(
        properties=properties,
        match_method="nearest_tile",
    )
def build_segment_climate_readings(
    segments: list[Any],
    map_data: dict[str, Any],
    timestamp: str,
) -> list["ClimateReading"]:
    """
    Match each RouteSegment to a FortyGuard heatmap tile and
    convert the result into the normalized ClimateReading model.
    """
    from ..models.climate_models import ClimateReading

    if not segments:
        raise ValueError(
            "At least one route segment is required."
        )

    if not timestamp.strip():
        raise ValueError(
            "timestamp cannot be empty."
        )

    try:
        reading_time = datetime.fromisoformat(
            timestamp.replace("Z", "+00:00")
        )
    except ValueError as exc:
        raise ValueError(
            "timestamp must be a valid ISO 8601 datetime."
        ) from exc

    readings: list[ClimateReading] = []

    for segment in segments:
        latitude = (
            segment.origin.latitude
            + segment.destination.latitude
        ) / 2.0

        longitude = (
            segment.origin.longitude
            + segment.destination.longitude
        ) / 2.0

        climate = find_heatmap_temperature(
            longitude=longitude,
            latitude=latitude,
            map_data=map_data,
        )

        readings.append(
            ClimateReading(
                latitude=latitude,
                longitude=longitude,
                timestamp=reading_time,
                temperature_c=climate["temperature_c"],
                source=climate["source"],
                environmental_data={
                    "fortyguard_tile_id": climate["tile_id"],
                    "min_temperature_c": (
                        climate["min_temperature_c"]
                    ),
                    "max_temperature_c": (
                        climate["max_temperature_c"]
                    ),
                },
            )
        )

    return readings