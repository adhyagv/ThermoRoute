from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from backend.services.optimizer import optimize_journey_with_options
from backend.services.temperature_provider import get_temperature_for_segment

app = FastAPI(
    title="ThermoRoute API",
    description="Heat-aware route optimization API",
    version="1.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


@app.get("/")
def home():
    return {
        "message": "ThermoRoute API is running",
        "status": "success",
    }


@app.get("/health")
def health():
    return {
        "status": "healthy",
        "service": "ThermoRoute API",
        "optimizer": "available",
        "thermal_engine": "available",
    }


class JourneyRequest(BaseModel):
    from_location: str
    destination: str
    departure_time: str
    max_extra_time_percent: int = 20


@app.post("/api/optimize")
def optimize_route(request: JourneyRequest):
    # ========================================================
    # PHOENIX, ARIZONA HACKATHON DEMO
    # Downtown Phoenix -> Phoenix Sky Harbor
    #
    # Route A = fastest but hotter
    # Route B = slightly slower and cooler -> recommended
    # Route C = hottest and outside the time limit
    # ========================================================

    scenarios = [
        {
            "route": "Route A",
            "departure_time": request.departure_time,
            "travel_time_min": 20,
            "distance_km": 8.4,
            "segments": [
                {
                    "latitude": 33.4484,
                    "longitude": -112.0740,
                    "temperature": 43,
                    "duration_minutes": 7,
                },
                {
                    "latitude": 33.4415,
                    "longitude": -112.0540,
                    "temperature": 45,
                    "duration_minutes": 7,
                },
                {
                    "latitude": 33.4342,
                    "longitude": -112.0116,
                    "temperature": 42,
                    "duration_minutes": 6,
                },
            ],
        },
        {
            "route": "Route B",
            "departure_time": request.departure_time,
            "travel_time_min": 23,
            "distance_km": 9.1,
            "segments": [
                {
                    "latitude": 33.4484,
                    "longitude": -112.0740,
                    "temperature": 38,
                    "duration_minutes": 8,
                },
                {
                    "latitude": 33.4380,
                    "longitude": -112.0600,
                    "temperature": 39,
                    "duration_minutes": 8,
                },
                {
                    "latitude": 33.4342,
                    "longitude": -112.0116,
                    "temperature": 37,
                    "duration_minutes": 7,
                },
            ],
        },
        {
            "route": "Route C",
            "departure_time": request.departure_time,
            "travel_time_min": 26,
            "distance_km": 10.0,
            "segments": [
                {
                    "latitude": 33.4484,
                    "longitude": -112.0740,
                    "temperature": 47,
                    "duration_minutes": 9,
                },
                {
                    "latitude": 33.4390,
                    "longitude": -112.0480,
                    "temperature": 49,
                    "duration_minutes": 9,
                },
                {
                    "latitude": 33.4342,
                    "longitude": -112.0116,
                    "temperature": 48,
                    "duration_minutes": 8,
                },
            ],
        },
    ]

    temperature_sources = set()

    for scenario in scenarios:
        for segment in scenario["segments"]:
            temperature_result = get_temperature_for_segment(
                latitude=segment["latitude"],
                longitude=segment["longitude"],
                fallback_temperature=segment["temperature"],
            )

            segment["temperature"] = temperature_result["temperature"]
            segment["temperature_source"] = temperature_result["source"]
            temperature_sources.add(temperature_result["source"])

    fastest_time = min(
        scenario["travel_time_min"] for scenario in scenarios
    )

    thermal_exposure_budget = 50

    result = optimize_journey_with_options(
        scenarios=scenarios,
        fastest_time=fastest_time,
        max_extra_time_percent=request.max_extra_time_percent,
        thermal_exposure_budget=thermal_exposure_budget,
    )

    return {
        "status": "success",
        "from": request.from_location,
        "destination": request.destination,
        "departure_time": request.departure_time,
        "temperature_source": list(temperature_sources),
        "fastest_time": fastest_time,
        "max_extra_time_percent": request.max_extra_time_percent,
        "max_allowed_time": result["constraints"]["max_allowed_time_min"],
        "thermal_exposure_budget": result["constraints"]["thermal_exposure_budget"],
        "recommendation": result["recommended"],
        "options": result["options"],
        "constraints": result["constraints"],
    }
