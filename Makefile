.PHONY: setup login doctor connect update up down logs docs-install docs-serve docs-build

setup:
	./scripts/setup.sh

login:
	./scripts/login.sh

doctor:
	./scripts/doctor.sh

connect:
	./scripts/connect.sh

update:
	./scripts/update.sh

up:
	docker compose up -d

down:
	docker compose down

logs:
	docker compose logs -f firstmate

docs-install:
	python -m pip install -r requirements-docs.txt

docs-serve:
	mkdocs serve

docs-build:
	mkdocs build --strict
