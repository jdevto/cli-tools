# get_twitch_schedule.py

This script fetches a Twitch channel's upcoming stream schedule from the Twitch Helix API. It outputs JSON to stdout and uses only the Python standard library (no pip install required).

## Usage

```bash
./get_twitch_schedule.py [--login NAME] [--broadcaster-id ID]
```

Set `TWITCH_CLIENT_ID` and `TWITCH_CLIENT_SECRET` in the environment (or export them) before running.

- **--login** (default: `aws`): Twitch channel login name. Ignored if `--broadcaster-id` is set.
- **--broadcaster-id**: Twitch broadcaster ID. If set, skips the users API lookup and fetches the schedule directly.

## Example Usage

Default channel (AWS):

```bash
export TWITCH_CLIENT_ID="your_client_id"
export TWITCH_CLIENT_SECRET="your_client_secret"
./get_twitch_schedule.py
```

By channel login:

```bash
./get_twitch_schedule.py --login awsonair
```

By broadcaster ID (skip login lookup):

```bash
./get_twitch_schedule.py --broadcaster-id 141981764
```

## Verification

Check that the script prints valid JSON (schedule data or `[]` if the channel has no schedule):

```bash
./get_twitch_schedule.py | jq .
```

## Output

- **Success**: JSON object or array to stdout (Helix schedule response, or `[]` when the channel has no schedule — Twitch returns 404 in that case).
- **Errors**: Error message to stderr and non-zero exit code.

## Required environment variables

- **TWITCH_CLIENT_ID** — Twitch application client ID (create an application in the Twitch Developer Console).
- **TWITCH_CLIENT_SECRET** — Twitch application client secret.

## Exit codes

- **0** — Success; JSON printed to stdout.
- **2** — Config/usage error (missing `TWITCH_CLIENT_ID` or `TWITCH_CLIENT_SECRET`).
- **3** — Auth error (failed to obtain access token).
- **4** — Not found (channel or schedule not found).
- **5** — Runtime/API error (e.g. non-200/404 response from Helix).

## Use as a library

```python
from get_twitch_schedule import get_schedule_for_channel

# By login (default "aws" if omitted)
schedule = get_schedule_for_channel(login="awsonair")

# By broadcaster ID
schedule = get_schedule_for_channel(broadcaster_id="141981764")
# Returns list or dict; [] if channel has no schedule.
```
