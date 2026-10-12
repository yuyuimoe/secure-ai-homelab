.PHONY: install setup login doctor connect update up down status logs shell docs-install docs-serve docs-build

install:
	./scripts/install.sh

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
	systemctl --user start vibepod-pod.service

down:
	systemctl --user stop vibepod-pod.service

status:
	podman pod ps && podman ps -a

logs:
	podman logs -f vibepod pinp ai-memory

shell:
	podman exec -it vibepod fish

docs-install:
	python -m pip install -r requirements-docs.txt

docs-serve:
	mkdocs serve

docs-build:
	mkdocs build --strict
