# get_youtube_upcoming.py

This script fetches a YouTube channel's upcoming scheduled live streams from the YouTube Data API v3 and prints the raw JSON list of video objects to stdout. Uses only the Python standard library (no pip install required).

## Usage

```bash
./get_youtube_upcoming.py [--channel-handle HANDLE] [--channel-id ID]
```

Set `YOUTUBE_API_KEY` in the environment. Optionally set `YOUTUBE_CHANNEL_ID` to skip handle lookup.

- **--channel-handle**: YouTube channel handle (e.g. `AWSEventsChannel`). Default: `AWSEventsChannel`. Ignored if `--channel-id` or `YOUTUBE_CHANNEL_ID` is set.
- **--channel-id**: YouTube channel ID (e.g. `UCxxxxxx`). If set, overrides env and handle.

## Example Usage

Default channel (AWSEventsChannel):

```bash
export YOUTUBE_API_KEY="your_api_key"
./get_youtube_upcoming.py
```

By channel handle:

```bash
./get_youtube_upcoming.py --channel-handle AWSEventsChannel
```

By channel ID (saves quota by skipping channels.list):

```bash
./get_youtube_upcoming.py --channel-id UCxxxxxxxxxxxxxxxxxx
```

## Running Without Cloning

```bash
python3 <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/get_youtube_upcoming.py)
```

Set `YOUTUBE_API_KEY` in the environment first. Add `--channel-handle` or `--channel-id` after the URL if needed.

## Verification

Check that the script prints valid JSON (array of video objects, or `[]` if no upcoming streams):

```bash
./get_youtube_upcoming.py | jq .
```

## Output

- **Success**: Raw JSON array to stdout (video objects from YouTube API `videos.list`).
- **Errors**: Error message to stderr and non-zero exit code.

## How to get the API key

YouTube Data API v3 uses an API key (no OAuth required for read-only operations like this script).

1. **Google Cloud project**
   - Go to [Google Cloud Console](https://console.cloud.google.com/).
   - Create a project or select an existing one.

2. **Enable the API**
   - Open **APIs & Services** → **Library**.
   - Search for **YouTube Data API v3** and click **Enable**.

3. **Create credentials**
   - Open **APIs & Services** → **Credentials**.
   - Click **Create credentials** → **API key**.
   - Copy the key and set it as `YOUTUBE_API_KEY` (e.g. `export YOUTUBE_API_KEY="AIza..."`).

4. **Optional: restrict the key**
   - In Credentials, click the new API key.
   - Under **API restrictions**, restrict to **YouTube Data API v3** to limit use to this API only.

## Quota and free account limits

- **Default quota**: The YouTube Data API v3 gives **10,000 quota units per day** on the free tier. Quota resets at **midnight Pacific Time**.
- **Cost per run of this script**:
  - If using **channel handle**: `channels.list` = 1 unit, `search.list` = 100 units, `videos.list` = 1 unit → **about 102 units per run**.
  - If using **channel ID** (e.g. `--channel-id` or `YOUTUBE_CHANNEL_ID`): no `channels.list` → **about 101 units per run**.
- So on a free account you can run the script roughly **~100 times per day** (or fewer if you use other API calls elsewhere).
- **Quota exceeded**: If you exceed the daily quota, the API returns HTTP 403 with a message about quota. You must wait until the next day or request a quota increase (Google may require an audit for more than 10,000 units/day).
- **Reference**: [Quota calculator](https://developers.google.com/youtube/v3/determine_quota_cost) and [YouTube Data API overview](https://developers.google.com/youtube/v3/getting-started).

## Required environment variables

- **YOUTUBE_API_KEY** — YouTube Data API v3 API key (see [How to get the API key](#how-to-get-the-api-key) above).

## Optional environment variables

- **YOUTUBE_CHANNEL_ID** — YouTube channel ID. If set, the script skips resolving the channel handle and saves 1 quota unit per run.

## Exit codes

- **0** — Success; JSON printed to stdout.
- **2** — Config/usage error (missing `YOUTUBE_API_KEY`).
- **3** — Auth error (invalid key, 403 Forbidden).
- **4** — Not found (channel not found).
- **5** — Runtime/API error (quota exceeded, 5xx, or other API errors).

## Use as a library

```python
from get_youtube_upcoming import get_upcoming_for_channel

# Use YOUTUBE_API_KEY from env; default channel AWSEventsChannel
videos = get_upcoming_for_channel()

# By handle
videos = get_upcoming_for_channel(channel_handle="AWSEventsChannel")

# By channel ID (saves quota)
videos = get_upcoming_for_channel(channel_id="UCxxxxxxxxxxxxxxxxxx")
# Returns list of video objects; [] if no upcoming streams.
```
