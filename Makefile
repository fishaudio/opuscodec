PYTHON ?= python3
VENV ?= .venv
VENV_BIN := $(VENV)/bin
PIP := $(VENV_BIN)/pip
PY := $(VENV_BIN)/python

.PHONY: venv install test wheel binaries clean deep-clean

venv:
	$(PYTHON) -m venv $(VENV)
	$(PIP) install --upgrade pip setuptools wheel

install: venv
	$(PIP) install -e '.[test]'

test: install
	$(PY) -m pytest -q

wheel: install
	$(PY) -m pip wheel --no-deps --wheel-dir dist/wheels .

binaries:
	bash scripts/build_binaries.sh dist/bin

clean:
	rm -rf build dist .pytest_cache __pycache__ tests/__pycache__ opuscodec.egg-info

deep-clean: clean
	rm -rf $(VENV)
