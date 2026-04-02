#!/bin/bash

set -euo pipefail

SYNC_GH_REPOS_URLS_TMP=""

cleanup() {
  [[ -n "${SYNC_GH_REPOS_URLS_TMP}" ]] && rm -f "${SYNC_GH_REPOS_URLS_TMP}"
}
trap cleanup EXIT

usage() {
  cat <<'EOF'
Usage: sync_github_repos.sh <GitHub_Entity> <Base_Directory>

Clone or update all GitHub repositories for an organization or user under:
  <Base_Directory>/<GitHub_Entity>/<repo_name>/

Environment variables:
  GITHUB_TOKEN, GH_TOKEN  Bearer token for api.github.com. Required to list and
                          sync private repositories (and to avoid low unauthenticated
                          rate limits). Create a fine-grained or classic PAT with
                          repository read access for the orgs/users you sync.
  GIT_SYNC_CONTINUE_ON_ERROR  If set to 1, log failures and continue with other repos
                              instead of exiting on the first git error.

Git access: clone URLs use SSH (ssh_url). Ensure your SSH key is added to GitHub
(ssh -T git@github.com) or clones of private repos will still fail after they are listed.

Examples:
  sync_github_repos.sh myorg ~/code/github
  GITHUB_TOKEN="$(gh auth token)" sync_github_repos.sh myorg ~/code/github
EOF
  exit 1
}

require_cmds() {
  local missing=()
  local c
  for c in curl jq git; do
    command -v "$c" &>/dev/null || missing+=("$c")
  done
  if ((${#missing[@]})); then
    echo "Error: missing required commands: ${missing[*]}"
    exit 1
  fi
}

# Curl args for GitHub API (optional bearer token).
github_api_curl() {
  local -a args=(-sS -H "Accept: application/vnd.github+json" -H "X-GitHub-Api-Version: 2022-11-28")
  if [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]]; then
    args+=(-H "Authorization: Bearer ${GITHUB_TOKEN:-$GH_TOKEN}")
  fi
  curl "${args[@]}" "$@"
}

# True if the response body is a JSON object with a "message" field (typical API error).
github_api_is_error_object() {
  local body="$1"
  echo "$body" | jq -e 'type == "object" and has("message")' >/dev/null 2>&1
}

# Paginated repo listing: with token, use /user/repos and filter by owner (covers private
# repos). Without token, use /orgs/.../repos or /users/.../repos (public only).
fetch_repo_ssh_urls_page() {
  local entity="$1"
  local entity_type="$2" # "orgs" or "users" — only used when no token
  local page="$3"
  local body

  if [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]]; then
    body=$(github_api_curl "https://api.github.com/user/repos?per_page=100&page=${page}&sort=full_name")
  else
    body=$(github_api_curl "https://api.github.com/${entity_type}/${entity}/repos?per_page=100&page=${page}")
  fi

  if github_api_is_error_object "$body"; then
    echo "GitHub API error: $(echo "$body" | jq -r '.message')" >&2
    exit 1
  fi

  if ! echo "$body" | jq -e 'type == "array"' >/dev/null 2>&1; then
    echo "Error: unexpected GitHub API response (expected a JSON array). Check credentials and rate limits." >&2
    exit 1
  fi

  # Used by the caller to paginate correctly when filtering (authenticated path) yields no URLs
  # for a page that is still full from the API.
  _SYNC_GH_API_PAGE_LEN=$(echo "$body" | jq 'length')

  if [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]]; then
    echo "$body" | jq -r --arg ent "$entity" \
      '.[] | select(.owner.login | ascii_downcase == ($ent | ascii_downcase)) | .ssh_url'
  else
    echo "$body" | jq -r '.[].ssh_url'
  fi
}

sync_github_repos() {
  local github_entity="$1"
  local base_dir="$2"
  local entity_type="orgs"

  if [[ "$github_entity" == "-h" || "$github_entity" == "--help" ]]; then
    usage
  fi

  require_cmds

  if [[ -z "$github_entity" || -z "$base_dir" ]]; then
    usage
  fi

  # Resolve entity as org or user (public metadata); used only for the unauthenticated API path.
  if [[ -z "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]]; then
    local org_body
    org_body=$(github_api_curl "https://api.github.com/orgs/${github_entity}")
    if echo "$org_body" | jq -e --arg ent "$github_entity" 'has("login") and (.login | ascii_downcase == ($ent | ascii_downcase))' >/dev/null 2>&1; then
      entity_type="orgs"
    elif [[ $(github_api_curl -o /dev/null -w "%{http_code}" "https://api.github.com/users/${github_entity}") == "200" ]]; then
      entity_type="users"
    else
      echo "Error: ${github_entity} is neither a valid GitHub organization nor a user (or the API request failed)." >&2
      exit 1
    fi
  fi

  mkdir -p "${base_dir}/${github_entity}"

  sync_repo() {
    local repo_url="$1"
    local repo_name
    repo_name=$(basename "$repo_url" .git)
    local repo_dir="${base_dir}/${github_entity}/${repo_name}"

    if [[ -n "${GIT_SYNC_CONTINUE_ON_ERROR:-}" && "${GIT_SYNC_CONTINUE_ON_ERROR}" == "1" ]]; then
      if [[ -d "$repo_dir" ]]; then
        echo "Updating ${repo_name}..."
        git -C "$repo_dir" pull --rebase || echo "Warning: pull failed for ${repo_name}" >&2
      else
        echo "Cloning ${repo_name}..."
        git clone "$repo_url" "$repo_dir" || echo "Warning: clone failed for ${repo_name}" >&2
      fi
      return 0
    fi

    if [[ -d "$repo_dir" ]]; then
      echo "Updating ${repo_name}..."
      git -C "$repo_dir" pull --rebase
    else
      echo "Cloning ${repo_name}..."
      git clone "$repo_url" "$repo_dir"
    fi
  }

  if [[ -n "${GITHUB_TOKEN:-${GH_TOKEN:-}}" ]]; then
    echo "Fetching repositories for ${github_entity} (authenticated API; includes private repos you can access)..."
  else
    echo "Fetching repositories for ${entity_type}: ${github_entity} (unauthenticated: public repos only)..."
    echo "Tip: set GITHUB_TOKEN or GH_TOKEN to sync private repositories." >&2
  fi

  SYNC_GH_REPOS_URLS_TMP=$(mktemp)
  local page=1

  while true; do
    # Redirect to a file so fetch_repo_ssh_urls_page runs in this shell (not a subshell) and
    # _SYNC_GH_API_PAGE_LEN remains visible for pagination when the jq filter returns no lines.
    fetch_repo_ssh_urls_page "$github_entity" "$entity_type" "$page" >"$SYNC_GH_REPOS_URLS_TMP"

    local url
    while IFS= read -r url || [[ -n "$url" ]]; do
      [[ -z "$url" ]] && continue
      sync_repo "$url"
    done <"$SYNC_GH_REPOS_URLS_TMP"

    if ((_SYNC_GH_API_PAGE_LEN < 100)); then
      break
    fi
    ((page++)) || true
  done

  rm -f "$SYNC_GH_REPOS_URLS_TMP"
  SYNC_GH_REPOS_URLS_TMP=""
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
fi

if [[ "$#" -lt 2 ]]; then
  usage
fi

sync_github_repos "$1" "$2"
