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
9. Selects the best valid route.
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
                       Flutter UIs