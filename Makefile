.PHONY: up down build test seed migrate eval lint clean health mcp

IMAGE_NAME ?= procureai
TAG ?= local

up:
	docker compose up --build -d

down:
	docker compose down -v

build:
	docker build -t $(IMAGE_NAME):$(TAG) .

test:
	pytest tests/ -v

seed:
	python -c "from app.db.seed import seed_all; seed_all()"
	python -c "from app.rag.ingest_policy import ingest_policy_document; ingest_policy_document()"

migrate:
	python -c "from app.db.database import init_db; init_db()"

eval:
	@if [ -x .venv/bin/python ]; then .venv/bin/python evals/run_evals.py; else python3 evals/run_evals.py; fi

mcp:
	python -m app.mcp_server.server

lint:
	ruff check app/ tests/ --ignore=F401,E402 2>/dev/null || echo "Lint warnings noted"

clean:
	find . -type d -name __pycache__ -exec rm -rf {} + 2>/dev/null; \
	find . -name "*.pyc" -delete 2>/dev/null

health:
	curl -s http://localhost:8004/health | python -m json.tool 2>/dev/null || echo "Check docker compose logs"
