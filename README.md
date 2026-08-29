# ThermoRoute — Heat-Aware Route Optimization

## Overview

ThermoRoute is a heat-aware navigation system that adds environmental
intelligence to conventional route planning.

Instead of optimizing only for travel time and distance, ThermoRoute
evaluates real route alternatives using:

- OpenStreetMap / OSRM for road routing
- FortyGuard for environmental data
- ThermoRoute's thermal exposure calculation
- constraint-aware route optimization
- personalized traveller preferences
- explainable route recommendations
- heat-safety and hydration guidance

The goal is simple:

> Don't just find the fastest road. Find the route that makes the most sense for the heat.

---

## Problem

Traditional navigation mainly focuses on travel time and distance.

In hot environments, the fastest route is not necessarily the most
comfortable or heat-aware route.

ThermoRoute adds a climate-intelligence layer so that route alternatives
can be evaluated using environmental conditions along the journey.

---

## Solution

ThermoRoute combines live routing information with environmental
intelligence.

The system:

1. Accepts an origin and destination.
2. Converts locations into coordinates.
3. Retrieves real road routes from OpenStreetMap / OSRM.
4. Preserves real route geometry, travel time, and distance.
5. Samples points along the route.
6. Retrieves environmental observations from FortyGuard.
7. Calculates thermal exposure for each route.
8. Applies the user's travel constraints.
9. Selects the best route.
10. Explains why that route was recommended.
11. Provides heat-safety and hydration guidance.

---

## Core Architecture

```text
Flutter Frontend
        |
        v
FastAPI Backend
        |
        +----------------------+
        |                      |
        v                      v
   Geocoding          OpenStreetMap / OSRM
                               |
                               v
                   Real route alternatives
                               |
                               v
                 Geometry + time + distance
                               |
                               v
                       Route sampling
                               |
                               v
                         FortyGuard
                               |
                               v
                 Environmental observations
                               |
                               v
                  Thermal exposure engine
                               |
                               v
                       Route optimizer
                               |
                               v
               Recommendation + explanation
                               |
                               v
                       Flutter UI
```

---

## Data Sources

### Routing

ThermoRoute uses OpenStreetMap / OSRM for real road routing.

OSRM provides:

- route geometry
- travel time
- distance
- route alternatives

The live route response identifies the routing source as:

```text
osrm_openstreetmap
```

### Environmental Data

ThermoRoute uses FortyGuard for environmental observations sampled
along the route.

These environmental observations are used as inputs to the
ThermoRoute thermal exposure calculation.

---

## Coordinate Handling

Users enter human-readable locations such as:

```text
Phoenix, Arizona
Scottsdale, Arizona
```

The backend geocodes these locations before routing.

GeoJSON coordinates are represented as:

```text
[longitude, latitude]
```

A verified live route returned:

```text
Origin
Latitude: 33.4484367
Longitude: -112.074141

Destination
Latitude: 33.4942189
Longitude: -111.926018
```

The route geometry is obtained from the routing provider rather than
manually fabricated.

---
## Thermal Exposure

ThermoRoute calculates the total thermal exposure for a route by
calculating exposure for each route segment and summing the segment
exposure values.

The calculation uses the environmental information available for each
segment:

- temperature
- segment duration in minutes
- heat index, when available
- apparent temperature, when available
- wet-bulb temperature, when available

The production calculation is:

```text
Total Thermal Exposure
=
Σ Segment Thermal Exposure

Segment Thermal Exposure
=
calculate_segment_exposure(
    temperature,
    duration_minutes,
    heat_index,
    apparent_temperature,
    wet_bulb_temperature
)

## Optimization

ThermoRoute evaluates route alternatives against user constraints.

The optimizer considers:

- travel time
- maximum allowed extra travel time
- thermal exposure budget
- traveller profile
- route strategy

The decision flow is:

```text
Generate real route alternatives
            |
            v
Measure time + distance
            |
            v
Sample route points
            |
            v
Retrieve FortyGuard environmental data
            |
            v
Calculate thermal exposure
            |
            v
Apply travel-time constraints
            |
            v
Apply thermal constraints
            |
            v
Compare valid routes
            |
            v
Recommend best route
            |
            v
Explain the decision
```

---

## Traveller Profiles

ThermoRoute supports personalized travel preferences.

### Everyday

A general travel profile balancing time and thermal exposure.

### Heat-sensitive

Places greater importance on reducing thermal exposure.

### Outdoor worker

Designed for users who spend significant time outdoors and may benefit
from stronger heat-aware routing.

---

## Route Strategies

### Balanced

Balances travel time and thermal exposure.

### Minimize Heat

Prioritizes lower estimated thermal exposure while respecting the
user's travel-time constraint.

### Fastest

Prioritizes minimum travel time.

---

## Recommended Journey

The application highlights the route selected by the optimizer.

The result can display:

- travel time
- distance
- thermal exposure
- risk level
- route geometry
- recommendation explanation

The recommendation is generated from the returned route and
environmental data.

---

## Fastest vs ThermoRoute

ThermoRoute compares the fastest route with the selected heat-aware
route.

Example presentation:

```text
FASTEST ROUTE
21.1 min
20.67 km

THERMOROUTE CHOICE
22.3 min
21.10 km

Additional travel:
+1.2 min

Thermal exposure:
Lower on the ThermoRoute option
```

The example numbers above are illustrative.

During live execution, ThermoRoute calculates comparison values from
the actual API response.

---

## Route Comparison

The application displays the available route alternatives and compares:

- travel time
- distance
- thermal exposure
- risk level
- route source
- recommendation status

Example UI structure:

```text
Route 1
OSRM route
21.1 min
20.67 km
Thermal exposure: 21.12
Risk: LOW

Route 2
OSRM route
22.0 min
20.92 km
Thermal exposure: 22.00
Risk: LOW
```

The live application populates these values dynamically.

---

## Why This Route?

ThermoRoute explains why a route was selected rather than simply
returning a route.

Example:

```text
WHY THIS ROUTE?

✓ Within the selected thermal budget
✓ Meets the travel-time constraint
✓ Evaluated against available route alternatives
✓ Environmental data supplied by FortyGuard
```

Any numerical comparison shown in the live application is calculated
from returned route data.

---

## Heat Intelligence

The Heat Intelligence section separates live provider data from
ThermoRoute's calculated metrics.

Example:

```text
FORTYGUARD LIVE DATA

Average temperature     35.0 °C
Peak temperature        35.0 °C
FortyGuard samples      4
Fallback samples        0
Source                  FortyGuard

THERMOROUTE CALCULATION

Thermal exposure        21.12 / 100
Risk level              LOW
```

The documented live optimization response returned:

```text
source: fortyguard
fortyguard_sample_count: 4
fallback_sample_count: 0
temperature_c_avg: 35.0
temperature_c_max: 35.0
thermal_exposure: 21.12
```

---
## FortyGuard Live API Evidence

ThermoRoute retrieves environmental observations from FortyGuard using
the environmental parameters endpoint.

### Request

```text
Provider: FortyGuard
Endpoint: https://api.fortyguard.com/v1/env_params
Method: POST

Headers:
api-key: REDACTED
Content-Type: application/json

## Live Routing Evidence

The same live optimization returned:

```text
route_source:
osrm_openstreetmap
```

with:

```text
Origin:
latitude  = 33.4484367
longitude = -112.074141

Destination:
latitude  = 33.4942189
longitude = -111.926018
```

The response also contained GeoJSON route geometry returned by the
routing service.

---

## Provider Data vs Calculated Data

ThermoRoute distinguishes external provider data from calculated
metrics.

### Provider Data

Examples:

- temperature
- heat index
- apparent temperature
- environmental observations

These values originate from FortyGuard when provided by the API.

### Calculated Data

Examples:

- thermal exposure
- thermal risk level
- route comparison
- exposure reduction
- optimization result
- recommendation explanation

These values are calculated by ThermoRoute.

---

## Fallback Handling

ThermoRoute tracks whether environmental data came from FortyGuard or
a fallback source.

Live environmental data should be identified as:

```text
LIVE — FortyGuard
```

Fallback environmental data should be identified as:

```text
FALLBACK — external environmental data unavailable
```

Fallback values must never be presented as live FortyGuard observations.

For the documented live test:

```text
FortyGuard samples: 4
Fallback samples: 0
```

---

## Thermal Route Map

ThermoRoute provides a visual route map.

The map can show:

```text
Start
Recommended route
Alternative route
Destination
```

The displayed route geometry comes from the backend route response.

The application does not fabricate the route coordinates.

The map uses OpenStreetMap-based map data and OSRM route geometry.

---

## Smart Heat Safety

ThermoRoute provides general heat-safety guidance based on the
calculated thermal conditions.

Examples include:

- stay hydrated
- carry water
- follow appropriate heat precautions
- consider lower-exposure routes when available

This is general travel guidance and is not medical advice.

---

## Hydration Reminder

The application includes a hydration reminder as part of the
heat-safety experience.

Example:

```text
Hydration reminder:
Carry water for your journey.
```

---

## Data Sources UI

The application exposes its data sources clearly:

```text
Routing
OpenStreetMap / OSRM

Environmental data
FortyGuard

Decision engine
ThermoRoute optimizer
```

This makes the architecture transparent to users and judges.

---

## ThermoRoute Impact

The application can summarize the measurable result of optimization.

The impact section can display:

```text
Routes evaluated
Thermal reduction
Extra travel time
Traveller profile
```

These values are calculated from the returned route alternatives.

---

## Departure Insight

The application can provide a simple interpretation of the selected
departure time.

Example:

```text
DEPARTURE INSIGHT

Selected departure:
14:00

Current route exposure:
21.12 / 100

Risk:
LOW
```

Live values are calculated from the current optimization response.

---

## API Flow

```text
User input
    |
    v
Geocoding
    |
    v
OSRM route alternatives
    |
    v
Route geometry + time + distance
    |
    v
Route sampling
    |
    v
FortyGuard environmental observations
    |
    v
Thermal exposure calculation
    |
    v
Constraint evaluation
    |
    v
Route optimization
    |
    v
Recommended route
    |
    v
Explanation + safety guidance
```

---

## Technology Stack

### Frontend

```text
Flutter
Dart
flutter_map
OpenStreetMap map data
```

### Backend

```text
Python
FastAPI
```

### Routing

```text
OpenStreetMap
OSRM
```

### Environmental Intelligence

```text
FortyGuard API
```

### Decision Engine

```text
ThermoRoute optimizer
```

### Version Control

```text
Git
GitHub
```

---

## Why Deterministic Optimization?

ThermoRoute is designed around transparent and explainable route
decisions.

The current MVP uses deterministic optimization so that the route
selection can be inspected and explained.

This allows the application to show why a route was selected based on:

- time
- thermal exposure
- constraints
- profile
- strategy

---

## What Makes ThermoRoute Different?

Traditional navigation asks:

```text
What is the fastest route?
```

ThermoRoute asks:

```text
Which route is the best choice when travel time,
environmental conditions, thermal exposure,
user preferences, and constraints are considered together?
```

The key difference is the climate-intelligence layer:

```text
Route
+
Travel time
+
Distance
+
Environmental exposure
+
User preference
+
Constraints
=
Heat-aware recommendation
```

---

## Security

API keys must never be committed to GitHub.

Use:

```text
.env
```

Example:

```text
FORTYGUARD_API_KEY=your_key_here
```

Commit only a safe template such as:

```text
.env.example
```

with no real credentials.

Never publish the actual FortyGuard API key in:

- source code
- README
- screenshots
- logs
- GitHub commits

---

## Local Setup

### Backend

From the project root:

```powershell
cd C:\Users\Adhya\ThermoRoute
py -m uvicorn backend.main:app --reload --port 8000
```

Keep this terminal running.

### Flutter

Open a second terminal:

```powershell
cd C:\Users\Adhya\ThermoRoute\frontend\thermoroute_app
flutter pub get
flutter run -d chrome
```

---

## Validation

### Backend validation

```powershell
cd C:\Users\Adhya\ThermoRoute
py -m compileall backend
```

### Flutter validation

```powershell
cd C:\Users\Adhya\ThermoRoute\frontend\thermoroute_app
flutter analyze
```

The Flutter analyzer may report deprecation information for older
Flutter APIs, but the application should contain no compile errors.

---

## API Endpoint

The primary application workflow is:

```text
POST /api/optimize
```

This endpoint performs the route-generation, environmental enrichment,
thermal calculation, and optimization workflow.

---

## Live Testing Checklist

Before submission, test multiple real locations.

For every test verify:

1. Origin is geocoded successfully.
2. Destination is geocoded successfully.
3. OSRM returns real route geometry.
4. Travel time is returned.
5. Distance is returned.
6. FortyGuard environmental data is returned.
7. FortyGuard source is identified correctly.
8. Fallback count is zero when live provider data succeeds.
9. Thermal exposure is calculated from returned environmental data.
10. The UI shows the returned environmental information.
11. The recommendation respects the selected constraints.
12. Route comparison uses actual returned route values.

---

## Example Verified Live Test

```text
Origin:
Phoenix, Arizona

Destination:
Scottsdale, Arizona

Departure:
14:00

Routing:
OpenStreetMap / OSRM

Route source:
osrm_openstreetmap

Environmental provider:
FortyGuard

FortyGuard samples:
4

Fallback samples:
0

Average temperature:
35.0 °C

Maximum temperature:
35.0 °C

Calculated thermal exposure:
21.12 / 100
```

---

## Limitations

ThermoRoute's thermal exposure value is an estimated decision-support
metric.

It is not:

- a medical diagnosis
- a heatstroke probability
- a guarantee of personal safety
- a replacement for official weather or health guidance

Environmental data availability can vary by location.

OSRM may return different numbers of route alternatives depending on
the road network.

---

## Future Work

Potential future improvements include:

- route × departure-time optimization
- richer environmental variables
- historical thermal validation
- user-feedback-based personalization
- outdoor-worker planning
- logistics and delivery routing
- heat-wave mobility alerts
- city-scale heat-aware transportation
- personalized exposure models

---

## Hackathon Demo Flow

Recommended live demonstration:

```text
1. Enter origin
2. Enter destination
3. Select traveller profile
4. Select route strategy
5. Optimize Journey
6. Show Thermal Route Map
7. Show Recommended Journey
8. Show Fastest vs ThermoRoute
9. Show Route Comparison
10. Show Why This Route
11. Show Heat Intelligence
12. Show FortyGuard live values
13. Show Smart Heat Safety
14. Show Hydration Reminder
15. Show Data Sources
```

---

## Key Demo Message

> ThermoRoute does not simply find the fastest route.
> It combines real OpenStreetMap/OSRM routing with real FortyGuard
> environmental data and a transparent thermal optimization layer to
> make a heat-aware, constraint-aware travel decision.