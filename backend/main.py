import json
import logging
import os
import requests
from datetime import datetime, timezone
from pathlib import Path

from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

from .models.climate_models import ClimateReading
from .models.route_models import RoutePoint, Route

from .services.climate_features import (
    build_route_climate_features,
)

from .services.fortiguard import (
    FortyGuardError,
    FortyGuardCoverageError,
    build_segment_climate_readings,
    get_route_heatmap_map_data,
)

from .services.optimizer_client import optimize_routes
from .services.routing import build_route
from .services.segmentation import create_route_segments
from .utils.geo import calculate_distance_m
from .utils.validation import validate_route


logger = logging.getLogger("thermoroute")

app = FastAPI(
    title="ThermoRoute API",
    summary="Climate-aware route intelligence for safer, cooler travel.",
    description=(
        "ThermoRoute combines live OSRM driving routes, FortyGuard "
        "street-level temperature intelligence, climate-risk analysis, "
        "and route optimization to recommend the best route for the "
        "requested time and coordinates."
    ),
    version="1.2.0",
    docs_url="/docs",
    redoc_url="/redoc",
    openapi_tags=[
        {"name": "system", "description": "Health and service information."},
        {"name": "routing", "description": "Live coordinate-based route recommendations."},
        {"name": "demo", "description": "Stored demo routes for testing and presentations."},
    ],
)

# Frontend integration. In production set FRONTEND_ORIGINS to the exact
# frontend origin(s), comma-separated. Local Vite/React development is
# supported by default without opening the API to every website.
frontend_origins = [
    origin.strip()
    for origin in os.getenv(
        "FRONTEND_ORIGINS",
        "http://localhost:3000,http://localhost:5173",
    ).split(",")
    if origin.strip()
]

app.add_middleware(
    CORSMiddleware,
    allow_origins=frontend_origins,
    allow_credentials=False,
    allow_methods=["GET", "POST", "OPTIONS"],
    allow_headers=["*"],
)

# Demo endpoints remain available for testing, but are hidden from the
# production API documentation unless explicitly enabled.
SHOW_DEMO_ENDPOINTS = os.getenv(
    "SHOW_DEMO_ENDPOINTS",
    "false",
).lower() in {"1", "true", "yes"}


BASE_DIR = Path(__file__).resolve().parent
DATA_DIR = BASE_DIR / "data"

SAMPLE_ROUTES_FILE = DATA_DIR / "sample_routes.json"
SAMPLE_CLIMATE_FILE = DATA_DIR / "sample_climate.json"


class DynamicRouteRequest(BaseModel):
    """
    User-provided origin and destination for live
    climate-aware route analysis.
    """

    origin_latitude: float = Field(
        ge=-90.0,
        le=90.0,
        description="Origin latitude in decimal degrees.",
    )

    origin_longitude: float = Field(
        ge=-180.0,
        le=180.0,
        description="Origin longitude in decimal degrees.",
    )

    destination_latitude: float = Field(
        ge=-90.0,
        le=90.0,
        description="Destination latitude in decimal degrees.",
    )

    destination_longitude: float = Field(
        ge=-180.0,
        le=180.0,
        description="Destination longitude in decimal degrees.",
    )

    date: str = Field(
        description="Heatmap date in YYYY-MM-DD format.",
    )

    time: str = Field(
        default="14:00",
        description="Heatmap time in HH:MM 24-hour format.",
    )

    model_config = {
        "json_schema_extra": {
            "example": {
                "origin_latitude": 33.4484,
                "origin_longitude": -112.0740,
                "destination_latitude": 33.4650,
                "destination_longitude": -112.0600,
                "date": "2026-08-28",
                "time": "14:00",
            }
        }
    }


def load_json_file(file_path: Path):
    """
    Load JSON data from a local file.
    """
    if not file_path.exists():
        raise FileNotFoundError(
            f"Data file not found: {file_path}"
        )

    with file_path.open(
        "r",
        encoding="utf-8",
    ) as file:
        try:
            return json.load(file)
        except json.JSONDecodeError as exc:
            raise ValueError(
                f"Malformed JSON in {file_path}: {exc}"
            ) from exc


def build_demo_route(
    route_data: dict,
) -> Route:
    """
    Convert one route dataset entry into a validated
    ThermoRoute Route with segmented geometry.
    """
    points = [
        RoutePoint(
            latitude=point["latitude"],
            longitude=point["longitude"],
        )
        for point in route_data["points"]
    ]

    if len(points) < 2:
        raise ValueError(
            "A route must contain at least two points."
        )

    segment_distances = []

    for index in range(len(points) - 1):
        distance = calculate_distance_m(
            points[index],
            points[index + 1],
        )
        segment_distances.append(distance)

    total_geometry_distance = sum(
        segment_distances
    )

    if total_geometry_distance <= 0:
        raise ValueError(
            "Route geometry has zero total distance."
        )

    total_time = float(
        route_data["estimated_time_s"]
    )

    if total_time <= 0:
        raise ValueError(
            "Route travel time must be greater than zero."
        )

    segment_times = [
        (
            distance
            / total_geometry_distance
            * total_time
        )
        for distance in segment_distances
    ]

    segments = create_route_segments(
        points=points,
        distances=segment_distances,
        times=segment_times,
    )

    route = build_route(
        route_id=route_data["route_id"],
        points=points,
        distance_m=route_data["distance_m"],
        estimated_time_s=route_data[
            "estimated_time_s"
        ],
    )

    route = route.model_copy(
        update={
            "segments": segments,
        }
    )

    validate_route(route)

    return route


def get_route_data(
    route_id: str,
) -> dict:
    """
    Find one route from the local OSRM-generated
    demo route dataset.
    """
    routes = load_json_file(
        SAMPLE_ROUTES_FILE
    )

    route_data = next(
        (
            route
            for route in routes
            if route.get("route_id") == route_id
        ),
        None,
    )

    if route_data is None:
        raise HTTPException(
            status_code=404,
            detail=(
                f"Route '{route_id}' not found."
            ),
        )

    return route_data


def get_route_points_for_heatmap(
    route: Route,
) -> list[dict[str, float]]:
    """
    Reconstruct the route coordinate sequence from
    RouteSegment objects.
    """
    if not route.segments:
        raise ValueError(
            "Route contains no segments."
        )

    points: list[dict[str, float]] = []

    for segment in route.segments:
        points.append(
            {
                "latitude": segment.origin.latitude,
                "longitude": segment.origin.longitude,
            }
        )

    last_segment = route.segments[-1]

    points.append(
        {
            "latitude": (
                last_segment.destination.latitude
            ),
            "longitude": (
                last_segment.destination.longitude
            ),
        }
    )

    return points


def build_fortyguard_climate_features(
    route: Route,
    heatmap_date: str,
    heatmap_time: str,
) -> tuple[list[ClimateReading], dict]:
    """
    Run the complete live FortyGuard climate pipeline.
    """
    route_points = get_route_points_for_heatmap(
        route
    )

    map_data = get_route_heatmap_map_data(
        route_points=route_points,
        start_date=heatmap_date,
        start_time=heatmap_time,
        granularity=100,
    )

    timestamp = (
        datetime.fromisoformat(
            f"{heatmap_date}T{heatmap_time}:00"
        )
        .replace(tzinfo=timezone.utc)
        .isoformat()
    )

    readings = build_segment_climate_readings(
        segments=route.segments,
        map_data=map_data,
        timestamp=timestamp,
    )

    climate_features = (
        build_route_climate_features(
            segments=route.segments,
            readings=readings,
            baseline_c=30.0,
            anomaly_threshold_c=3.0,
            extreme_threshold_c=40.0,
            zscore_threshold=2.0,
        )
    )

    return readings, climate_features


def build_fallback_climate_features(
    route: Route,
) -> tuple[list[ClimateReading], dict]:
    """
    Use sample climate data only if live FortyGuard
    processing fails.
    """
    climate_data = load_json_file(
        SAMPLE_CLIMATE_FILE
    )

    route_climate_data = [
        reading
        for reading in climate_data
        if reading.get("route_id")
        == route.route_id
    ]

    if len(route_climate_data) != len(
        route.segments
    ):
        raise ValueError(
            "Fallback climate reading count does not "
            "match route segment count."
        )

    readings = [
        ClimateReading.model_validate(
            reading
        )
        for reading in route_climate_data
    ]

    climate_features = (
        build_route_climate_features(
            segments=route.segments,
            readings=readings,
            baseline_c=30.0,
            anomaly_threshold_c=3.0,
            extreme_threshold_c=40.0,
            zscore_threshold=2.0,
        )
    )

    return readings, climate_features


def enrich_route_with_climate(
    route: Route,
    readings: list[ClimateReading],
) -> Route:
    """
    Attach the actual ClimateReading object to
    each route segment.
    """
    if len(route.segments) != len(readings):
        raise ValueError(
            "Number of climate readings must match "
            "number of route segments."
        )

    enriched_segments = []

    for segment, reading in zip(
        route.segments,
        readings,
    ):
        enriched_segments.append(
            segment.model_copy(
                update={
                    "climate": reading,
                }
            )
        )

    return route.model_copy(
        update={
            "segments": enriched_segments,
        }
    )


def validate_datetime_inputs(
    date: str,
    time: str,
) -> None:
    """
    Validate date and time strings before sending
    them to external services.
    """
    try:
        datetime.strptime(
            date,
            "%Y-%m-%d",
        )

        datetime.strptime(
            time,
            "%H:%M",
        )

    except ValueError as exc:
        raise HTTPException(
            status_code=422,
            detail=(
                "date must use YYYY-MM-DD and "
                "time must use HH:MM."
            ),
        ) from exc


def get_dynamic_osrm_routes(
    request: DynamicRouteRequest,
) -> list[Route]:
    """
    Get live driving route alternatives from OSRM
    using user-provided coordinates.
    """
    origin = (
        request.origin_longitude,
        request.origin_latitude,
    )

    destination = (
        request.destination_longitude,
        request.destination_latitude,
    )

    if origin == destination:
        raise HTTPException(
            status_code=422,
            detail="Origin and destination must be different coordinates.",
        )

    url = (
        "https://router.project-osrm.org/"
        "route/v1/driving/"
        f"{origin[0]},{origin[1]};"
        f"{destination[0]},{destination[1]}"
    )

    params = {
        "alternatives": "true",
        "overview": "full",
        "geometries": "geojson",
        "steps": "false",
    }

    try:
        response = requests.get(
            url,
            params=params,
            headers={
                "User-Agent": "ThermoRoute/1.1",
            },
            timeout=30,
        )
        response.raise_for_status()
        data = response.json()

    except requests.RequestException as exc:
        raise HTTPException(
            status_code=502,
            detail=(
                f"OSRM routing request failed: {exc}"
            ),
        ) from exc

    if data.get("code") != "Ok":
        raise HTTPException(
            status_code=502,
            detail=(
                "OSRM could not calculate a route: "
                f"{data.get('message', data.get('code'))}"
            ),
        )

    routes = data.get("routes") or []

    if not routes:
        raise HTTPException(
            status_code=404,
            detail="No driving routes were found.",
        )

    result: list[Route] = []

    for index, route_data in enumerate(routes):
        geometry = (
            route_data.get("geometry") or {}
        )

        coordinates = (
            geometry.get("coordinates") or []
        )

        if len(coordinates) < 2:
            continue

        points = [
            RoutePoint(
                latitude=float(coordinate[1]),
                longitude=float(coordinate[0]),
            )
            for coordinate in coordinates
        ]

        segment_distances = [
            calculate_distance_m(
                points[i],
                points[i + 1],
            )
            for i in range(len(points) - 1)
        ]

        total_geometry_distance = sum(
            segment_distances
        )

        if total_geometry_distance <= 0:
            continue

        total_time = float(
            route_data["duration"]
        )

        if total_time <= 0:
            continue

        segment_times = [
            (
                distance
                / total_geometry_distance
                * total_time
            )
            for distance in segment_distances
        ]

        segments = create_route_segments(
            points=points,
            distances=segment_distances,
            times=segment_times,
        )

        route = build_route(
            route_id=(
                f"dynamic_route_{index + 1}"
            ),
            points=points,
            distance_m=float(
                route_data["distance"]
            ),
            estimated_time_s=total_time,
        )

        route = route.model_copy(
            update={
                "segments": segments,
            }
        )

        validate_route(route)

        result.append(route)

    if not result:
        raise HTTPException(
            status_code=502,
            detail=(
                "OSRM returned no usable route geometry."
            ),
        )

    return result


def analyze_live_route(route: Route, heatmap_date: str, heatmap_time: str) -> dict:
    """Run the live climate-intelligence pipeline for one route."""
    readings, climate_features = build_fortyguard_climate_features(
        route=route,
        heatmap_date=heatmap_date,
        heatmap_time=heatmap_time,
    )

    enriched_route = enrich_route_with_climate(
        route=route,
        readings=readings,
    )

    return {
        "route": enriched_route.model_dump(mode="json"),
        "climate_features": climate_features,
        "climate_source": "fortyguard_heatmap",
    }


def build_optimization_input(analysis: dict) -> dict:
    """Convert one route analysis into the optimizer contract."""
    route = analysis["route"]
    return {
        "route_id": route["route_id"],
        "estimated_time_s": route["estimated_time_s"],
        "climate_features": analysis["climate_features"],
    }


def select_recommended_route(optimization: dict, route_results: list[dict]) -> dict | None:
    """Attach the full route geometry to the optimizer recommendation."""
    recommended_route_id = optimization.get("recommended_route_id")
    return next(
        (
            item
            for item in route_results
            if item["route"]["route_id"] == recommended_route_id
        ),
        None,
    )


@app.get("/", tags=["system"], summary="API information")
def root():
    """
    Basic API information.
    """
    return {
        "name": "ThermoRoute",
        "status": "running",
        "version": app.version,
        "mode": "live",
        "routing_source": "OSRM",
        "climate_source": "FortyGuard",
        "docs": "/docs",
    }


@app.get("/health", tags=["system"], summary="Health check")
def health_check():
    """
    Lightweight backend health check.

    This does not call FortyGuard so the health check
    does not consume API credits.
    """
    return {
        "status": "healthy",
        "mode": "live",
        "services": {
            "routing": "osrm",
            "climate": "fortyguard",
            "optimization": "thermoroute",
        },
    }


@app.get("/demo/routes", tags=["demo"], summary="List demo routes", include_in_schema=SHOW_DEMO_ENDPOINTS)
def get_demo_routes():
    """
    Return the OSRM-generated routes available
    for the demo.
    """
    try:
        routes = load_json_file(
            SAMPLE_ROUTES_FILE
        )
    except (FileNotFoundError, ValueError) as exc:
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        ) from exc

    return {
        "source": "osrm_openstreetmap",
        "route_count": len(routes),
        "routes": routes,
    }


@app.get("/demo/analyze/{route_id}", tags=["demo"], summary="Analyze a demo route", include_in_schema=SHOW_DEMO_ENDPOINTS)
def analyze_demo_route(
    route_id: str,
    date: str | None = None,
    time: str = "14:00",
):
    """
    Analyze one stored demo route using live
    FortyGuard heat data.
    """
    route_data = get_route_data(
        route_id
    )

    if date is None:
        date = datetime.now(
            timezone.utc
        ).strftime("%Y-%m-%d")

    validate_datetime_inputs(
        date=date,
        time=time,
    )

    try:
        route = build_demo_route(
            route_data
        )
    except (ValueError, KeyError) as exc:
        raise HTTPException(
            status_code=422,
            detail=(
                f"Route '{route_id}' could not "
                f"be processed: {exc}"
            ),
        ) from exc

    live = True
    climate_source = "fortyguard_heatmap"

    try:
        readings, climate_features = (
            build_fortyguard_climate_features(
                route=route,
                heatmap_date=date,
                heatmap_time=time,
            )
        )

    except (
        FortyGuardError,
        TimeoutError,
        ValueError,
        KeyError,
    ) as exc:
        try:
            readings, climate_features = (
                build_fallback_climate_features(
                    route
                )
            )

            live = False
            climate_source = "sample_demo"

        except Exception as fallback_exc:
            raise HTTPException(
                status_code=502,
                detail=(
                    "Both live FortyGuard climate "
                    "processing and fallback climate "
                    "processing failed. "
                    f"Live error: {exc}. "
                    f"Fallback error: {fallback_exc}."
                ),
            ) from fallback_exc

    enriched_route = (
        enrich_route_with_climate(
            route=route,
            readings=readings,
        )
    )

    return {
        "status": "success",
        "mode": (
            "live"
            if live
            else "fallback"
        ),
        "route": enriched_route.model_dump(
            mode="json"
        ),
        "climate_source": climate_source,
        "heatmap_request": {
            "date": date,
            "time": time,
            "granularity_m": 100,
        },
        "climate_features": climate_features,
    }


@app.get("/demo/recommend", tags=["demo"], summary="Recommend from demo routes", include_in_schema=SHOW_DEMO_ENDPOINTS)
def recommend_route(
    date: str = "2026-08-28",
    time: str = "14:00",
):
    """
    Analyze all stored demo routes with live
    FortyGuard climate data and return the
    climate-aware recommendation.
    """
    validate_datetime_inputs(
        date=date,
        time=time,
    )

    try:
        routes_data = load_json_file(
            SAMPLE_ROUTES_FILE
        )
    except (FileNotFoundError, ValueError) as exc:
        raise HTTPException(
            status_code=500,
            detail=str(exc),
        ) from exc

    analyzed_routes = []
    route_results = []

    for route_data in routes_data:
        route_id = route_data.get(
            "route_id"
        )

        if not route_id:
            continue

        try:
            route = build_demo_route(
                route_data
            )

            readings, climate_features = (
                build_fortyguard_climate_features(
                    route=route,
                    heatmap_date=date,
                    heatmap_time=time,
                )
            )

            enriched_route = (
                enrich_route_with_climate(
                    route=route,
                    readings=readings,
                )
            )

            analyzed_routes.append(
                {
                    "route_id": route.route_id,
                    "estimated_time_s": (
                        route.estimated_time_s
                    ),
                    "climate_features": (
                        climate_features
                    ),
                }
            )

            route_results.append(
                {
                    "route": enriched_route.model_dump(
                        mode="json"
                    ),
                    "climate_features": (
                        climate_features
                    ),
                    "climate_source": (
                        "fortyguard_heatmap"
                    ),
                }
            )

        except FortyGuardCoverageError as exc:
            raise HTTPException(
                status_code=422,
                detail={
                    "type": "fortyguard_coverage_unavailable",
                    "message": (
                        "Live climate optimization is not "
                        "available for this location because "
                        "FortyGuard has no usable heatmap data "
                        "for the requested area."
                    ),
                    "route_id": route.route_id,
                },
            ) from exc

        except (
            FortyGuardError,
            TimeoutError,
            ValueError,
            KeyError,
        ) as exc:
            raise HTTPException(
                status_code=502,
                detail={
                    "type": "fortyguard_service_error",
                    "message": (
                        "ThermoRoute could not retrieve live "
                        "climate data from FortyGuard."
                    ),
                    "route_id": route.route_id,
                },
            ) from exc

    if not analyzed_routes:
        raise HTTPException(
            status_code=422,
            detail=(
                "No valid routes were available "
                "for optimization."
            ),
        )

    try:
        optimization = optimize_routes(
            analyzed_routes
        )
    except Exception as exc:
        logger.exception("Route optimization failed")
        raise HTTPException(
            status_code=500,
            detail="Route optimization failed. Please try again.",
        ) from exc

    recommended_route_id = (
        optimization[
            "recommended_route_id"
        ]
    )

    recommended_route = next(
        (
            item
            for item in route_results
            if item["route"]["route_id"]
            == recommended_route_id
        ),
        None,
    )

    return {
        "status": "success",
        "mode": "live",
        "climate_source": (
            "fortyguard_heatmap"
        ),
        "recommendation": optimization,
        "recommended_route": (
            recommended_route
        ),
        "analyzed_routes": route_results,
        "request": {
            "date": date,
            "time": time,
        },
    }


@app.post("/route/recommend", tags=["routing"], summary="Recommend a dynamic route", include_in_schema=False)
def recommend_dynamic_route(
    request: DynamicRouteRequest,
):
    """
    Fully dynamic ThermoRoute endpoint.

    User supplies origin and destination coordinates.
    OSRM generates route alternatives.
    FortyGuard supplies real temperature intelligence.
    ThermoRoute climate logic analyzes the routes.
    The optimizer selects the recommended route.
    """
    validate_datetime_inputs(
        date=request.date,
        time=request.time,
    )

    routes = get_dynamic_osrm_routes(
        request
    )

    analyzed_routes = []
    route_results = []

    for route in routes:
        try:
            analysis = analyze_live_route(
                route=route,
                heatmap_date=request.date,
                heatmap_time=request.time,
            )

            analyzed_routes.append(
                build_optimization_input(analysis)
            )
            route_results.append(analysis)

        except FortyGuardCoverageError as exc:
            logger.warning(
                "FortyGuard coverage unavailable for %s: %s",
                route.route_id,
                exc,
            )
            raise HTTPException(
                status_code=422,
                detail={
                    "type": "fortyguard_coverage_unavailable",
                    "message": (
                        "Live climate optimization is not "
                        "available for the requested route because "
                        "FortyGuard has no usable heatmap data "
                        "for that area."
                    ),
                    "route_id": route.route_id,
                },
            ) from exc

        except (
            FortyGuardError,
            TimeoutError,
            ValueError,
            KeyError,
        ) as exc:
            logger.exception(
                "FortyGuard analysis failed for %s",
                route.route_id,
            )
            raise HTTPException(
                status_code=502,
                detail={
                    "type": "fortyguard_service_error",
                    "message": (
                        "ThermoRoute could not retrieve live "
                        "climate data from FortyGuard."
                    ),
                    "route_id": route.route_id,
                },
            ) from exc

    if not analyzed_routes:
        raise HTTPException(
            status_code=422,
            detail=(
                "No usable routes were available "
                "for optimization."
            ),
        )

    try:
        optimization = optimize_routes(
            analyzed_routes
        )
    except Exception as exc:
        logger.exception("Route optimization failed")
        raise HTTPException(
            status_code=500,
            detail="Route optimization failed. Please try again.",
        ) from exc

    recommended_route = select_recommended_route(
        optimization,
        route_results,
    )

    return {
        "status": "success",
        "mode": "live",
        "route_source": "osrm",
        "climate_source": (
            "fortyguard_heatmap"
        ),
        "optimizer": optimization,
        "recommended_route": (
            recommended_route
        ),
        "routes": route_results,
        "request": request.model_dump(),
    }

# Clean /api aliases for frontend integration.
# Existing /demo and /route endpoints are intentionally preserved
# so current integrations do not break.
app.add_api_route(
    "/api/health",
    health_check,
    methods=["GET"],
    tags=["system"],
    summary="Health check",
    include_in_schema=True,
)
app.add_api_route(
    "/api/routes",
    get_demo_routes,
    methods=["GET"],
    tags=["demo"],
    summary="List demo routes",
    include_in_schema=SHOW_DEMO_ENDPOINTS,
)
app.add_api_route(
    "/api/analyze/{route_id}",
    analyze_demo_route,
    methods=["GET"],
    tags=["demo"],
    summary="Analyze a demo route",
    include_in_schema=SHOW_DEMO_ENDPOINTS,
)
app.add_api_route(
    "/api/optimize",
    recommend_dynamic_route,
    methods=["POST"],
    tags=["routing"],
    summary="Recommend the best route from live climate data",
    description=(
        "Provide origin/destination coordinates and a date/time. "
        "OSRM generates route alternatives, FortyGuard supplies live "
        "heatmap data, and ThermoRoute ranks the alternatives."
    ),
    response_description="Live climate-aware route recommendation.",
    include_in_schema=True,
)

