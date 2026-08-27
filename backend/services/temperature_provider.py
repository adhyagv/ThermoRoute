from datetime import datetime

from .fortyguard import FortyGuardClient


# ============================================================
# FORTYGUARD CLIENT
# ============================================================

client = FortyGuardClient()


# ============================================================
# GET ENVIRONMENTAL DATA FOR ROUTE SEGMENT
# ============================================================

def get_temperature_for_segment(
    latitude: float,
    longitude: float,
    fallback_temperature: float,
):
    """
    Get environmental information for one route segment.

    FortyGuard provides:
        - Temperature
        - Heat Index
        - Apparent Temperature
        - GHI
        - DNI
        - DHI

    If FortyGuard takes too long or fails,
    fallback values are returned so ThermoRoute
    can continue calculating the route.
    """

    now = datetime.now()

    start_date = now.strftime("%Y-%m-%d")
    start_time = now.strftime("%H:%M")

    try:

        # ----------------------------------------------------
        # SUBMIT ENVIRONMENTAL ANALYSIS
        # ----------------------------------------------------

        submitted = client.get_environmental_parameters(
            latitude=latitude,
            longitude=longitude,
            temperature=fallback_temperature,
            start_date=start_date,
            start_time=start_time,
            analysis=[
                "heat_index_celsius",
                "apparent_temperature_celsius",
            ],
        )

        print("FortyGuard submission:")
        print(submitted)

        # ----------------------------------------------------
        # EXTRACT ACTIVITY ID
        # ----------------------------------------------------

        activity_id = client.extract_activity_id(
            submitted
        )

        if not activity_id:
            raise RuntimeError(
                "FortyGuard did not return an activity ID."
            )

        print(
            f"FortyGuard activity started: "
            f"{activity_id}"
        )

        # ----------------------------------------------------
        # WAIT FOR COMPLETION
        # ----------------------------------------------------
        #
        # IMPORTANT:
        # Keep this short so route optimization
        # does not remain blocked for minutes.
        #

        completed = client.wait_for_activity(
            activity_id=activity_id,
            timeout_seconds=20,
            poll_seconds=5,
        )

        print("FortyGuard completed result:")
        print(completed)

        # ----------------------------------------------------
        # FIND LOCATION DATA
        # ----------------------------------------------------

        location = (
            completed
            .get("data", {})
            .get("result", {})
            .get("locations", [{}])[0]
        )

        # ----------------------------------------------------
        # ENVIRONMENT PARAMETERS
        # ----------------------------------------------------

        parameters = location.get(
            "parameters",
            {},
        )

        # ----------------------------------------------------
        # SOLAR DATA
        # ----------------------------------------------------

        solar = (
            location
            .get("solar_irradiance", {})
            .get("clear_sky", {})
        )

        # ----------------------------------------------------
        # TEMPERATURE
        # ----------------------------------------------------

        temperature = location.get(
            "temperature",
            fallback_temperature,
        )

        # ----------------------------------------------------
        # HEAT INDEX
        # ----------------------------------------------------

        heat_index_values = parameters.get(
            "heat_index_celsius",
            [],
        )

        if heat_index_values:
            heat_index = heat_index_values[0]
        else:
            heat_index = temperature

        # ----------------------------------------------------
        # APPARENT TEMPERATURE
        # ----------------------------------------------------

        apparent_temperature_values = parameters.get(
            "apparent_temperature_celsius",
            [],
        )

        if apparent_temperature_values:
            apparent_temperature = (
                apparent_temperature_values[0]
            )
        else:
            apparent_temperature = temperature

        # ----------------------------------------------------
        # FINAL RESULT
        # ----------------------------------------------------

        result = {
            "temperature": temperature,

            "heat_index": heat_index,

            "apparent_temperature": (
                apparent_temperature
            ),

            "ghi": solar.get(
                "ghi",
                0,
            ),

            "dni": solar.get(
                "dni",
                0,
            ),

            "dhi": solar.get(
                "dhi",
                0,
            ),

            "source": "fortyguard",

            "activity_id": activity_id,
        }

        return result

    # ========================================================
    # FALLBACK
    # ========================================================

    except Exception as error:

        print(
            "FortyGuard environmental analysis failed:"
        )

        print(error)

        return {
            "temperature": fallback_temperature,

            "heat_index": fallback_temperature,

            "apparent_temperature": (
                fallback_temperature
            ),

            "ghi": 0,

            "dni": 0,

            "dhi": 0,

            "source": "fallback",
        }