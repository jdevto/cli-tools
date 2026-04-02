# sync_github_repos.sh

Clone or update all repositories for a GitHub organization or user into `<Base_Directory>/<entity>/<repo>/`. New repos are cloned with `git clone`; existing directories get `git pull --rebase`.

## Usage

```bash
./sync_github_repos.sh <GitHub_Entity> <Base_Directory>
```

- **GitHub_Entity**: Organization or user login (e.g. `myorg`, `octocat`).
- **Base_Directory**: Root directory for clones; the script creates `<Base_Directory>/<GitHub_Entity>/`.

```bash
./sync_github_repos.sh --help
```

## Why private repositories were missing

The script lists repositories through the GitHub REST API.

- **Without a token**, only **public** repositories are returned. Private repos never appear in the list, so they are never cloned or updated.
- **With a user name**, `GET /users/{user}/repos` (the unauthenticated path) also only includes **public** repos for that user, even if you use a browser while logged in.

With **`GITHUB_TOKEN`** or **`GH_TOKEN`** set, the script uses **`GET /user/repos`** (authenticated) and keeps repositories whose **`owner.login`** matches the entity you passed. That includes **private** repos your account can access for that owner (your own user or an organization).

## Optional environment variables

| Variable | Purpose |
|----------|---------|
| `GITHUB_TOKEN` or `GH_TOKEN` | Bearer token for `api.github.com`. Use a classic PAT with `repo` ([token settings](https://github.com/settings/tokens)), or a fine-grained token with read access to the relevant repositories/organizations. |
| `GIT_SYNC_CONTINUE_ON_ERROR` | Set to `1` to log `git` failures and continue with the next repository instead of exiting on the first error. |

Example with GitHub CLI:

```bash
export GITHUB_TOKEN="$(gh auth token)"
./sync_github_repos.sh myorg /path/to/directory
```

## SSH and private clones

The API returns **`ssh_url`** URLs. Listing private repos succeeds only with a token; **cloning** them still requires Git to authenticate to GitHub (SSH key added to your account, or another configured SSH identity). Check with:

```bash
ssh -T git@github.com
```

If SSH is not set up, clones of private repositories will fail with permission errors even when the token is correct.

## Example usage

```bash
./sync_github_repos.sh jdevto .
```

```bash
./sync_github_repos.sh jdevto /path/to/directory
```

## Running without cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/sync_github_repos.sh) jdevto .
```

For private repositories, export `GITHUB_TOKEN` or `GH_TOKEN` in the same shell before running this one-liner.

## Troubleshooting

- **No private repos**: Export `GITHUB_TOKEN` or `GH_TOKEN` with access to those repositories (and use the correct organization or user name as `GitHub_Entity`).
- **Listed but clone fails**: Configure SSH for GitHub or use a key that has access to that org/user’s private repos.
- **API errors / rate limit**: Unauthenticated requests are limited to 60 requests per hour per IP; a token raises the limit substantially.
- **`jq` / `curl` / `git` not found**: Install them with your package manager; the script checks for these commands up front.
