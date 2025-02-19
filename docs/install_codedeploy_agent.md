# install_codedeploy.sh

This script installs, uninstalls, or registers the AWS CodeDeploy agent on **Ubuntu, Red Hat, Fedora, Debian, and Amazon Linux**.

## Usage

```bash
./install_codedeploy.sh [install|uninstall|register <INSTANCE_NAME>]
```

- **install** (default): Installs the AWS CodeDeploy agent.
- **uninstall**: Removes the AWS CodeDeploy agent from the system.
- **register <INSTANCE_NAME>**: Registers the machine as an on-premise instance in AWS CodeDeploy.

## Example Usage

### Install the CodeDeploy Agent

```bash
./install_codedeploy.sh
```

### Uninstall the CodeDeploy Agent

```bash
./install_codedeploy.sh uninstall
```

### Register a Non-EC2 Instance in CodeDeploy

```bash
./install_codedeploy.sh register MyNonEC2Instance
```

## Running Without Cloning

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_codedeploy.sh) install
```

## Verification

After installation, check the CodeDeploy agent status:

```bash
systemctl status codedeploy-agent
```

If installed correctly, you should see output indicating that the service is **active (running).**

## Supported Operating Systems

- Ubuntu (uses `apt`)
- Debian (uses `apt`)
- Amazon Linux (uses `yum`)
- Red Hat / Fedora (uses `dnf`)

## Error Handling

- If CodeDeploy agent is **already installed**, the script skips reinstallation.
- If an **unsupported OS** is detected, the script exits with an error message.
- If AWS credentials are missing on **non-EC2 instances**, registration will fail.

## Cleanup

- Temporary installation files are **automatically removed** after execution.
- The script uses **trap cleanup EXIT** to ensure cleanup even if interrupted.
