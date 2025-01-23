# cli-tools

Command-line interface tools/scripts

## Table of Contents

- [sync_github_repos.sh](#sync_github_repossh)
- [install_aws_cli.sh](#install_aws_clish)

## Scripts

### sync_github_repos.sh

This script allows you to clone or update all repositories for a GitHub organization or user.

#### Usage

```bash
./sync_github_repos.sh <GitHub_Entity> <Base_Directory>
```

- **GitHub_Entity**: The name of the GitHub organization or user.
- **Base_Directory**: The directory where repositories will be stored.

#### Example Usage

To clone or update all repositories for a GitHub organization `jdevto` into the current directory:

```bash
./sync_github_repos.sh jdevto .
```

To sync repositories into a specific directory:

```bash
./sync_github_repos.sh jdevto /path/to/directory
```

#### Running sync_github_repos.sh Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/sync_github_repos.sh) jdevto .
```

### install_aws_cli.sh

This script installs or uninstalls the AWS CLI on Ubuntu, Red Hat, or Fedora-based systems. The default operation is to install the AWS CLI if no arguments are provided.

#### Installation & Usage

```bash
./install_aws_cli.sh [install|uninstall]
```

- **install** (default): Installs the latest AWS CLI version.
- **uninstall**: Removes the AWS CLI from the system.

#### Installation Example

To install AWS CLI:

```bash
./install_aws_cli.sh
```

To uninstall AWS CLI:

```bash
./install_aws_cli.sh uninstall
```

#### Running install_aws_cli.sh Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_aws_cli.sh) install
```

#### Verification

After installation, check the AWS CLI version:

```bash
aws --version
```

#### Supported Operating Systems

- Ubuntu (uses `apt` for package management)
- Red Hat / Fedora (uses `dnf` for package management)

#### Error Handling

- If AWS CLI is already installed, the script will skip reinstallation.
- If an unsupported OS is detected, the script exits with an error message.

#### Cleanup

- Temporary installation files are automatically removed after execution.
