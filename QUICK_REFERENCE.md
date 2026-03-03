# AWS Research Computing Quick Reference

**⚠️ Windows Users**: These commands use bash syntax. Use Git Bash, WSL, or AWS CloudShell.

**Cross-Platform Note**: Commands use standard bash that works on macOS, Linux, WSL, and Git Bash.

## Essential AWS CLI Commands

### EC2 (Compute)

```bash
# Launch instance
aws ec2 run-instances \
    --image-id ami-xxx \
    --instance-type m6a.xlarge \
    --iam-instance-profile Name=ec2-workshop-role

# List running instances
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].[InstanceId,InstanceType,PublicIpAddress,State.Name]' \
    --output table

# Get public IP
aws ec2 describe-instances \
    --instance-ids i-xxx \
    --query 'Reservations[0].Instances[0].PublicIpAddress' \
    --output text

# Terminate instance
aws ec2 terminate-instances --instance-ids i-xxx

# Terminate ALL instances with specific tag
aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=research-*" "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' --output text)
```

### S3 (Storage)

```bash
# Create bucket
aws s3 mb s3://your-bucket-name --region us-west-2

# Upload file
aws s3 cp file.txt s3://your-bucket-name/

# Upload directory
aws s3 sync /local/dir/ s3://your-bucket-name/remote-dir/

# Download file
aws s3 cp s3://your-bucket-name/file.txt ./

# Download directory
aws s3 sync s3://your-bucket-name/remote-dir/ /local/dir/

# List bucket contents
aws s3 ls s3://your-bucket-name/

# Delete file
aws s3 rm s3://your-bucket-name/file.txt

# Delete all files in bucket
aws s3 rm s3://your-bucket-name/ --recursive

# Delete bucket
aws s3 rb s3://your-bucket-name --force
```

### Cost Management

```bash
# View current month costs
aws ce get-cost-and-usage \
    --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics "BlendedCost" \
    --group-by Type=DIMENSION,Key=SERVICE

# List budgets
aws budgets describe-budgets \
    --account-id $(aws sts get-caller-identity --query Account --output text)
```

---

## Spore.host Quick Commands

### truffle (Discovery)

```bash
# Natural language search (no AWS account needed!)
truffle find h100                    # Find H100 GPUs
truffle find "large amd"             # Find large AMD instances
truffle find "efa graviton"          # Find Graviton with EFA
truffle find "100gbps intel"         # High-bandwidth instances

# Regex pattern search (for power users)
truffle search m7i.large
truffle search "p5\..*"              # All p5 instances

# Check Spot prices
truffle spot m6a.xlarge --region us-west-2

# Find cheapest Spot
truffle spot "m6a.*" --sort-by-price

# Check GPU availability
truffle capacity --gpu-only

# Check quotas
truffle quotas --family Standard
truffle quotas --family P  # GPU quota
```

### spawn (Launch & Manage)

```bash
# Wizard mode (easiest)
spawn

# Direct launch
spawn --instance-type m6a.xlarge --region us-west-2

# With auto-termination (TTL)
spawn --instance-type m6a.xlarge --ttl 8h

# Auto-STOP (not terminate) after TTL - keeps data!
spawn --instance-type m6a.xlarge --ttl 8h --on-complete stop

# Auto-hibernate after TTL - saves RAM too
spawn --instance-type m6a.xlarge --ttl 8h --on-complete hibernate

# See what's running (cost monitoring!)
spawn list                  # All instances, all regions
spawn list --state stopped  # Stopped instances
spawn list --job-array-name compute  # Specific job array

# Shows: name, type, region, state, cost/hr, TTL, total cost
# Pro tip: Run daily to avoid surprise bills!

# Stop/start instances
spawn stop i-0abc123        # Stop (save 99%)
spawn start i-0abc123       # Restart later
spawn hibernate i-0abc123   # Hibernate (save RAM)

# Connect to instance
spawn connect i-0abc123

# Extend TTL
spawn extend i-0abc123 2h

# Spot instance
spawn --instance-type m6a.xlarge --spot --ttl 4h

# From truffle pipe
truffle spot "m6a.xlarge" --sort-by-price | spawn --ttl 2h

# GPU with auto-stop on completion
spawn --instance-type g5.xlarge --ttl 24h --on-complete stop

# Job arrays - launch multiple instances with automatic DNS
spawn launch --count 10 --job-array-name compute \
  --instance-type c7i.xlarge --spot --ttl 24h

# Each instance gets $SPORE_RANK (0-9) and DNS: compute.job
# Manage entire array as one unit:
spawn list --job-array-name compute
spawn stop --job-array-name compute
spawn start --job-array-name compute

# Data staging - save 99% on data transfer costs
spawn stage upload dataset.tar.gz /mnt/data/dataset.tar.gz \
  --regions us-west-2

# List staged data
spawn stage list

# Delete staged data
spawn stage delete dataset.tar.gz

# Example: 100GB to 10 instances
#   Without staging: $90
#   With staging: $2
```

---

## Common Instance Types for Research

| Instance Type | vCPUs | RAM | Use Case | Cost (us-west-2) |
|---------------|-------|-----|----------|------------------|
| **m6a.xlarge** ⭐ | 4 | 16 GB | **Workshop default** — general research workloads | $0.173/hr |
| **m6a.2xlarge** | 8 | 32 GB | Data processing, bioinformatics | $0.346/hr |
| **m7i.2xlarge** | 8 | 32 GB | Memory-intensive (Intel) | $0.4032/hr |
| **c7i.4xlarge** | 16 | 32 GB | Compute-intensive | $0.714/hr |
| **r7i.2xlarge** | 8 | 64 GB | Large datasets in memory | $0.504/hr |
| **g5.xlarge** | 4 | 24 GB | GPU (1× A10G) | $1.006/hr |
| **g5.12xlarge** | 48 | 192 GB | GPU (4× A10G) | $16.288/hr |

💡 **Spot instances**: 50-90% discount, may be interrupted. Requires checkpointing — see curriculum for details.

---

## S3 Storage Classes

| Storage Class | Cost/GB/Month | Retrieval | Use Case |
|---------------|---------------|-----------|----------|
| **S3 Standard** | $0.023 | Instant | Frequently accessed |
| **S3 IA** | $0.0125 | Instant | Infrequently accessed |
| **S3 Glacier IR** | $0.004 | Instant | Archive, occasional access |
| **S3 Glacier** | $0.0036 | 3-5 hours | Long-term archive |
| **S3 Deep Archive** | $0.00099 | 12 hours | Rarely accessed |

---

## Cost Optimization Tips

### 1. Use Spot Instances
```bash
# Save 50-90% for fault-tolerant workloads
truffle spot "m7i.*" --sort-by-price | spawn --spot --ttl 8h
```

### 2. Auto-Terminate with TTL
```bash
# Prevents forgetting to stop instances
spawn --instance-type m6a.xlarge --ttl 4h
```

### 3. S3 Lifecycle Policies
```bash
# Move old data to cheaper storage
aws s3api put-bucket-lifecycle-configuration \
    --bucket your-bucket \
    --lifecycle-configuration file://lifecycle.json
```

### 4. Set Budget Alerts
```bash
# Get notified before overspending
aws budgets create-budget --account-id YOUR_ACCOUNT --budget file://budget.json
```

### 5. Stop (Don't Terminate) for Dev Instances
```bash
# Stopped instances: No compute charge, only storage (~$0.10/GB/month)
aws ec2 stop-instances --instance-ids i-xxx
aws ec2 start-instances --instance-ids i-xxx
```

---

## Connecting to Instances

### EC2 Instance Connect (workshop method — no key pair needed)
```
EC2 → Instances → select instance → Connect → EC2 Instance Connect → Connect
```

### SSH / SCP / rclone / GUI tools (if you created a key pair)

See **REMOTE_ACCESS_AND_TRANSFER.md** — covers SSH connection, key permissions, Jupyter port forwarding, SCP, rsync, VS Code Remote SSH, rclone, and GUI tools (Cyberduck, WinSCP).

---

## Data Transfer

### Small Files (<5GB)
```bash
# To S3 (preferred — data persists independently of the instance)
aws s3 cp file.txt s3://bucket/
aws s3 sync /local/dir/ s3://bucket/dir/
```

### Large Files (5GB-5TB)
```bash
# S3 multipart (automatic with AWS CLI)
aws s3 cp large-file.tar.gz s3://bucket/

# Parallel sync for directories
aws s3 sync /data/ s3://bucket/data/ --progress
```

### Huge Datasets (>5TB)
- **rclone** with `--transfers 16` handles most research-scale transfers efficiently
- For very large or recurring transfers, contact your institution's research computing team — campus HPC often has Globus endpoints or dedicated transfer nodes

---

## Troubleshooting

### Instance Connect Fails
```bash
# 1. Check instance has a public IP (most common cause — must be set at launch)
aws ec2 describe-instances --instance-ids i-xxx \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
# If "None" → terminate and relaunch with Auto-assign public IP = Enable

# 2. Check instance is running
aws ec2 describe-instances --instance-ids i-xxx \
    --query 'Reservations[0].Instances[0].State.Name' --output text

# 3. Check workshop-sg allows port 22
aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=workshop-sg" \
    --query 'SecurityGroups[0].IpPermissions'
```

### Bucket Name Already Exists
```bash
# Add unique suffix
BUCKET_NAME="my-research-$(whoami)-$(date +%s)"
aws s3 mb s3://$BUCKET_NAME
```

### Insufficient Capacity
```bash
# Try different availability zone
aws ec2 run-instances --placement AvailabilityZone=us-west-2b ...

# Or different instance type
truffle spot "m7i.*" --sort-by-price
```

### Quota Exceeded
```bash
# Check current usage
truffle quotas --family Standard

# Request increase (24 hour wait)
# Console: Service Quotas → EC2 → Request increase
```

---

## Resources

### AWS Documentation
- EC2 User Guide: https://docs.aws.amazon.com/ec2/
- S3 User Guide: https://docs.aws.amazon.com/s3/
- Pricing Calculator: https://calculator.aws/

### CU Boulder
- Research Computing: https://www.colorado.edu/rc/

### Spore.host
- GitHub: https://github.com/scttfrdmn/mycelium

### AWS for Research
- Research Credits: https://aws.amazon.com/research-credits/
- AWS HPC: https://aws.amazon.com/hpc/
- Case Studies: https://aws.amazon.com/government-education/research/

---

## Emergency Commands

### Stop All Running Instances
```bash
aws ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
    --query 'Reservations[].Instances[].InstanceId' \
    --output text | \
xargs -n 1 aws ec2 terminate-instances --instance-ids
```

### Delete All S3 Buckets (CAUTION!)
```bash
# List all buckets
aws s3 ls

# Delete specific bucket
aws s3 rb s3://bucket-name --force
```

### Check Current Month Bill
```bash
aws ce get-cost-and-usage \
    --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics "BlendedCost"
```

---

## Keyboard Shortcuts (Console)

- `Ctrl+F` / `Cmd+F`: Search in console
- `G` then `E`: Go to EC2
- `G` then `S`: Go to S3
- `?`: Show keyboard shortcuts

---

**Print this page for quick reference during your research!** 📄
