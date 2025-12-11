# install_s3_mount.sh

This script installs, configures, and manages AWS Mountpoint for Amazon S3 on RPM-based Linux distributions (Amazon Linux, RHEL, CentOS, Fedora). AWS Mountpoint allows you to mount an S3 bucket as a local filesystem.

## Usage

```bash
./install_s3_mount.sh [install|uninstall]
```

- **install** (default): Installs AWS Mountpoint and configures the S3 mount.
- **uninstall**: Removes the S3 mount configuration (does not remove AWS Mountpoint package).

## Required Environment Variables

- **S3_BUCKET_NAME**: Name of the S3 bucket to mount (required for install)
- **MOUNT_USER**: User to set ownership for the mount (required for install)

## Optional Environment Variables

- **MOUNT_POINT**: Mount point directory (default: `/mnt/s3_config`)
- **MOUNTPOINT_VERSION**: Pin specific version or leave empty for latest

## Example Usage

To install S3 mount with default settings:

```bash
S3_BUCKET_NAME=my-bucket MOUNT_USER=ec2-user ./install_s3_mount.sh install
```

To install with a custom mount point:

```bash
S3_BUCKET_NAME=my-bucket MOUNT_POINT=/mnt/my-s3 MOUNT_USER=ubuntu ./install_s3_mount.sh install
```

To install a specific version of AWS Mountpoint:

```bash
S3_BUCKET_NAME=my-bucket MOUNT_USER=ec2-user MOUNTPOINT_VERSION=1.0.0 ./install_s3_mount.sh install
```

To uninstall S3 mount:

```bash
MOUNT_POINT=/mnt/s3_config ./install_s3_mount.sh uninstall
```

## Running Without Cloning

```bash
S3_BUCKET_NAME=my-bucket MOUNT_USER=ec2-user bash <(curl -s https://raw.githubusercontent.com/jdevto/cli-tools/main/scripts/install_s3_mount.sh) install
```

## Verification

After installation, check if AWS Mountpoint is installed:

```bash
mount-s3 --version
```

Check the service status:

```bash
sudo systemctl status s3-mount.service
```

Verify the mount point:

```bash
mountpoint /mnt/s3_config
```

List mounted filesystems:

```bash
df -h | grep s3
```

## Supported Operating Systems

- **Amazon Linux 2023, RHEL 8/9, Fedora** (uses `dnf` for package management)
- **Amazon Linux 2, RHEL 7, CentOS 7** (uses `yum` for package management)

**Note**: AWS Mountpoint is currently only available as RPM packages, so this script supports RPM-based distributions only.

## Supported Architectures

- **x86_64** (amd64)
- **aarch64** (arm64)

## Features

- Automatically detects package manager and operating system
- Installs `wget` as a dependency if not present
- Downloads and installs AWS Mountpoint RPM package
- Creates systemd service for automatic mounting on boot
- Configures mount with read-only access and proper user permissions
- Automatically starts and enables the mount service
- Skips installation if AWS Mountpoint is already installed
- Handles version pinning for reproducible installations

## Error Handling

- If AWS Mountpoint is already installed, the script will skip reinstallation and display the current version.
- If an unsupported OS or architecture is detected, the script exits with an error message.
- The script validates that required environment variables are set before proceeding.
- Service file and binary existence checks are performed before starting the service.
- Missing dependencies are automatically installed.
- User validation ensures the specified mount user exists before configuration.

## Cleanup

- Temporary installation files (`mount-s3.rpm`) are automatically removed after execution.
- The script uses `trap cleanup EXIT` to ensure cleanup even if interrupted.

## Configuration

The script automatically configures the S3 mount with:

- **Systemd service** at `/etc/systemd/system/s3-mount.service`
- **Read-only mount** for safety
- **User permissions** based on the specified `MOUNT_USER`
- **File and directory modes** (0644 for files, 0755 for directories)
- **Automatic mount** on system boot
- **Proper unmount** on service stop

### Configuration Details

- **Mount type**: Read-only (`--read-only`)
- **Allow other users**: Enabled (`--allow-other`)
- **File permissions**: 0644 (readable by all, writable by owner)
- **Directory permissions**: 0755 (readable/executable by all, writable by owner)
- **User/Group**: Set based on `MOUNT_USER` UID/GID
- **Service type**: oneshot with RemainAfterExit

## Service Management

After installation, you can manage the S3 mount service using:

```bash
sudo systemctl start s3-mount.service
sudo systemctl stop s3-mount.service
sudo systemctl restart s3-mount.service
sudo systemctl enable s3-mount.service
sudo systemctl disable s3-mount.service
```

### Service Commands

- **Start**: `sudo systemctl start s3-mount.service`
- **Stop**: `sudo systemctl stop s3-mount.service` (unmounts the bucket)
- **Restart**: `sudo systemctl restart s3-mount.service`
- **Status**: `sudo systemctl status s3-mount.service`
- **Enable**: `sudo systemctl enable s3-mount.service` (mounts automatically on boot)
- **Disable**: `sudo systemctl disable s3-mount.service` (prevents auto-mount on boot)

## Prerequisites

The script automatically installs required dependencies:

- `wget` - for downloading AWS Mountpoint RPM

### AWS Credentials

AWS Mountpoint requires AWS credentials to access S3 buckets. Ensure one of the following is configured:

- **IAM instance role** (recommended for EC2 instances)
- **AWS credentials file** (`~/.aws/credentials`)
- **Environment variables** (`AWS_ACCESS_KEY_ID`, `AWS_SECRET_ACCESS_KEY`)
- **AWS credentials chain** (IAM roles, credentials file, environment variables)

## Troubleshooting

### Common Issues

1. **Service fails to start**: Check logs with `sudo journalctl -u s3-mount.service -f`
2. **Permission denied**: Ensure AWS credentials are properly configured
3. **Bucket not found**: Verify the bucket name is correct and accessible
4. **Mount point busy**: Ensure no processes are using the mount point
5. **User not found**: Verify the `MOUNT_USER` exists on the system

### Logs and Debugging

- **Service logs**: `sudo journalctl -u s3-mount.service`
- **Check if mounted**: `mountpoint /mnt/s3_config` or `df -h | grep s3`
- **Check mount details**: `mount | grep s3`
- **Manual mount test**: `sudo mount-s3 --read-only my-bucket /mnt/test`

### AWS Permissions

The IAM role or user needs the following S3 permissions:

```json
{
  "Version": "2012-10-17",
  "Statement": [
    {
      "Effect": "Allow",
      "Action": [
        "s3:ListBucket",
        "s3:GetObject"
      ],
      "Resource": [
        "arn:aws:s3:::my-bucket",
        "arn:aws:s3:::my-bucket/*"
      ]
    }
  ]
}
```

### Manual Unmount

If the service fails to unmount, you can manually unmount:

```bash
sudo umount /mnt/s3_config
```

### Removing AWS Mountpoint Package

The uninstall script does not remove the AWS Mountpoint package. To remove it:

```bash
# For dnf-based systems
sudo dnf remove mountpoint-s3

# For yum-based systems
sudo yum remove mountpoint-s3
```

## Security Considerations

- **Read-only mount**: The script configures the mount as read-only for safety
- **IAM permissions**: Use least-privilege IAM policies
- **Network security**: Consider VPC endpoints for S3 access to avoid internet traffic
- **User permissions**: Only the specified user and group can write to the mount (if write access is enabled)

## Limitations

- **RPM-only**: AWS Mountpoint is currently only available as RPM packages
- **Read-only**: The script configures read-only mounts by default
- **Network dependency**: Requires network connectivity to S3
- **Performance**: File operations may be slower than local filesystems due to network latency
