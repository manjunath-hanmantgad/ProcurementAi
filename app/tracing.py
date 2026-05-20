from __future__ import annotations

import os


def get_langfuse_handler():
    pk = os.getenv("LANGFUSE_PUBLIC_KEY", "").strip()
    sk = os.getenv("LANGFUSE_SECRET_KEY", "").strip()
    if not (pk and sk):
        return None
    try:
        from langfuse.callback import CallbackHandler

        return CallbackHandler(
            public_key=pk,
            secret_key=sk,
            host=os.getenv("LANGFUSE_HOST", "https://cloud.langfuse.com"),
        )
    except Exception:
        return None
