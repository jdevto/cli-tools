# cli-tools

Command-line interface tools/scripts

## Table of Contents

- [sync_github_repos.sh](#sync_github_repossh)

## Scripts

### sync_github_repos.sh

This script allows you to clone or update all repositories for a GitHub organization or user.

#### Usage

```bash
./sync_github_repos.sh <GitHub_Entity> <Base_Directory>
```

- **GitHub_Entity**: The name of the GitHub organization or user.
- **Base_Directory**: The directory where repositories will be stored.

#### Example

To clone or update all repositories for a GitHub organization `jdevto` into the current directory:

```bash
./sync_github_repos.sh jdevto .
```

To sync repositories into a specific directory:

```bash
./sync_github_repos.sh jdevto /path/to/directory
```

To run directly without cloning the repository:

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/sync_github_repos.sh) jdevto .
```
