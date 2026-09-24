"""lab.util -- small, dependency-free helpers shared across the project.

Jython 2.7 (Ignition). Keep this module tiny and side-effect free: nothing here
touches tags, the database, or Perspective, so you can reason about it — and the
lab's validate.sh can parse it — without a running gateway.
"""


def to_float(value, default=0.0):
    """Best-effort float conversion that never raises.

    Tag reads and UI inputs can arrive as None, "", or a stray string. Use this
    at the boundary so the rest of the code can assume a real number.
    """
    if value is None:
        return default
    try:
        return float(value)
    except (ValueError, TypeError):
        return default


def clamp(value, low, high):
    """Constrain value to the inclusive [low, high] range."""
    if value < low:
        return low
    if value > high:
        return high
    return value
