.PHONY: setup login doctor connect update up down logs

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
