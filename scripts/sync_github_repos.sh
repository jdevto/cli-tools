#!/bin/bash

# Function to sync repositories for a GitHub organization or user
sync_github_repos() {
  local github_entity="$1"  # GitHub organization or user name passed as the first argument
  local base_dir="$2"       # Base directory to store repositories passed as the second argument
  local entity_type="orgs"  # Default entity type is set to organization

  # Validate input arguments
  if [ -z "$github_entity" ]; then
    echo "Error: No GitHub entity provided. Please specify an organization or user."
    exit 1
  fi

  if [ -z "$base_dir" ]; then
    echo "Error: No base directory provided. Please specify a valid path."
    exit 1
  fi

  # Determine if the entity is an organization or a user by checking the respective GitHub API endpoints
  if curl -s "https://api.github.com/orgs/$github_entity" | jq -e 'has("login") and .login == "'$github_entity'"' > /dev/null 2>&1; then
    entity_type="orgs"
  elif curl -s -o /dev/null -w "%{http_code}" "https://api.github.com/users/$github_entity" | grep -q '^200$'; then
    entity_type="users"
  else
    echo "Error: $github_entity is neither a valid GitHub organization nor a user."
    exit 1
  fi

  # Ensure the base directory exists
  mkdir -p "$base_dir/$github_entity"

  # Function to clone or update a repository
  sync_repo() {
    local repo_url="$1"  # Repository URL passed to the function
    local repo_name=$(basename "$repo_url" .git)  # Extract repository name from the URL
    local repo_dir="$base_dir/$github_entity/$repo_name"  # Full path to the local repository

    # Check if the repository directory exists locally
    if [ -d "$repo_dir" ]; then
      echo "Updating $repo_name..."
      git -C "$repo_dir" pull --rebase  # Update the repository using git pull with rebase
    else
      echo "Cloning $repo_name..."
      git clone "$repo_url" "$repo_dir"  # Clone the repository if it does not exist
    fi
  }

  # Fetch and synchronize repositories for the given entity
  echo "Fetching repositories for $entity_type: $github_entity..."
  local page=1  # Start with the first page of results

  # Loop through paginated results to fetch all repositories
  while true; do
    # Fetch repository data using the GitHub API
    repos=$(curl -s "https://api.github.com/$entity_type/$github_entity/repos?per_page=100&page=$page")

    # Validate if the response contains an array
    if ! echo "$repos" | jq -e 'type == "array"' > /dev/null 2>&1; then
      echo "Error: Unable to fetch repositories. Check your API rate limits or credentials."
      exit 1
    fi

    # Extract repository SSH URLs
    repo_urls=$(echo "$repos" | jq -r '.[].ssh_url')

    # Exit the loop if no repositories are found
    [ -z "$repo_urls" ] && break

    # Iterate over each repository URL and sync it
    for repo_url in $repo_urls; do
      sync_repo "$repo_url"
    done

    ((page++))  # Increment the page number for the next iteration
  done
}

# Check if arguments are provided and run the script
if [ "$#" -lt 2 ]; then
  echo "Usage: $0 <GitHub_Entity> <Base_Directory>"
  exit 1
fi

# Pass arguments to the function
sync_github_repos "$1" "$2"
