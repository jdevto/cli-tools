# get_discord_events.py

This script fetches a Discord guild's scheduled events from the Discord API and prints the raw JSON response to stdout. No time conversion or reshaping; uses only the Python standard library (no pip install required).

## Usage

```bash
./get_discord_events.py [--guild-id ID]
```

Set `DISCORD_BOT_TOKEN` and `DISCORD_GUILD_ID` in the environment (or pass `--guild-id` to override the guild).

- **--guild-id**: Discord guild (server) ID. If set, overrides `DISCORD_GUILD_ID` from the environment.

## Example Usage

Using environment variables:

```bash
export DISCORD_BOT_TOKEN="your_bot_token"
export DISCORD_GUILD_ID="your_guild_id"
./get_discord_events.py
```

Override guild ID:

```bash
./get_discord_events.py --guild-id 123456789
```

## Verification

Check that the script prints valid JSON (array of scheduled events, or `[]` if none):

```bash
./get_discord_events.py | jq .
```

## Output

- **Success**: Raw JSON array to stdout (Discord API scheduled-events response).
- **Errors**: Error message to stderr and non-zero exit code.

## Required environment variables

- **DISCORD_BOT_TOKEN** — Discord bot token (create a bot in the Discord Developer Portal).
- **DISCORD_GUILD_ID** — Discord guild (server) ID. Can be overridden with `--guild-id`.

## Exit codes

- **0** — Success; JSON printed to stdout.
- **2** — Config/usage error (missing `DISCORD_BOT_TOKEN` or `DISCORD_GUILD_ID`).
- **3** — Auth error (invalid token, 401/403).
- **4** — Not found (guild or resource not found).
- **5** — Runtime/API error (e.g. other HTTP errors from Discord API).

## Use as a library

```python
from get_discord_events import get_events_for_guild

# Use DISCORD_GUILD_ID from environment
events = get_events_for_guild()

# Or pass guild_id explicitly
events = get_events_for_guild(guild_id="123456789")
# Returns list (raw API response).
```
