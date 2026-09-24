# Presence of this conftest.py puts sample-app/ on sys.path during test collection,
# so `from app import greet` resolves whether you run `pytest sample-app/tests` from the
# repo root or `pytest tests` from inside sample-app/. Intentionally empty otherwise.
