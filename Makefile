.PHONY: test test-python test-swift run-sidecar run-desktop

test: test-python test-swift

test-python:
	cd agent && python3.13 -m venv .venv && source .venv/bin/activate && pip install -q -r requirements.txt && pytest -q

test-swift:
	cd apps/desktop && swift build

run-sidecar:
	cd agent && uvicorn app.main:app --host 127.0.0.1 --port 7789 --reload

run-desktop:
	cd apps/desktop && swift run
