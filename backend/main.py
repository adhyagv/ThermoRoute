from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel

from backend.services.optimizer import optimize_journey_with_options


# ============================================================
# THERMOROUTE API
# ============================================================

app = FastAPI(
    title="ThermoRoute API",
    description="Heat-aware route optimization API",
    version="1.0.0",
)


# ============================================================
# CORS
# Allows Flutter Web to communicate with FastAPI
# ============================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)


# ============================================================
# REQUEST MODEL
# ============================================================

class JourneyRequest(BaseModel):
    from_location: str
    destination: str
    departure_time: str
    max_extra_time_percent: int = 20


# ============================================================
# HEALTH CHECK
# ============================================================

@app.get("/")
def home():
    return {
        "message": "ThermoRoute API is running",
        "status": "success",
    }


# ============================================================
# OPTIMIZE ROUTE
# ============================================================

@app.post("/api/optimize")
def optimize_route(request: JourneyRequest):

    # ========================================================
    # DEMO ROUTE SCENARIOS
    #
    # These will later be replaced with:
    # - real routing data
    # - FortyGuard heat data
    # - real climate information
    # ========================================================

    scenarios = [

        # ----------------------------------------------------
        # ROUTE A
        # Fastest valid route
        # ----------------------------------------------------

        {
            "route": "Route A",
            "departure_time": request.departure_time,
            "travel_time_min": 20,
            "distance_km": 2.4,

            "segments": [
                {
                    "temperature": 36,
                    "duration_minutes": 6,
                },
                {
                    "temperature": 38,
                    "duration_minutes": 8,
                },
                {
                    "temperature": 35,
                    "duration_minutes": 6,
                },
            ],
        },

        # ----------------------------------------------------
        # ROUTE B
        # Recommended route
        # ----------------------------------------------------

        {
            "route": "Route B",
            "departure_time": request.departure_time,
            "travel_time_min": 23,
            "distance_km": 2.7,

            "segments": [
                {
                    "temperature": 32,
                    "duration_minutes": 8,
                },
                {
                    "temperature": 33,
                    "duration_minutes": 9,
                },
                {
                    "temperature": 31,
                    "duration_minutes": 6,
                },
            ],
        },

        # ----------------------------------------------------
        # ROUTE C
        # Lower thermal exposure but too slow
        #
        # This is important for the demo because it shows
        # that ThermoRoute does not simply choose the route
        # with the lowest exposure.
        # ----------------------------------------------------

        {
            "route": "Route C",
            "departure_time": request.departure_time,
            "travel_time_min": 25,
            "distance_km": 3.1,

            "segments": [
                {
                    "temperature": 30,
                    "duration_minutes": 8,
                },
                {
                    "temperature": 31,
                    "duration_minutes": 9,
                },
                {
                    "temperature": 30,
                    "duration_minutes": 8,
                },
            ],
        },
    ]


    # ========================================================
    # FASTEST AVAILABLE ROUTE
    # ========================================================

    fastest_time = min(
        scenario["travel_time_min"]
        for scenario in scenarios
    )


    # ========================================================
    # THERMAL EXPOSURE BUDGET
    # ========================================================

    thermal_exposure_budget = 50


    # ========================================================
    # RUN OPTIMIZATION
    #
    # IMPORTANT:
    # optimize_journey_with_options returns:
    #
    # 1. recommended route
    # 2. all evaluated routes
    # 3. constraint information
    # ========================================================

    result = optimize_journey_with_options(
        scenarios=scenarios,
        fastest_time=fastest_time,
        max_extra_time_percent=request.max_extra_time_percent,
        thermal_exposure_budget=thermal_exposure_budget,
    )


    # ========================================================
    # API RESPONSE
    # ========================================================

    return {
        "status": "success",

        "from": request.from_location,

        "destination": request.destination,

        "departure_time": request.departure_time,

        "fastest_time": fastest_time,

        "max_extra_time_percent": (
            request.max_extra_time_percent
        ),

        "max_allowed_time": (
            result["constraints"]["max_allowed_time_min"]
        ),

        "thermal_exposure_budget": (
            result["constraints"]["thermal_exposure_budget"]
        ),

        # Recommended route
        "recommendation": result["recommended"],

        # ALL routes
        "options": result["options"],

        # Optimization constraints
        "constraints": result["constraints"],
    }