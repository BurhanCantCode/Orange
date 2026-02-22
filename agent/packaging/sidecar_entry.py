from __future__ import annotations

import argparse

import uvicorn
from app.main import app as fastapi_app


def main() -> None:
    parser = argparse.ArgumentParser(description="Orange sidecar server")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=7789)
    parser.add_argument("--log-level", default="info")
    args = parser.parse_args()

    uvicorn.run(
        fastapi_app,
        host=args.host,
        port=args.port,
        log_level=args.log_level,
    )


if __name__ == "__main__":
    main()
