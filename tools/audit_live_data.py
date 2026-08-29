"""
ThermoRoute submission audit helper.

Run from the repository root:

    py tools/audit_live_data.py

This script does not call external APIs. It looks for obvious signs of
hard-coded/demo route scenarios and checks whether the expected live-routing
and FortyGuard integration names exist in the backend.
"""

from pathlib import Path
import re


ROOT = Path(__file__).resolve().parents[1]

main = ROOT / "backend" / "main.py"
routing = ROOT / "backend" / "services" / "routing.py"
thermal = ROOT / "backend" / "services" / "thermal.py"
provider = ROOT / "backend" / "services" / "temperature_provider.py"

files = [main, routing, thermal, provider]


for path in files:
    print(f"\n=== {path.relative_to(ROOT)} ===")

    if not path.exists():
        print("MISSING")
        continue

    text = path.read_text(
        encoding="utf-8",
        errors="replace",
    )

    print(
        f"size={len(text)} chars, "
        f"lines={len(text.splitlines())}"
    )


patterns = {
    # Review flag only. This intentionally looks for obvious hard-coded
    # thermal/demo values anywhere in the backend.
    "temporary_demo_scenarios": (
        r"TEMPORARY DEMO SCENARIOS"
        r'|temperature[\'"]?\s*:\s*\d+'
        r'|travel_time_min[\'"]?\s*:\s*\d+'
    ),
    "fortyguard_reference": r"FortyGuard|fortyguard",
    "osrm_reference": r"OSRM|osrm",
    "route_exposure": r"calculate_route_exposure",
}


for name, pattern in patterns.items():
    found = []

    for path in files:
        if not path.exists():
            continue

        text = path.read_text(
            encoding="utf-8",
            errors="replace",
        )

        if re.search(pattern, text, flags=re.IGNORECASE):
            found.append(str(path.relative_to(ROOT)))

    print(
        f"{name}: "
        f"{', '.join(found) if found else 'NONE'}"
    )


print(
    """
Interpretation:

- A 'temporary_demo_scenarios' match is a review flag, not automatically an error.
- If hard-coded temperatures/travel times are part of the live /api/optimize path,
  replace them with real OSRM + FortyGuard data before submission.
- Verify that any fallback path is clearly marked as fallback.
"""
)