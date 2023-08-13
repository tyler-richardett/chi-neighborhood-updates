.ONESHELL:

PYTHON = ./venv/bin/python3
PIP = ./venv/bin/pip
PACKAGE = chi_updates

venv/bin/activate: pyproject.toml
	python3 -m venv venv
	chmod +x ./venv/bin/activate
	. ./venv/bin/activate
	$(PIP) install --upgrade pip
	$(PIP) install -e '.[test]'

venv: venv/bin/activate
	. ./venv/bin/activate

clean:
	rm -rf *.egg-info
	rm -rf .pytest_cache
	rm -rf __pycache__
	rm -rf venv

test: venv
	pytest tests

format: venv
	black $(PACKAGE)
	isort $(PACKAGE)
	docformatter $(PACKAGE)

lint:
	prospector --with-tool mypy --profile prospector.yaml
	black --check $(PACKAGE)
	isort --check $(PACKAGE)
	docformatter --check $(PACKAGE)
