# Xray Server Deployment Guide

This guide provides instructions for deploying the Xray network proxy tool on a newly created VPS. This version does not use a control panel and operates directly via the Xray command line, making it suitable for VPS machines with limited resources.

## Prerequisites

1. **Domain Setup (Optional):**
   - Create a new domain prefix pointing to the public IPv4/IPv6 address of the VPS.

2. **Access the VPS:**
   ```bash
   ssh root@domain.or.ip
   ```

3. **Update the System:**
   ```bash
   sudo apt update && sudo apt upgrade
   ```
   **Note:** If you encounter any conflicts related to SSH configuration during the upgrade, keep the pre-installed configuration provided by the VPS vendor to avoid connection issues in the future.

## Install Xray Server

Run the following command to install the Xray server:
```bash
bash -c "$(curl -L https://github.com/XTLS/Xray-install/raw/main/install-release.sh)" @ install
```

Once installed, the Xray server will be registered and started automatically in `systemctl`.

Verify the status of the Xray service:
```bash
systemctl status xray
```

## Important Configuration Steps

1. **Save the Output of the Following Commands:**
   - Generate a UUID:
     ```bash
     xray uuid
     ```
   - Generate an X25519 private key:
     ```bash
     xray x25519
     ```

   Save the results of these commands for later use.

2. **Edit the Default Configuration File:**
   Open the Xray configuration file using `vim` or `nano`:
   ```bash
   vim /usr/local/etc/xray/config.json
   ```

   Refer to the following templates for configuration examples. Ensure that the UUID and private key generated earlier are correctly configured:
   - [VLESS-TCP-XTLS-Vision-REALITY Config Example](https://github.com/XTLS/Xray-examples/blob/main/VLESS-TCP-XTLS-Vision-REALITY/config_server.jsonc)
   - [Integrated Examples for Xray](https://github.com/lxhao61/integrated-examples/blob/main/Xray(VLESS%2BVision%2BREALITY)/xray.jsonc)

## Restart Xray After Configuration Changes

After making any changes to the configuration file, restart the Xray service:
```bash
systemctl restart xray
```

Check the status to ensure the service is running correctly:
```bash
systemctl status xray
```