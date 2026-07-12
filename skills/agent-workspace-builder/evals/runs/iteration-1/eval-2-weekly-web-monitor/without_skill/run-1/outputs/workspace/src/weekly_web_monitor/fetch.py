from __future__ import annotations

from dataclasses import dataclass
from urllib.error import HTTPError, URLError
from urllib.request import Request, urlopen

from .config import Settings, Target


class FetchError(RuntimeError):
    """Raised when a target cannot be downloaded safely."""


@dataclass(frozen=True)
class FetchResult:
    text: str
    status: int
    content_type: str


def fetch_url(target: Target, settings: Settings) -> FetchResult:
    request = Request(
        target.url,
        headers={"User-Agent": settings.user_agent, "Accept-Encoding": "identity"},
        method="GET",
    )
    try:
        with urlopen(request, timeout=settings.timeout_seconds) as response:
            body = response.read(settings.max_response_bytes + 1)
            if len(body) > settings.max_response_bytes:
                raise FetchError(
                    f"response exceeds {settings.max_response_bytes} bytes"
                )
            charset = response.headers.get_content_charset() or "utf-8"
            content_type = response.headers.get_content_type()
            status = int(getattr(response, "status", 200))
    except FetchError:
        raise
    except HTTPError as exc:
        raise FetchError(f"HTTP {exc.code}") from exc
    except (URLError, TimeoutError, OSError) as exc:
        raise FetchError(str(exc)) from exc

    text = body.decode(charset, errors="replace").replace("\r\n", "\n")
    return FetchResult(text=text, status=status, content_type=content_type)
