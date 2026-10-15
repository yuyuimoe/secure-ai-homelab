.PHONY: docs-install docs-serve docs-build

docs-install:
	python -m pip install -r requirements-docs.txt

docs-serve:
	mkdocs serve

docs-build:
	mkdocs build --strict
