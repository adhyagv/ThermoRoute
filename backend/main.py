from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel


from backend.services.optimizer import optimize_journey

from backend.services.routing import (
    build_route_scenarios,
    create_demo_routes,
)

from backend.services.fortyguard import (
    FortyGuardClient,
    FortyGuardError,
)


# =========================================================
# APP
# =========================================================

app = FastAPI(
    title="ThermoRoute API",
    description=(
        "Heat-aware route and departure-time "
        "optimization powered by FortyGuard."
    ),
    version="3.0.0",
)


# =========================================================
# CORS
# =========================================================

# =========================================================
# CORS
# =========================================================

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)
# =========================================================
# FORTYGUARD
# =========================================================

fortyguard = FortyGuardClient()


# =========================================================
# REQUEST MODELS
# =========================================================

class JourneyRequest(BaseModel):
    from_location: str
    destination: str
    departure_time: str
    max_extra_time_percent: int = 20
    thermal_exposure_budget: float = 50


class HeatRequest(BaseModel):
    latitude: float
    longitude: float
    temperature: float
    date: str
    start_time: str = "14:00"


# =========================================================
# HOME
# =========================================================

@app.get("/")
def home():
    return {
        "message": "ThermoRoute API is running",
        "status": "success",
        "version": "3.0.0",
        "fortyguard": True,
        "routing": "Demo Arizona Routes",
    }


# =========================================================
# HEALTH
# =========================================================

@app.get("/api/health")
def health():
    return {
        "status": "healthy",
        "service": "ThermoRoute API",
        "fortyguard": True,
    }


# =========================================================
# FORTYGUARD ENVIRONMENT
# =========================================================

@app.post("/api/fortyguard/environment")
def environmental_parameters(request: HeatRequest):

    try:

        result = fortyguard.get_environmental_parameters(
            latitude=request.latitude,
            longitude=request.longitude,
            temperature=request.temperature,
            start_date=request.date,
            start_time=request.start_time,
            analysis=[
                "heat_index_celsius",
                "apparent_temperature_celsius",
                "relative_humidity_percent",
            ],
        )

        return {
            "status": "success",
            "data": result,
        }

    except FortyGuardError as error:

        return {
            "status": "error",
            "message": str(error),
        }

    except Exception as error:

        return {
            "status": "error",
            "message": f"Unexpected error: {error}",
        }


# =========================================================
# FORTYGUARD STATUS
# =========================================================

@app.get("/api/fortyguard/status/{activity_id}")
def fortyguard_status(activity_id: str):

    try:

        result = fortyguard.get_status(
            activity_id
        )

        return {
            "status": "success",
            "data": result,
        }

    except FortyGuardError as error:

        return {
            "status": "error",
            "message": str(error),
        }

    except Exception as error:

        return {
            "status": "error",
            "message": f"Unexpected error: {error}",
        }


# =========================================================
# ROUTE OPTIMIZATION
# =========================================================

@app.post("/api/optimize")
def optimize_route(request: JourneyRequest):

    try:

        print()
        print("=" * 60)
        print("THERMOROUTE OPTIMIZATION STARTED")
        print("=" * 60)

        print(
            f"From: {request.from_location}"
        )

        print(
            f"Destination: {request.destination}"
        )

        print(
            f"Departure: {request.departure_time}"
        )

        print(
            f"Extra time allowed: "
            f"{request.max_extra_time_percent}%"
        )

        print(
            f"Thermal budget: "
            f"{request.thermal_exposure_budget}"
        )

        # -------------------------------------------------
        # BUILD ROUTES
        # -------------------------------------------------

        scenarios = build_route_scenarios(
            from_location=request.from_location,
            destination=request.destination,
            departure_time=request.departure_time,
        )

        print(
            f"Routes generated: {len(scenarios)}"
        )

        # -------------------------------------------------
        # CHECK ROUTES
        # -------------------------------------------------

        if not scenarios:

            return {
                "status": "error",
                "message": "No routes available.",
            }

        # -------------------------------------------------
        # FIND FASTEST ROUTE
        # -------------------------------------------------

        fastest_time = min(
            scenario.get(
                "travel_time_min",
                0,
            )
            for scenario in scenarios
        )

        print(
            f"Fastest route: "
            f"{fastest_time} minutes"
        )

        # -------------------------------------------------
        # OPTIMIZE
        # -------------------------------------------------

        result = optimize_journey(
            scenarios=scenarios,
            fastest_time=fastest_time,
            max_extra_time_percent=(
                request.max_extra_time_percent
            ),
            thermal_exposure_budget=(
                request.thermal_exposure_budget
            ),
        )

        print(
            "Optimization completed."
        )

        # -------------------------------------------------
        # RETURN RESULT
        # -------------------------------------------------

        response = {
            "status": "success",

            "from": request.from_location,

            "destination": request.destination,

            "departure_time": request.departure_time,

            "max_extra_time_percent": (
                request.max_extra_time_percent
            ),

            "thermal_exposure_budget": (
                request.thermal_exposure_budget
            ),

            "fastest_time": fastest_time,

            "routes_evaluated": len(scenarios),

            "recommendation": result,
        }

        print(
            "THERMOROUTE OPTIMIZATION FINISHED"
        )

        print("=" * 60)

        return response

    except FortyGuardError as error:

        print(
            "FORTYGUARD ERROR:",
            repr(error),
        )

        return {
            "status": "error",
            "message": (
                "FortyGuard environmental "
                f"analysis failed: {error}"
            ),
        }

    except Exception as error:

        print(
            "OPTIMIZATION ERROR:",
            repr(error),
        )

        return {
            "status": "error",
            "message": f"Unexpected error: {error}",
        }


# =========================================================
# TEST ROUTES
# =========================================================

@app.get("/api/routes")
def get_test_routes():

    try:

        routes = create_demo_routes(
            origin="Phoenix, Arizona",
            destination="Tempe, Arizona",
            departure_time="10:00",
        )

        return {
            "status": "success",
            "origin": "Phoenix, Arizona",
            "destination": "Tempe, Arizona",
            "routes": routes,
        }

    except Exception as error:

        return {
            "status": "error",
            "message": f"Unexpected error: {error}",
        }