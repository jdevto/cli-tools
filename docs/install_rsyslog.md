# **install_rsyslog.sh**

This script installs, uninstalls, or configures `rsyslog` on **Ubuntu, Red Hat, Fedora, Debian, and CentOS**.

## **Usage**

```bash
./install_rsyslog.sh [install|uninstall] [--configure]
```

- **install** (default): Installs `rsyslog`.
- **uninstall**: Removes `rsyslog` from the system.
- **--configure**: (Optional) Configures `rsyslog` to exclude debug logs.

## **Example Usage**

### **Install rsyslog**

```bash
./install_rsyslog.sh install
```

### **Install and Configure rsyslog**

```bash
./install_rsyslog.sh install --configure
```

This will install and configure `rsyslog` in one step.

### **Uninstall rsyslog**

```bash
./install_rsyslog.sh uninstall
```

## **Running Without Cloning**

```bash
bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_rsyslog.sh) install
```

## **Verification**

After installation or configuration, check the `rsyslog` service status:

```bash
systemctl status rsyslog
```

If installed correctly, the service should be **active (running).**

### **Check the rsyslog Configuration**

```bash
cat /etc/rsyslog.conf
```

This file contains the logging configuration.

## **Supported Operating Systems**

- **Ubuntu** (`apt`)
- **Debian** (`apt`)
- **Red Hat / Fedora** (`dnf`)
- **CentOS** (`yum`)

## **Error Handling**

- If `rsyslog` is **already installed**, the script **skips reinstallation**.
- If an **unsupported OS** is detected, the script exits with an error message.
- If **rsyslog configuration is missing**, `--configure` will apply default settings.

## **Cleanup**

- Temporary installation files are **automatically removed** after execution.
- The script uses **trap cleanup EXIT** to ensure cleanup even if interrupted.
