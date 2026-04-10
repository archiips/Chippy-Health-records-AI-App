"""
Gemini client for chat and document explainer streaming.
Uses gemini-1.5-flash (1,500 req/day free tier vs 20/day for 2.5-flash).
"""

import asyncio
import concurrent.futures
from typing import AsyncGenerator

from google import genai as google_genai
from google.genai import types as genai_types

from app.core.config import settings

_MODEL = "gemini-2.5-flash-lite"
_client: google_genai.Client | None = None


def _get_client() -> google_genai.Client:
    global _client
    if _client is None:
        _client = google_genai.Client(api_key=settings.google_api_key)
    return _client


async def stream_completion(
    system: str,
    user: str,
    max_tokens: int = 1024,
    temperature: float = 0.2,
) -> AsyncGenerator[str, None]:
    """
    Streams a Gemini 1.5 Flash response as text chunks.
    Uses a thread + asyncio.Queue to bridge sync streaming SDK with async code.
    Real streaming — chunks arrive as Gemini generates them.
    """
    loop = asyncio.get_running_loop()
    queue: asyncio.Queue[str | BaseException | None] = asyncio.Queue()

    def _stream_in_thread() -> None:
        try:
            print(f"[gemini] streaming model={_MODEL} user_len={len(user)}")
            for chunk in _get_client().models.generate_content_stream(
                model=_MODEL,
                contents=user,
                config=genai_types.GenerateContentConfig(
                    system_instruction=system,
                    temperature=temperature,
                    max_output_tokens=max_tokens,
                ),
            ):
                if chunk.text:
                    loop.call_soon_threadsafe(queue.put_nowait, chunk.text)
        except Exception as exc:
            print(f"[gemini] ERROR {type(exc).__name__}: {exc}")
            loop.call_soon_threadsafe(queue.put_nowait, exc)
        finally:
            loop.call_soon_threadsafe(queue.put_nowait, None)

    executor = concurrent.futures.ThreadPoolExecutor(max_workers=1)
    loop.run_in_executor(executor, _stream_in_thread)

    while True:
        item = await queue.get()
        if item is None:
            break
        if isinstance(item, BaseException):
            raise item
        yield item
