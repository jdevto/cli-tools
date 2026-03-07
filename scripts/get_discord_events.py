#!/usr/bin/env python3
"""
get_discord_events.py

Fetch a Discord guild's scheduled events (raw API response, no conversion).

Usage:
  Set DISCORD_BOT_TOKEN and DISCORD_GUILD_ID, then:
    ./get_discord_events.py                     # use guild ID from env
    ./get_discord_events.py --guild-id 123456789   # override guild ID

  As a library:
    from get_discord_events import get_events_for_guild
    events = get_events_for_guild()  # or guild_id="..."

Config sources:
  Environment: DISCORD_BOT_TOKEN (required), DISCORD_GUILD_ID (required unless --guild-id)

Output:
  Raw JSON to stdout (same as Discord API). No time conversion or reshaping.
  Uses stdlib only; no pip install required.

Exit codes:
  0 success
  2 config/usage error (missing env vars)
  3 auth error (invalid token, forbidden)
  4 not found (guild or resource)
  5 runtime/API error
"""

import argparse
import json
import os
import sys
from urllib.error import HTTPError
from urllib.request import Request, urlopen

DISCORD_API_BASE = "https://discord.com/api/v10"
# Cloudflare blocks default Python urllib User-Agent (403/1010); Discord recommends a bot identifier
USER_AGENT = "DiscordBot (https://github.com/aws-user-group-nz, 1.0)"


def eprint(*args: object, **kwargs) -> None:
    print(*args, file=sys.stderr, **kwargs)


def get_scheduled_events(token: str, guild_id: str) -> list:
    """GET guild scheduled-events from Discord API. Return raw list or raise."""
    url = f"{DISCORD_API_BASE}/guilds/{guild_id}/scheduled-events?with_user_count=true"
    req = Request(url, method="GET")
    req.add_header("Authorization", f"Bot {token}")
    req.add_header("Content-Type", "application/json")
    req.add_header("User-Agent", USER_AGENT)
    try:
        with urlopen(req) as resp:
            return json.loads(resp.read().decode())
    except HTTPError as e:
        body = e.read().decode() if e.fp else ""
        raise RuntimeError(f"Discord API returned HTTP {e.code}: {body}") from e


def get_events_for_guild(guild_id: str | None = None) -> list:
    """
    Fetch Discord guild scheduled events and return raw API response (list).
    Uses DISCORD_BOT_TOKEN and DISCORD_GUILD_ID from environment unless guild_id is passed.
    """
    token = os.environ.get("DISCORD_BOT_TOKEN")
    if not token:
        raise RuntimeError("DISCORD_BOT_TOKEN must be set")
    gid = guild_id or os.environ.get("DISCORD_GUILD_ID")
    if not gid:
        raise RuntimeError("DISCORD_GUILD_ID must be set or pass guild_id")

    return get_scheduled_events(token, gid)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Fetch a Discord guild's scheduled events (raw API response). "
        "Requires DISCORD_BOT_TOKEN and DISCORD_GUILD_ID in the environment.",
        epilog="Examples:\n"
        "  ./get_discord_events.py                  # use DISCORD_GUILD_ID from env\n"
        "  ./get_discord_events.py --guild-id 123   # override guild ID\n",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    parser.add_argument(
        "--guild-id",
        default=None,
        metavar="ID",
        help="Discord guild (server) ID. If set, overrides DISCORD_GUILD_ID from environment",
    )
    args = parser.parse_args()

    try:
        events = get_events_for_guild(guild_id=args.guild_id)
    except RuntimeError as e:
        msg = str(e)
        eprint(msg)
        if "must be set" in msg:
            return 2
        if "401" in msg or "403" in msg or "Unauthorized" in msg or "Forbidden" in msg:
            return 3
        if "404" in msg or "not found" in msg.lower():
            return 4
        return 5

    print(json.dumps(events, indent=2))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
