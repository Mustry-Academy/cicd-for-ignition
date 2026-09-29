from app import greet, farewell


def test_greet_uses_name():
    assert greet("Ada") == "Hello, Ada!"


def test_greet_default_world():
    assert greet("world") == "Hello, world!"


def test_greet_shout():
    assert greet("Ada", shout=True) == "HELLO, ADA!"


def test_farewell_uses_name():
    assert farewell("Ada") == "Goodbye, Ada!"


def test_farewell_shout():
    assert farewell("Ada", shout=True) == "GOODBYE, ADA!"
