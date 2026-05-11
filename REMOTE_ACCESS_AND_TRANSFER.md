# Remote Access and Data Transfer for AWS Research Computing

> **Side document for the Research Computing AWS Workshop.**
> This covers SSH connection (including Jupyter port forwarding) and data transfer tools for moving data to/from S3 and EC2.
>
> **The workshop uses EC2 Instance Connect (no key pair needed) and S3 as the primary data layer.** The tools here are for researchers who want direct SSH access or prefer specific transfer tools — use whichever fits your existing workflow.

---

## Quick Decision Guide

| Your situation | Recommended tool |
|----------------|-----------------|
| I want a terminal on my EC2 instance (no key pair) | **EC2 Instance Connect** — browser-based, see QUICK_REFERENCE.md |
| I want SSH access with a key pair | **SSH** — see below |
| I want to run Jupyter on EC2 | **SSH with port forwarding** — see below |
| I code in VS Code and want a file browser on EC2 | **VS Code Remote SSH** (with key pair) |
| I use HPC and already have rclone | **rclone** — works exactly the same with S3 |
| I prefer a GUI (Mac or Windows) | **Cyberduck** — free, drag-and-drop |
| I'm on Windows and want a GUI | **WinSCP** — free, S3 support in v6+ |
| I need fast parallel transfers (large datasets) | **rclone** with `--transfers 16` |
| I just need a quick file copy | **AWS CLI** `aws s3 cp` — already installed |

---

## Note on SSH Key Pairs

The workshop uses **EC2 Instance Connect** (browser-based terminal, no key pair needed).

Tools that connect **directly to EC2** — VS Code Remote SSH, SCP, rsync — require a **key pair**. If you want to use these, create a key pair at EC2 → Key Pairs → Create key pair, then reference it when launching your instance.

**S3 tools** (rclone, Cyberduck, WinSCP, AWS CLI) use your **AWS credentials**, not a key pair. They connect to S3 directly — not to the EC2 instance. This is the recommended approach: put data in S3, pull it to EC2 from there.

---

## SSH Connection

**Requires a key pair.** If you launched without one, use EC2 Instance Connect instead (see QUICK_REFERENCE.md).

### Fix key permissions (required — SSH will refuse if too open)
```bash
chmod 400 ~/.ssh/your-key.pem
```

### Connect
```bash
ssh -i ~/.ssh/your-key.pem ec2-user@PUBLIC_IP
```

### Get your instance's public IP
```bash
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=research-compute-01" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text
```

### Jupyter port forwarding

Run Jupyter on the instance, access it in your local browser. **Port 8888 does not need to be open in your security group** — the tunnel carries it through port 22 (SSH).

**Step 1: Install JupyterLab** (on the instance, before setting up the tunnel)
```bash
# Requires miniforge — if not installed, see the workshop CURRICULUM.md Lab 1 section
source $HOME/miniforge3/bin/activate
mamba install -y jupyterlab    # ~60 seconds
```

**Step 2: Connect with port forwarding** (from your local terminal)
```bash
ssh -i ~/.ssh/your-key.pem -L 8888:localhost:8888 ec2-user@PUBLIC_IP
```

**Step 3: Start Jupyter** (in the SSH session on the instance)
```bash
jupyter lab --no-browser --port 8888
```

**Step 4: Open in your browser**
```
http://localhost:8888
```
Copy the token from the terminal output if prompted for a password.

> 💡 The `-L 8888:localhost:8888` flag tunnels port 8888 through the SSH connection. Your security group only needs port 22 open — opening 8888 is unnecessary and less secure.

### Windows users

Use **Git Bash** or **WSL** — the commands above work as-is. If using PuTTY, convert your `.pem` to `.ppk` format with PuTTYgen first.

---

## rclone

**Best for**: Anyone coming from HPC who already uses rclone for other storage systems (Google Drive, Globus, SFTP). Cross-platform. Extremely fast with parallelism flags.

**Full S3 configuration reference**: https://rclone.org/s3/

### Install

```bash
# macOS (Homebrew)
brew install rclone

# Linux / WSL
curl https://rclone.org/install.sh | sudo bash

# Windows: download installer from https://rclone.org/downloads/
```

### Configure for S3

```bash
rclone config
```

- `n` → new remote
- Name: `aws-s3`
- Storage type: `s3` (Amazon S3 Compliant Storage Providers)
- Provider: `AWS`
- Credentials: `Enter AWS credentials in the next step`
- Region: `us-west-2`
- Leave endpoint blank → press Enter

Or configure directly (using your default AWS credentials):

```bash
# Use your default AWS profile — no separate rclone config needed if credentials are set
rclone ls s3://rcws-yourname-0302/
```

### Common Commands

```bash
# List bucket contents
rclone ls s3://rcws-yourname-0302/

# Upload a file
rclone copy dataset.tar.gz s3://rcws-yourname-0302/datasets/

# Upload a directory (sync — only copies new/changed files)
rclone sync /local/data/ s3://rcws-yourname-0302/data/ --progress

# Download a file
rclone copy s3://rcws-yourname-0302/results/results.csv ./

# Parallel upload (much faster for many small files)
rclone copy /local/data/ s3://rcws-yourname-0302/data/ \
    --transfers 16 \
    --checkers 16 \
    --progress
```

### Why rclone is great for research

- If you already use rclone for Globus, Google Drive, or your institution's storage — same commands, just `s3://` prefix
- `--transfers 16` flag makes large dataset uploads dramatically faster
- Works on all platforms including HPC login nodes
- Handles S3 multipart upload automatically for large files

---

## Cyberduck (Mac & Windows)

**Best for**: Researchers who prefer a GUI. Free, actively maintained, native S3 support.

### Install

Download from: **https://cyberduck.io/download/**
(Free — ignore "Donate" prompts)

### Connect to S3

1. Open Cyberduck → click **Open Connection**
2. From the dropdown, select **Amazon S3**
3. Enter your AWS credentials:
   - **Access Key ID**: from `aws configure get aws_access_key_id`
   - **Secret Access Key**: from `aws configure get aws_secret_access_key`
4. Click **Connect**

You'll see all your S3 buckets. Navigate into `rcws-yourname-0302/`.

### Usage

- **Drag files** from Finder/Explorer into Cyberduck to upload
- **Double-click** to download files to your local machine
- Right-click → **Get Info** to see file size, last modified
- Right-click → **Copy URL** to get a shareable link (if bucket is public)

### Bookmarks

Save your S3 connection as a bookmark (Bookmarks → New Bookmark) so you don't re-enter credentials every session.

---

## WinSCP (Windows)

**Best for**: Windows users who want a free GUI with S3 support.

> S3 support requires **WinSCP 6.0 or later** (released 2023). Check Help → About if you're not sure.

### Install

Download from: **https://winscp.net/eng/download.php** (free, open source)

### Connect to S3

1. Open WinSCP → click **New Session**
2. **File protocol**: Amazon S3
3. **Host name**: `s3.amazonaws.com`
4. **Access key ID** and **Secret access key**: your AWS credentials
5. Click **Login**

Navigate to `rcws-yourname-0302/` in the right panel. Drag files from your local drive (left panel) to upload.

### Note for existing WinSCP users

If you previously used WinSCP for SFTP to HPC — this is the same app, just switch protocol to Amazon S3. Your SFTP sessions are unaffected.

---

## VS Code Remote — SSH

**Best for**: Researchers who use VS Code and want to edit files directly on EC2 — not just transfer data.

> **Requires a key pair.** EC2 Instance Connect (browser terminal, no key pair) doesn't support VS Code Remote. If you want VS Code on EC2, create a key pair when launching your instance.

### Setup

1. Install the **Remote - SSH** extension in VS Code
2. Open Command Palette (`Cmd+Shift+P` / `Ctrl+Shift+P`) → **Remote-SSH: Open SSH Configuration File**
3. Add your instance:

```
Host aws-research
    HostName YOUR_PUBLIC_IP
    User ec2-user
    IdentityFile ~/.ssh/your-key.pem
    ServerAliveInterval 60
```

4. Command Palette → **Remote-SSH: Connect to Host** → `aws-research`

VS Code opens a full editor connected to your EC2 instance. You can:
- Browse the remote filesystem in the Explorer panel
- Edit files with full VS Code features (language servers, git, etc.)
- Open terminals inside VS Code (connects to the instance)
- Drag files from your local machine to upload them

### Getting your public IP

```bash
# From CloudShell or your local terminal
aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=research-compute-01" \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text
```

### Key permission (macOS/Linux)

```bash
chmod 400 ~/.ssh/your-key.pem
```

---

## SCP / rsync (Command Line)

**Best for**: Researchers comfortable with the command line who need one-off file transfers.

> **Requires a key pair.** These connect directly to EC2, not to S3.

### SCP (Secure Copy)

```bash
# Upload file to EC2
scp -i ~/.ssh/your-key.pem dataset.tar.gz ec2-user@PUBLIC_IP:~/

# Upload directory to EC2
scp -i ~/.ssh/your-key.pem -r ./analysis/ ec2-user@PUBLIC_IP:~/

# Download file from EC2
scp -i ~/.ssh/your-key.pem ec2-user@PUBLIC_IP:~/results.csv ./

# Download directory from EC2
scp -i ~/.ssh/your-key.pem -r ec2-user@PUBLIC_IP:~/results/ ./
```

### rsync (more efficient for large directories)

```bash
# Upload directory (only copies new/changed files)
rsync -avz -e "ssh -i ~/.ssh/your-key.pem" \
    ./local-data/ ec2-user@PUBLIC_IP:~/data/

# Download directory
rsync -avz -e "ssh -i ~/.ssh/your-key.pem" \
    ec2-user@PUBLIC_IP:~/results/ ./results/
```

### Why S3 is usually better

For research workflows, prefer S3 over direct SCP/rsync:
- **Persistent**: S3 data survives instance termination; EBS data doesn't
- **Shareable**: Multiple instances can access the same S3 data
- **No key pair required**: Works from any machine with AWS credentials
- **Cheaper for long-term storage**: S3 Standard is $0.023/GB/month vs EBS at $0.08/GB/month

---

## Moving Data Between HPC and AWS

If you have data on a campus HPC system and want to move it to S3:

### Option 1: Via your laptop

```bash
# Download from HPC to laptop (using scp or rsync with HPC credentials)
# Substitute <user>@<your-hpc-login-node> with your institution's HPC details
scp -r <user>@<your-hpc-login-node>:/projects/yourgroup/data/ ./

# Upload from laptop to S3 (AWS CLI or rclone)
aws s3 sync ./data/ s3://rcws-yourname-0302/data/
```

### Option 2: rclone on the HPC login node

Many HPC clusters have rclone installed or you can install it in your home directory:

```bash
# Install rclone in your home directory (no root needed)
curl https://rclone.org/install.sh | bash --no-sudo

# Configure rclone with your AWS credentials
rclone config

# Transfer directly from HPC to S3
rclone sync /projects/yourgroup/data/ s3://rcws-yourname-0302/data/ \
    --progress --transfers 8
```

> Check with your HPC team about policies on outbound transfers from login nodes. Some systems prefer a dedicated transfer node (often named something like `xfer.<your-hpc-domain>` or `dtn.<your-hpc-domain>`).

### Option 3: rclone on the HPC transfer node

Many institutions have dedicated transfer/DTN nodes that are better suited for large outbound transfers than login nodes. Check with your HPC team for the hostname.

```bash
# On the HPC transfer node
rclone sync /projects/yourgroup/data/ s3://rcws-yourname-0302/data/ \
    --progress --transfers 16
```

---

## Summary

| Tool | Platform | Connects to | Requires key pair? | Best for |
|------|----------|-------------|-------------------|----------|
| **AWS CLI** | All | S3 | No | Quick one-offs, scripting |
| **rclone** | All | S3 | No | Large datasets, parallelism, HPC |
| **Cyberduck** | Mac, Windows | S3 | No | GUI drag-and-drop |
| **WinSCP** | Windows | S3 or EC2 | No (S3) / Yes (EC2) | Windows GUI |
| **VS Code Remote** | Mac, Windows, Linux | EC2 | Yes | Code editing on EC2 |
| **SCP/rsync** | Mac, Linux, WSL | EC2 | Yes | CLI file transfers to EC2 |

---

**Tip**: For reproducible research, prefer **S3 as the data layer**. Your analysis script on EC2 pulls from S3 (`aws s3 cp`), writes results back to S3 (`aws s3 cp`), and anyone with AWS credentials can access the data — regardless of which instance is running.
