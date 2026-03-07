#!/usr/bin/env python3
"""
get_twitch_schedule.py

Fetch a Twitch channel's upcoming stream schedule via the Helix API.

Usage:
  Set TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET, then:
    ./get_twitch_schedule.py                     # AWS channel (default)
    ./get_twitch_schedule.py --login awsonair    # by channel login
    ./get_twitch_schedule.py --broadcaster-id 141981764   # by broadcaster ID

  As a library:
    from get_twitch_schedule import get_schedule_for_channel
    schedule = get_schedule_for_channel(login="aws")  # or broadcaster_id="..."

Config sources:
  Environment: TWITCH_CLIENT_ID, TWITCH_CLIENT_SECRET (required)

Output:
  JSON to stdout. If the channel has no schedule, outputs [] (Twitch returns 404).
  Uses stdlib only; no pip install required.

Exit codes:
  0 success
  2 config/usage error (missing env vars)
  3 auth error (token failure)
  4 not found (channel or schedule)
  5 runtime/API error
"""

import argparse
import json
import os
import sys
from urllib.error import HTTPError
from urllib.parse import urlencode
from urllib.request import Request, urlopen

OAUTH_TOKEN_URL = "https://id.twitch.tv/oauth2/token"
HELIX_BASE = "https://api.twitch.tv/helix"


def eprint(*args: object, **kwargs) -> None:
    print(*args, file=sys.stderr, **kwargs)


def get_token(client_id: str, client_secret: str) -> str:
    """POST to Twitch OAuth2 token endpoint; return access_token or raise."""
    data = urlencode({
        "client_id": client_id,
        "client_secret": client_secret,
        "grant_type": "client_credentials",
    }).encode()
    req = Request(OAUTH_TOKEN_URL, data=data, method="POST")
    req.add_header("Content-Type", "application/x-www-form-urlencoded")
    with urlopen(req) as resp:
        body = json.loads(resp.read().decode())
    token = body.get("access_token")
    if not token:
        raise RuntimeError("Failed to get Twitch access token")
    return token


def get_broadcaster_id(client_id: str, token: str, login: str) -> str:
    """GET Helix users by login; return data[0]['id'] or raise."""
    url = f"{HELIX_BASE}/users?{urlencode({'login': login})}"
    req = Request(url, method="GET")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Client-Id", client_id)
    with urlopen(req) as resp:
        data = json.loads(resp.read().decode())
    users = data.get("data") or []
    if not users:
        raise RuntimeError(f"Twitch channel not found: {login}")
    return users[0]["id"]


def get_schedule(client_id: str, token: str, broadcaster_id: str) -> tuple:
    """GET Helix schedule for broadcaster_id. Return (body_str, status_code)."""
    url = f"{HELIX_BASE}/schedule?{urlencode({'broadcaster_id': broadcaster_id})}"
    req = Request(url, method="GET")
    req.add_header("Authorization", f"Bearer {token}")
    req.add_header("Client-Id", client_id)
    try:
        with urlopen(req) as resp:
            return resp.read().decode(), resp.status
    except HTTPError as e:
        body = e.read().decode() if e.fp else ""
        return body, e.code


def get_schedule_for_channel(
    login: str | None = None,
    broadcaster_id: str | None = None,
) -> list | dict:
    """
    High-level: fetch schedule for a channel by login or broadcaster_id.
    Uses TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET from environment.
    Returns parsed JSON (list/dict). On 404 (no schedule), returns [].
    If both login and broadcaster_id are provided, broadcaster_id is used.
    """
    client_id = os.environ.get("TWITCH_CLIENT_ID")
    client_secret = os.environ.get("TWITCH_CLIENT_SECRET")
    if not client_id or not client_secret:
        raise RuntimeError("TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET must be set")

    token = get_token(client_id, client_secret)

    if broadcaster_id is None:
        if not login:
            login = "aws"
        broadcaster_id = get_broadcaster_id(client_id, token, login)

    body_str, status = get_schedule(client_id, token, broadcaster_id)

    if status == 404:
        return []
    if status != 200:
        raise RuntimeError(f"Schedule request returned HTTP {status}: {body_str}")

    return json.loads(body_str)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fetch a Twitch channel's upcoming stream schedule from the Helix API. "
        "Outputs JSON to stdout. Requires TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET in the environment.",
        epilog="Examples:\n"
        "  ./get_twitch_schedule.py                     # AWS channel (default)\n"
        "  ./get_twitch_schedule.py --login awsonair    # channel by login name\n"
        "  ./get_twitch_schedule.py --broadcaster-id 141981764   # skip login lookup\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--login",
        default="aws",
        metavar="NAME",
        help="Twitch channel login (e.g. aws, awsonair). Used only when --broadcaster-id is not set (default: aws)",
    )
    parser.add_argument(
        "--broadcaster-id",
        default=None,
        metavar="ID",
        help="Twitch broadcaster ID. If set, skips the users API lookup and fetches schedule directly",
    )
    args = parser.parse_args()

    try:
        if args.broadcaster_id is not None:
            schedule = get_schedule_for_channel(broadcaster_id=args.broadcaster_id)
        else:
            schedule = get_schedule_for_channel(login=args.login)
    except RuntimeError as e:
        msg = str(e)
        eprint(msg)
        if "TWITCH_CLIENT_ID and TWITCH_CLIENT_SECRET" in msg:
            return 2
        if "access token" in msg.lower():
            return 3
        if "not found" in msg.lower() or "404" in msg:
            return 4
        return 5

    print(json.dumps(schedule, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
