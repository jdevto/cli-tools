#!/usr/bin/env python3
"""
get_youtube_upcoming.py

Fetch a YouTube channel's upcoming scheduled live streams (raw API response).

Uses YouTube Data API v3 (https://www.googleapis.com/youtube/v3). Requires
YOUTUBE_API_KEY. Default channel: AWSEventsChannel. Quota: search.list (100 units)
and videos.list (1 unit) per run; free tier has 10,000 units/day.

Usage:
  export YOUTUBE_API_KEY=your_key
  ./get_youtube_upcoming.py
  ./get_youtube_upcoming.py --channel-handle AWSEventsChannel
  ./get_youtube_upcoming.py --channel-id UCxxxxxx

  As a library:
    from get_youtube_upcoming import get_upcoming_for_channel
    videos = get_upcoming_for_channel()  # or channel_handle="...", channel_id="..."

Config sources:
  Environment: YOUTUBE_API_KEY (required), YOUTUBE_CHANNEL_ID (optional, overrides handle)

Output:
  Raw JSON list of video objects (videos.list items). No upcoming -> [].
  Uses stdlib only; no pip install required.

Exit codes:
  0 success
  2 config/usage error (missing API key)
  3 auth error (invalid key, 403)
  4 not found (channel not found)
  5 runtime/API error (quota exceeded, 5xx, etc.)
"""

import argparse
import json
import os
import sys
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

YOUTUBE_API_BASE = "https://www.googleapis.com/youtube/v3"
DEFAULT_CHANNEL_HANDLE = "AWSEventsChannel"


def eprint(*args: object, **kwargs) -> None:
    print(*args, file=sys.stderr, **kwargs)


def get_channel_id(api_key: str, handle: str) -> str:
    """Resolve channel handle to channel ID via channels.list forHandle. Raise if not found."""
    handle = handle.strip()
    if handle and not handle.startswith("@"):
        handle = "@" + handle
    params = {"part": "id", "forHandle": handle, "key": api_key}
    url = f"{YOUTUBE_API_BASE}/channels?{urlencode(params)}"
    req = Request(url, method="GET")
    try:
        with urlopen(req) as resp:
            data = json.loads(resp.read().decode())
    except HTTPError as e:
        body = e.read().decode() if e.fp else ""
        raise RuntimeError(f"YouTube API channels returned HTTP {e.code}: {body}") from e
    items = data.get("items") or []
    if not items:
        raise RuntimeError(f"YouTube channel not found: {handle}")
    return items[0]["id"]


def search_upcoming(api_key: str, channel_id: str) -> list:
    """Search for upcoming broadcasts for channel_id. Return list of video IDs (may be empty)."""
    params = {
        "part": "id,snippet",
        "channelId": channel_id,
        "eventType": "upcoming",
        "type": "video",
        "key": api_key,
    }
    url = f"{YOUTUBE_API_BASE}/search?{urlencode(params)}"
    req = Request(url, method="GET")
    try:
        with urlopen(req) as resp:
            data = json.loads(resp.read().decode())
    except HTTPError as e:
        body = e.read().decode() if e.fp else ""
        raise RuntimeError(f"YouTube API search returned HTTP {e.code}: {body}") from e
    items = data.get("items") or []
    video_ids = []
    for item in items:
        vid = (item.get("id") or {}).get("videoId")
        if vid:
            video_ids.append(vid)
    return video_ids


def get_video_details(api_key: str, video_ids: list) -> list:
    """Fetch video details (snippet, liveStreamingDetails) for given IDs. Return items list."""
    if not video_ids:
        return []
    params = {
        "part": "snippet,liveStreamingDetails",
        "id": ",".join(video_ids),
        "key": api_key,
    }
    url = f"{YOUTUBE_API_BASE}/videos?{urlencode(params)}"
    req = Request(url, method="GET")
    try:
        with urlopen(req) as resp:
            data = json.loads(resp.read().decode())
    except HTTPError as e:
        body = e.read().decode() if e.fp else ""
        raise RuntimeError(f"YouTube API videos returned HTTP {e.code}: {body}") from e
    return data.get("items") or []


def get_upcoming_for_channel(
    api_key: str | None = None,
    channel_id: str | None = None,
    channel_handle: str | None = None,
) -> list:
    """
    Fetch upcoming scheduled live streams for a YouTube channel. Returns raw video objects.
    Uses YOUTUBE_API_KEY from env if api_key not passed. Channel from channel_id, or
    YOUTUBE_CHANNEL_ID env, or resolved from channel_handle (default AWSEventsChannel).
    """
    key = api_key or os.environ.get("YOUTUBE_API_KEY")
    if not key:
        raise RuntimeError("YOUTUBE_API_KEY must be set or pass api_key")

    cid = channel_id or os.environ.get("YOUTUBE_CHANNEL_ID")
    if not cid:
        handle = channel_handle if channel_handle is not None else DEFAULT_CHANNEL_HANDLE
        cid = get_channel_id(key, handle)

    video_ids = search_upcoming(key, cid)
    return get_video_details(key, video_ids)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fetch a YouTube channel's upcoming scheduled live streams (raw API response). "
        "Requires YOUTUBE_API_KEY. Default channel: AWSEventsChannel.",
        epilog="Examples:\n"
        "  ./get_youtube_upcoming.py\n"
        "  ./get_youtube_upcoming.py --channel-handle AWSEventsChannel\n"
        "  ./get_youtube_upcoming.py --channel-id UCxxxxxx\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--channel-id",
        default=None,
        metavar="ID",
        help="YouTube channel ID. If set, overrides env and handle",
    )
    parser.add_argument(
        "--channel-handle",
        default=None,
        metavar="HANDLE",
        help=f"Channel handle (e.g. AWSEventsChannel). Default: {DEFAULT_CHANNEL_HANDLE}",
    )
    args = parser.parse_args()

    try:
        videos = get_upcoming_for_channel(
            channel_id=args.channel_id,
            channel_handle=args.channel_handle,
        )
    except RuntimeError as e:
        msg = str(e)
        eprint(msg)
        if "YOUTUBE_API_KEY must be set" in msg:
            return 2
        if "403" in msg or "Forbidden" in msg or "invalid" in msg.lower():
            return 3
        if "not found" in msg.lower() or "404" in msg:
            return 4
        return 5

    print(json.dumps(videos, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
