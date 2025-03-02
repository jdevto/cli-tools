# **install_cloudwatch_agent.sh**

This script installs, uninstalls, or configures the AWS CloudWatch Unified Agent on **Ubuntu, Red Hat, Fedora, Debian, CentOS, and Amazon Linux**.

## **Usage**

```bash
./install_cloudwatch_agent.sh [install|uninstall] [--region <AWS_REGION>]
```

- **install** (default): Installs and configures the AWS CloudWatch Unified Agent.
- **uninstall**: Removes the AWS CloudWatch Unified Agent from the system.
- **--region <AWS_REGION>**: (Optional) Sets the AWS region for CloudWatch (default: `ap-southeast-2`).

## **Example Usage**

### **Install the CloudWatch Unified Agent**

```bash
./install_cloudwatch_agent.sh install
```

### **Install and Override AWS Region**

```bash
./install_cloudwatch_agent.sh install --region ap-southeast-1
```

### **Uninstall the CloudWatch Unified Agent**

```bash
./install_cloudwatch_agent.sh uninstall
```

## **Running Without Cloning**

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_cloudwatch_agent.sh) install
```

## **Verification**

After installation, check the CloudWatch agent status:

```bash
systemctl status amazon-cloudwatch-agent
```

If installed correctly, the service should be **active (running).**

### **Check the CloudWatch Agent Configuration**

```bash
cat /opt/aws/amazon-cloudwatch-agent/etc/amazon-cloudwatch-agent.json
```

This file contains the AWS region and logging configuration.

## **Supported Operating Systems**

- **Amazon Linux** (`yum`)
- **Ubuntu** (`apt`)
- **Debian** (`apt`)
- **Red Hat / Fedora** (`dnf`)
- **CentOS** (`yum`)

## **Error Handling**

- If the **CloudWatch agent is already installed**, the script **skips reinstallation**.
- If an **unsupported OS** is detected, the script exits with an error message.
- If **AWS credentials** are missing, CloudWatch may fail to send logs.

## **Cleanup**

- Temporary installation files are **automatically removed** after execution.
- The script uses **trap cleanup EXIT** to ensure cleanup even if interrupted.
