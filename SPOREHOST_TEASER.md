# spore.host Quick Start: A Better Way to Run AWS Research Computing

> **This is a companion document to the main workshop.**
> It covers spore.host (two tools: `truffle` + `spawn`) as a faster alternative to the AWS Console and CLI.
> The main workshop teaches you the fundamentals — this shows you what daily production use looks like.

---

## Why spore.host?

After today's workshop, you know how to:
- Launch instances with `aws ec2 run-instances` (20+ flags)
- Check Spot prices with `aws ec2 describe-spot-price-history`
- Find an AMI with a JMESPath query
- Manage everything region by region

**spore.host wraps all of that into two simple tools:**

| Task | AWS CLI | spore.host |
|------|---------|------------|
| Launch an instance | `aws ec2 run-instances --image-id ami-xxx --instance-type m6a.xlarge --tag-specifications ...` | `spawn --instance-type m6a.xlarge` |
| Find cheapest Spot | `aws ec2 describe-spot-price-history --instance-types m6a.* ... \| jq ...` | `truffle spot "m6a.*" --sort-by-price` |
| See all running instances | Navigate Console region by region | `spawn list` |
| Launch 10 parallel instances | `for i in {1..10}; do aws ec2 run-instances ...; done` | `spawn launch --count 10 --job-array-name my-job` |
| Search by hardware feature | Know AWS naming conventions (p5.48xlarge = H100) | `truffle find h100` |

> "Console for learning. CLI for scripts. **spore.host for real research work.**"

---

## Installation

```bash
# Install on macOS or Linux (Homebrew)
brew install scttfrdmn/tap/truffle
brew install scttfrdmn/tap/spawn

# Verify installation
truffle --version
spawn --version
```

**Windows**: install via [Scoop](https://scoop.sh): `scoop bucket add scttfrdmn https://github.com/scttfrdmn/scoop-bucket && scoop install truffle spawn`. Or download the Windows binaries from the [latest release](https://github.com/scttfrdmn/spore-host/releases/latest) and add them to your PATH.

**Linux (.deb/.rpm)**: download the per-tool `.deb` or `.rpm` from the [latest release](https://github.com/scttfrdmn/spore-host/releases/latest) and install with `dpkg -i` / `rpm -i`.

> See [spore.host](https://spore.host) for the latest install instructions and additional optional tools (`lagotto`, `spore-host-mcp`).

---

## The 5 Essential Commands

### 1. `truffle find` — Natural Language Instance Search

No more memorizing AWS instance type names. Search by hardware features in plain English.

```bash
# No AWS account needed for these!
truffle find h100                    # Finds p5.48xlarge (H100 GPU)
truffle find "large amd"             # Find large AMD-based instances
truffle find "efa graviton"          # Find Graviton with high-speed networking
truffle find "100gbps intel"         # Find high-bandwidth Intel instances
truffle find "64 core"               # Find 64-vCPU instances
```

**Key benefit**: Works without AWS credentials — explore what's available before you even have an account.

---

### 2. `truffle spot` — Find Cheapest Spot Prices

```bash
# Compare Spot prices across instance families
truffle spot "m6a.*" --sort-by-price

# GPU Spot pricing
truffle spot "p3.*" --sort-by-price

# Specific instance in a region
truffle spot m6a.xlarge --region us-west-2

# Combine: find cheapest Spot and pipe to launch
truffle spot "m7i.*" --sort-by-price | spawn --spot --ttl 8h
```

---

### 3. `spawn` — Interactive Launch Wizard

For beginners: just press Enter through the defaults.

```
$ spawn

🧙 spawn Setup Wizard

Region [us-west-2]: ↵
Instance type [m6a.xlarge]: ↵
TTL (auto-terminate) [8h]: ↵
Spot instance [no]: ↵

Launching...

🎉 Instance ready in 60 seconds!
Name: research-01

Cost estimate: ~$0.17/hour
Auto-terminates in 8 hours (NO SURPRISE BILLS!)
```

**No JSON. No 20-step process. No key pair management.**

```bash
# Or launch directly (skip the wizard)
spawn --instance-type m6a.xlarge --ttl 8h

# With Spot (70% savings)
spawn --instance-type m6a.xlarge --spot --ttl 8h

# Stop (not terminate) after TTL -- keeps data!
spawn --instance-type m6a.xlarge --ttl 8h --on-complete stop

# GPU with auto-stop (never pay for idle GPU time again)
spawn --instance-type p3.2xlarge --ttl 24h --on-complete stop
```

**Connect to your instance**:
```bash
spawn connect research-01    # By name — no SSH keys needed
spawn connect i-0abc123      # Or by ID
```

---

### 4. `spawn list` — See Everything You're Running

The "did I leave something running?" safety net.

```bash
# See all instances across ALL regions at once
spawn list

# Output:
# NAME         ID         TYPE        REGION     STATE    COST/HR  TTL    TOTAL
# research-01  i-0abc123  m6a.xlarge  us-west-2  running  $0.17    6h     $0.34
# genomics-gpu i-0def456  p3.2xlarge  us-east-1  running  $3.06    2h     $6.12
#
# Total: $3.23/hour

# Stop to save money (keeps data, zero compute charge)
spawn stop i-0abc123

# Start later
spawn start i-0abc123

# Hibernate (saves RAM state too)
spawn hibernate i-0abc123

# Extend TTL if you need more time
spawn extend i-0abc123 2h
```

**Run `spawn list` daily to avoid surprise bills.**

---

### 5. `spawn launch --count N` — Parallel Instances (Workshop 2!)

The feature that makes parallel research computing practical.

```bash
# Check quota before launching (important for GPU families)
truffle quotas --family Standard
truffle quotas --family P  # For p-family (GPU)

# Launch 10 instances as a job array
spawn launch --count 10 --job-array-name my-analysis \
  --instance-type c7i.xlarge --spot --ttl 24h

# Each instance gets:
# - $SPORE_RANK: unique rank (0-9) — use for data partitioning
# - DNS: my-analysis.job resolves to all instances
# - Automatic peer discovery

# Manage the entire array as one unit
spawn list --job-array-name my-analysis    # Status of all 10
spawn stop --job-array-name my-analysis    # Stop all 10
spawn start --job-array-name my-analysis   # Resume all 10
```

**This is covered in depth in Workshop 2 (spore.host for Production).**

---

## Quick Reference

### truffle

```bash
truffle find <natural language>     # Search by hardware description
truffle search <pattern>            # Regex/wildcard search (e.g., "p5\.*", "m7i.large")
truffle spot <pattern>              # Show Spot prices
truffle spot <pattern> --sort-by-price | spawn --spot --ttl Xh  # Pipe to launch
truffle quotas --family Standard    # Check vCPU quotas
truffle quotas --family P           # Check GPU quotas
truffle quotas --family P --request # Request quota increase
truffle capacity --instance-types p3.2xlarge  # Check capacity
```

### spawn

```bash
spawn                               # Interactive wizard
spawn --instance-type TYPE          # Direct launch
spawn --instance-type TYPE --spot --ttl Xh  # Spot with auto-terminate
spawn --ttl Xh --on-complete stop   # Auto-stop (not terminate) after TTL
spawn list                          # All instances, all regions
spawn list --state stopped          # Stopped instances only
spawn stop i-xxx                    # Stop instance (save $)
spawn start i-xxx                   # Start stopped instance
spawn connect i-xxx                 # Connect (no SSH keys!)
spawn hibernate i-xxx               # Hibernate
spawn extend i-xxx 2h               # Extend TTL
spawn launch --count N --job-array-name NAME --instance-type TYPE --ttl Xh
```

---

## Real Research Examples

### Batch Genomics (10 samples in parallel)

```bash
# Check quota, launch 10 instances
truffle quotas --family Standard
spawn launch --count 10 --job-array-name variant-calling \
  --instance-type c7i.xlarge --spot --ttl 24h \
  --user-data '#!/bin/bash
  RANK=$SPORE_RANK   # 0-9, use for sample selection
  # Download sample from S3
  aws s3 cp s3://my-data/sample_${RANK}.fastq ./
  # Run variant calling
  gatk HaplotypeCaller -I sample_${RANK}.fastq -O output_${RANK}.vcf
  # Upload results
  aws s3 cp output_${RANK}.vcf s3://my-results/
  shutdown -h now'

# Monitor progress
spawn list --job-array-name variant-calling
```

**Cost**: ~$0.10/sample (Spot) vs $0.30/sample (On-Demand) = 70% savings for 10 samples

---

### GPU Training with Auto-Stop

```bash
# No surprise bills — auto-stops when TTL expires
truffle quotas --family P
spawn --instance-type p3.2xlarge --ttl 24h --on-complete stop

# Connect and run training
spawn connect research-01
# ... run your training job ...

# When done, instance auto-stops (NOT terminates)
# Your model checkpoint is safe on the EBS volume
# Restart later: spawn start research-01
```

---

### Multi-Region Data Staging (99% cost savings)

When distributing the same dataset to many instances, data transfer costs add up:
- Without staging: 100GB → 10 instances = 1TB transfer = **$90**
- With staging: 100GB staged once, instances read locally = **$2**

```bash
# Stage dataset once (Workshop 2 topic)
spawn stage upload dataset.tar.gz /mnt/data/dataset.tar.gz --regions us-west-2

# Launch instances — staged data is pre-mounted
spawn launch --count 10 --job-array-name analysis \
  --instance-type c7i.xlarge --spot --ttl 24h

# Clean up staged data when done
spawn stage delete dataset.tar.gz
```

---

## When to Use What

| Task | Use |
|------|-----|
| **Learning AWS concepts** | AWS Console + CLI (today's workshop!) |
| **Daily research work** | spore.host (`spawn` + `truffle`) |
| **Production pipelines** | spore.host (Workshop 2) |
| **Exploring instance options** | `truffle find` (no AWS account needed!) |
| **One-off edge cases** | AWS CLI |
| **Automation/infrastructure** | AWS CLI or Terraform |

---

## Cost Safety Features

| Feature | How |
|---------|-----|
| **Auto-terminate** | `spawn --ttl 8h` — kills instance after 8 hours |
| **Auto-stop** | `spawn --ttl 8h --on-complete stop` — stops but keeps data |
| **See what you're paying** | `spawn list` — shows cost/hr and total for every instance |
| **Quota checking** | `truffle quotas --family Standard` — before launching large arrays |
| **Spot instances** | `spawn --spot` — 50-90% discount for interruptible workloads |

---

## Getting More

- **GitHub**: https://github.com/scttfrdmn/spore-host
- **Workshop 2**: spore.host for Production Research Computing
  - Job arrays at scale (10-20 instances, quota-dependent)
  - Data staging (99% transfer cost savings)
  - Real workflows: genomics, imaging, distributed ML
  - Fault tolerance with Spot + checkpointing

---

*spore.host is a complement to AWS, not a replacement. Learn the fundamentals first — then use these tools to work faster.*
