# Mycelium Quick Reference Guide

**Print this page for quick reference during your research!** 📄

---

## Installation

```bash
# macOS
brew install scttfrdmn/tap/mycelium

# Linux/WSL
curl -sSL https://raw.githubusercontent.com/scttfrdmn/mycelium/main/install.sh | bash

# Verify
truffle --version
spawn --version
```

---

## truffle - Discovery Commands

### Natural Language Search (No AWS Credentials Needed!)

```bash
# Find instances by description
truffle find h100                    # Find H100 GPUs → p5.48xlarge
truffle find "large amd"             # Find large AMD instances
truffle find "efa graviton"          # Find Graviton with EFA
truffle find "100gbps intel"         # High-bandwidth instances
truffle find "32gb memory"           # 32GB RAM instances
truffle find "8 gpu nvidia"          # 8 NVIDIA GPUs
truffle find "local nvme"            # Instances with NVMe storage
```

### Regex Pattern Search

```bash
# Search by instance type pattern
truffle search m7i.large             # Exact match
truffle search "p5\..*"              # All p5 instances (regex)
truffle search "c7i\.(large|xlarge)" # c7i.large or c7i.xlarge
```

### Spot Price Discovery

```bash
# Check Spot prices (all regions auto-detected)
truffle spot t3.medium

# Find cheapest Spot across all regions
truffle spot "c7i.*" --sort-by-price

# Filter by specific regions
truffle spot "p3.2xlarge" --regions us-west-2,us-east-1 --sort-by-price

# Compare multiple instance types
truffle spot "c7i.xlarge,m7i.xlarge,r7i.xlarge" --sort-by-price
```

### Capacity Checking

```bash
# Check if instances are available
truffle capacity --instance-types p3.2xlarge

# Check multiple types
truffle capacity --instance-types "p3.2xlarge,p3.8xlarge"

# Check in specific regions
truffle capacity --instance-types g5.xlarge --regions us-west-2,us-east-1

# GPU-only capacity
truffle capacity --gpu-only
```

### Quota Management

**Understanding AWS Quotas**:
- AWS limits vCPUs per account to prevent accidental bills
- **Standard** (C, M, R, T): Usually 32-256 vCPUs
- **P** (GPU p3, p4, p5): Usually **0 vCPUs** ← Must request!
- **G** (GPU g4dn, g5, g6): 0-128 vCPUs
- **Inf** (Inferentia): Usually **0 vCPUs** ← Must request!

**Quota Check (truffle)**:
```bash
# View all quota families
truffle quotas

# Output shows table:
# Family | Type | Quota | Usage | Available | Status
# Standard | On-Demand | 256 vCPUs | 45 | 211 vCPUs | ✅ OK
# P | On-Demand | 0 vCPUs | 0 | 0 vCPUs | ❌ Zero

# Check specific family
truffle quotas --family Standard     # Standard instance quota
truffle quotas --family P            # GPU (P family) quota
truffle quotas --family G            # G family GPU quota
truffle quotas --family Inf          # Inferentia quota

# Multi-region comparison
truffle quotas --regions us-west-2,us-east-1,eu-west-1
```

**Request Quota Increase**:
```bash
# Generate quota increase request commands
truffle quotas --family P --request

# Output:
# 📝 Quota Increase Request Commands
#
# aws service-quotas request-service-quota-increase \
#   --service-code ec2 \
#   --quota-code L-417A185B \
#   --desired-value 192 \
#   --region us-west-2
#
# Copy/paste command, typically approved in 24-48 hours
# GPU quotas require business justification

# Check request status
aws service-quotas list-requested-service-quota-change-history-by-quota \
  --service-code ec2 \
  --quota-code L-417A185B \
  --region us-west-2
```

**Integrated Quota + Launch Workflow**:
```bash
# Step 1: Check quota
truffle quotas --family P

# If quota = 0:
# ❌ P quota is 0 vCPUs - request increase first
truffle quotas --family P --request
# Copy/paste generated AWS CLI command, wait 24-48 hours

# Step 2: Check capacity
truffle capacity --instance-types p5.48xlarge

# Step 3: Launch with confidence
spawn launch --instance-type p5.48xlarge --spot --ttl 8h ...
```

**💡 Critical**: ALWAYS check `truffle quotas` before launching 20+ instances!

---

## spawn - Launch & Manage Commands

### Quick Launch

```bash
# Wizard mode (interactive)
spawn

# Direct launch with defaults
spawn --instance-type t3.medium

# With TTL (auto-termination)
spawn --instance-type t3.medium --ttl 8h

# Spot instance
spawn --instance-type c7i.xlarge --spot --ttl 4h

# Auto-STOP (not terminate) - keeps data!
spawn --instance-type t3.xlarge --ttl 8h --on-complete stop

# Auto-HIBERNATE - saves RAM state
spawn --instance-type p3.2xlarge --ttl 24h --on-complete hibernate

# Specify region
spawn --instance-type t3.medium --region us-west-2 --ttl 6h
```

### Choosing the Right Execution Mode

| Mode | Use When | Best For |
|------|----------|----------|
| **Regular Launch** | Interactive work, wizard mode | Exploration, development |
| **One-Shot (TTL)** | Auto-terminate after time | Quick experiments, cost control |
| **Job Arrays** | Parallel across many instances | Genomics, image analysis, sweeps |
| **Batch Queues** | Sequential pipeline on one instance | ETL, CI/CD, ML pipelines |
| **Detached Mode** | Long jobs + need to disconnect | Overnight runs, unstable connections |
| **Scheduled** | Run at specific time | Nightly jobs, off-peak execution |

---

### Launch from truffle (The Power Combo!)

```bash
# Find cheapest Spot, launch immediately
truffle spot "m7i.xlarge" --sort-by-price | spawn --ttl 8h

# Natural language to launch
truffle find "large amd" | spawn --spot --ttl 4h
```

### Monitoring (Cost Awareness!)

```bash
# See everything you're running (all regions!)
spawn list

# Shows: name, type, region, state, cost/hr, TTL, total cost
# Pro tip: Run daily to avoid surprise bills!

# Filter by state
spawn list --state running           # Only running
spawn list --state stopped           # Only stopped (costing $0/hr)

# Filter by job array
spawn list --job-array-name genomics-pipeline

# Filter by region
spawn list --region us-west-2
```

### Lifecycle Management

```bash
# Stop instance (save 99% - keeps data!)
spawn stop i-0abc123

# Start stopped instance
spawn start i-0abc123

# Hibernate (saves RAM state too)
spawn hibernate i-0abc123

# Extend TTL (need more time)
spawn extend i-0abc123 2h            # Add 2 hours
spawn extend i-0abc123 6h            # Add 6 hours

# Terminate (delete everything - use AWS CLI or let TTL expire)
aws ec2 terminate-instances --instance-ids i-0abc123 --region us-west-2
```

### Connection

```bash
# Connect by instance ID
spawn connect i-0abc123

# Connect by name
spawn connect research-01

# Connect to specific rank in job array
spawn connect genomics-pipeline-0    # Rank 0
spawn connect genomics-pipeline-42   # Rank 42
```

---

## Batch Mode - Parallel Computing Made Easy

### Launch Batch

```bash
# Launch 20 instances in batch mode
spawn launch --count 20 --job-array-name my-pipeline \
  --instance-type c7i.xlarge --spot --ttl 24h \
  --user-data '#!/bin/bash
  # Automatic environment variables:
  # $SPORE_RANK = 0, 1, 2, ... 19
  # $SPORE_SIZE = 20
  # $SPORE_JOB_ARRAY_NAME = my-pipeline

  RANK=$SPORE_RANK
  echo "Processing task $RANK of $SPORE_SIZE"

  # Your processing here...
  aws s3 cp s3://data/sample_${RANK}.txt ./
  process_sample.sh sample_${RANK}.txt
  aws s3 cp output_${RANK}.txt s3://results/
  '
```

**💡 Scaling Up**: ALWAYS check quota first!
```bash
# Step 1: Check quota
truffle quotas --family Standard

# Step 2: Calculate needed vCPUs
# Example: 50 × c7i.xlarge (4 vCPUs each) = 200 vCPUs needed

# Step 3: Verify you have enough available
# If quota is 256 and you're using 45, you have 211 available
# 200 needed < 211 available ✅ Can launch!

# Step 4: Scale up if you have quota
spawn launch --count 50 --job-array-name large-batch \
  --instance-type c7i.xlarge --spot --ttl 24h ...

# If insufficient quota, request increase first
truffle quotas --family Standard --request
```

**⚠️ Common Mistake**: Launching without checking quota
```bash
# BAD - might fail with VcpuLimitExceeded
spawn launch --count 100 --instance-type c7i.2xlarge ...

# GOOD - check first
truffle quotas --family Standard  # Check available vCPUs
# 100 × c7i.2xlarge (8 vCPUs) = 800 vCPUs needed
# If available < 800, adjust count or request increase
```

### Manage Batches

```bash
# List instances in batch
spawn list --job-array-name my-pipeline

# Stop entire batch
spawn stop --job-array-name my-pipeline

# Start entire batch
spawn start --job-array-name my-pipeline

# Extend TTL for entire batch
spawn extend --job-array-name my-pipeline 4h

# Terminate entire batch (use AWS CLI)
aws ec2 terminate-instances --instance-ids $(spawn list --job-array-name my-pipeline --json | jq -r '.[].instance_id') --region us-west-2
```

### Batch Mode Features

**Automatic DNS**:
- All instances in batch share DNS: `my-pipeline.compute`
- Resolves to all instances in the batch
- Perfect for distributed computing (MPI, etc.)

**Peer Discovery**:
```bash
# In user data script:
spore-rank              # Get my rank (0-19 for 20 instances)
spore-size              # Get total size (20)
spore-is-rank-0         # Am I rank 0? (coordinator)
spore-peers             # Get list of peer IPs

if spore-is-rank-0; then
  echo "I am the coordinator!"
fi
```

**Real Research Example - Genomics Pipeline** (20 samples):
```bash
spawn launch --count 20 --job-array-name variant-calling \
  --instance-type c7i.2xlarge --spot --ttl 12h \
  --user-data '#!/bin/bash
  RANK=$SPORE_RANK
  aws s3 cp s3://genomes/sample_${RANK}.bam ./
  bcftools mpileup -f ref.fa sample_${RANK}.bam | \
    bcftools call -mv -O v -o ${RANK}.vcf
  aws s3 cp ${RANK}.vcf s3://results/
  shutdown -h now
  '
```

---

## Batch Queues - Sequential Pipelines

**Use When**: Multi-step pipeline on ONE instance with job dependencies

### Create Pipeline Configuration

```bash
# Create JSON config file
cat > ml-pipeline.json <<'EOF'
{
  "queue_id": "ml-pipeline",
  "jobs": [
    {
      "job_id": "preprocess",
      "command": "python preprocess.py --input data/ --output preprocessed/",
      "timeout": "30m"
    },
    {
      "job_id": "train",
      "command": "python train.py --data preprocessed/ --model model.pkl",
      "depends_on": ["preprocess"],
      "timeout": "2h",
      "retry": {"max_attempts": 2, "backoff": "exponential"}
    },
    {
      "job_id": "evaluate",
      "command": "python evaluate.py --model model.pkl --output metrics.json",
      "depends_on": ["train"],
      "timeout": "15m"
    },
    {
      "job_id": "export",
      "command": "aws s3 cp model.pkl s3://models/final/",
      "depends_on": ["evaluate"],
      "timeout": "10m"
    }
  ]
}
EOF
```

### Launch Batch Queue

```bash
# Launch instance with batch queue
spawn launch --instance-type c7i.2xlarge --spot --ttl 4h \
  --batch-queue ml-pipeline.json

# Monitor progress (pass instance ID, not queue name)
spawn queue status <instance-id>

# Download results when complete
spawn queue results <queue-id> --output ./results/

# Results also automatically collected in S3
```

### Key Features

- ✅ Automatic dependency resolution
- ✅ Retry failed jobs with backoff strategies
- ✅ Results collected to S3 automatically
- ✅ State persists across instance restarts
- ✅ Multiple retry strategies: exponential, linear, constant

**💡 Use Cases**: ETL pipelines, CI/CD, multi-step ML workflows

---

## Detached Mode - Disconnect-Proof Execution

**Use When**: Long-running jobs where you need to close your laptop or have unstable connections

### Launch in Detached Mode

```bash
# Launch parameter sweep in detached mode
spawn launch --params sweep.yaml --max-concurrent 10 --detach

# Output:
# ✅ Sweep sweep-20260129-140530 launched in detached mode
# ✅ Lambda will manage execution
# ✅ Safe to close terminal now

# CLI exits immediately - sweep continues in the cloud!
```

### Monitor Detached Sweep

```bash
# Check status from ANY machine, anytime
spawn status --sweep-id sweep-20260129-140530

# Output shows: total jobs, completed, running, pending, failed

# Cancel if needed
spawn cancel --sweep-id sweep-20260129-140530
```

### How It Works

- Lambda self-reinvokes every 13 minutes
- State persists in DynamoDB
- Survives: laptop sleep, network drops, CLI crashes, terminal closes
- Cost: ~$0.005 per sweep (Lambda + DynamoDB)

**💡 Use Cases**: Overnight runs, multi-hour sweeps, unstable connections, laptop workflows

---

## Scheduled Executions - Run Later

**Use When**: Need to execute workloads at specific times or on a recurring schedule

### One-Time Execution

```bash
# Run at specific date/time
spawn schedule create --params training.yaml \
  --at "2026-01-30T02:00:00" \
  --timezone "America/Denver"

# Output:
# ✅ Scheduled execution: sched-ml-training-20260130
# ✅ Will start at: 2026-01-30 02:00:00 MST
```

### Recurring Execution

```bash
# Run every night at 2 AM
spawn schedule create --params nightly-analysis.yaml \
  --cron "0 2 * * *" \
  --timezone "America/Denver" \
  --name "nightly-genomics"

# Weekly on Sundays at 3 AM
spawn schedule create --params weekly-backup.yaml \
  --cron "0 3 * * 0" \
  --timezone "America/New_York" \
  --name "weekly-backup"
```

### Manage Schedules

```bash
# List all schedules
spawn schedule list

# View schedule details
spawn schedule describe nightly-genomics

# Pause temporarily
spawn schedule pause nightly-genomics

# Resume
spawn schedule resume nightly-genomics

# Cancel schedule
spawn schedule cancel nightly-genomics

# View schedule details (includes recent executions)
spawn schedule describe nightly-genomics
```

### Cron Expression Examples

```bash
# Every day at 2 AM
--cron "0 2 * * *"

# Every Monday at 9 AM
--cron "0 9 * * 1"

# Every 6 hours
--cron "0 */6 * * *"

# First day of month at midnight
--cron "0 0 1 * *"

# Weekdays at 8 AM
--cron "0 8 * * 1-5"
```

**💡 Use Cases**: Nightly data processing, weekly model retraining, off-peak execution for cheaper Spot prices

**Timezone Support**: 600+ timezones, automatic DST handling

---

## Data Staging - 95% Cost Savings!

### Why Stage Data?

**Problem**: Distribute 50GB to 20 instances
- **Without staging**: 20 × 50GB = 1TB transfer = **$90** 💸
- **With staging**: Stage once = **$4.50** ✅ (95% savings!)

**Scales with instance count**: 50 instances = $225 traditional vs $4.50 staging!

### Stage Data

```bash
# Stage file in one region
spawn stage upload dataset.tar.gz /mnt/data/dataset.tar.gz \
  --regions us-west-2

# Stage in multiple regions (multi-region workflows)
spawn stage upload reference.tar.gz /mnt/data/reference.tar.gz \
  --regions us-west-2,us-east-1,eu-west-1

# List staged data
spawn stage list

# Output shows:
# REGION      FILE              SIZE     COST    UPLOADED
# us-west-2   dataset.tar.gz    100GB    $9.00   2024-12-15
```

### Use Staged Data

```bash
# Launch instances - data automatically available!
spawn launch --count 100 --job-array-name analysis \
  --instance-type c7i.xlarge --spot --ttl 24h \
  --region us-west-2 \
  --user-data '#!/bin/bash
  # Data already at /mnt/data/dataset.tar.gz - NO download!
  tar -xzf /mnt/data/dataset.tar.gz -C /data/

  # Your processing here...
  process_data.sh /data/
  '
```

### Cleanup Staged Data

```bash
# Delete when done
spawn stage delete dataset.tar.gz

# Delete from specific region
spawn stage delete dataset.tar.gz --region us-west-2
```

### When to Use Staging

**✅ Use staging when**:
- Distributing >50GB to 10+ instances
- Multi-region deployments
- Frequently reused reference datasets (genomes, models, databases)
- Large container images

**❌ Don't use staging when**:
- One-off data transfers (just use S3)
- Data changes frequently
- Small files (<10GB)

---

## Real Research Workflow Examples

### Genomics Variant Calling Pipeline

```bash
# 0. CHECK QUOTA FIRST! (Critical step)
truffle quotas --family Standard
# Need: 20 × c7i.2xlarge (8 vCPUs) = 160 vCPUs
# Verify available > 160

# 1. Stage reference genome (one-time)
spawn stage upload human_g1k_v37.fasta.tar.gz /mnt/data/reference.tar.gz \
  --regions us-west-2

# 2. Launch batch of 20 instances
spawn launch --count 20 --job-array-name variant-calling \
  --instance-type c7i.2xlarge --spot --ttl 2h \
  --region us-west-2 \
  --user-data '#!/bin/bash
  set -e
  tar -xzf /mnt/data/reference.tar.gz -C /data/
  SAMPLE=$SPORE_RANK
  aws s3 cp s3://1000genomes/sample_${SAMPLE}.bam ./
  samtools index sample_${SAMPLE}.bam
  bcftools mpileup -f /data/human_g1k_v37.fasta sample_${SAMPLE}.bam | \
    bcftools call -mv -O z -o sample_${SAMPLE}.vcf.gz
  aws s3 cp sample_${SAMPLE}.vcf.gz s3://results/vcf/
  shutdown -h now
  '

# 3. Monitor
spawn list --job-array-name variant-calling

# 4. Cleanup
spawn stage delete human_g1k_v37.fasta.tar.gz
```

**Cost**: ~$3.20 (compute) + $0.27 (staging) vs $5.40 (traditional)
**Time**: 30 minutes (all parallel!)

**💡 Scaling**: Have 50 samples and quota? Change `--count 20` to `--count 50`!

---

### Microscopy Image Analysis

```bash
# 0. Check quota (20 × r7i.xlarge = 80 vCPUs)
truffle quotas --family Standard

# 1. Find cheapest Spot
truffle spot "r7i.xlarge" --regions us-west-2 --sort-by-price

# 2. Launch analysis (20 batches)
spawn launch --count 20 --job-array-name image-analysis \
  --instance-type r7i.xlarge --spot --ttl 4h \
  --user-data '#!/bin/bash
  BATCH=$SPORE_RANK
  aws s3 sync s3://microscopy/batch_${BATCH}/ /data/images/
  cellprofiler -c -r -p analysis.cppipe -i /data/images/ -o /data/output/
  python quantify.py --input /data/output/ --output results_${BATCH}.csv
  aws s3 cp results_${BATCH}.csv s3://results/
  shutdown -h now
  '
```

**Cost**: ~$6 (Spot) vs $20 (On-Demand) = 70% savings

---

### Distributed ML Training (PyTorch DDP)

```bash
# 0. CHECK GPU QUOTA! (P family often 0 by default)
truffle quotas --family P
# Need: 8 × p3.2xlarge (8 vCPUs each) = 64 vCPUs
# If quota = 0, request increase first!

# 1. Stage training data
spawn stage upload imagenet-train.tar.gz /mnt/data/training.tar.gz \
  --regions us-east-1

# 2. Launch distributed training
spawn launch --count 8 --job-array-name ml-training \
  --instance-type p3.2xlarge --spot --ttl 30h \
  --region us-east-1 \
  --user-data '#!/bin/bash
  export MASTER_ADDR=$(spore-peers | head -n1)
  export MASTER_PORT=29500
  export WORLD_SIZE=$SPORE_SIZE
  export RANK=$SPORE_RANK

  tar -xzf /mnt/data/training.tar.gz -C /data/

  python -m torch.distributed.launch \
    --nproc_per_node=1 \
    --nnodes=$WORLD_SIZE \
    --node_rank=$RANK \
    --master_addr=$MASTER_ADDR \
    --master_port=$MASTER_PORT \
    train.py --epochs 100
  '

# Monitor
spawn list --job-array-name ml-training

# Extend if needed
spawn extend --job-array-name ml-training 6h
```

**Cost** (24-hour training):
- On-Demand: $587
- Spot: $176 (70% savings, but may be interrupted)
- Capacity Block: ~$350 (40% savings, guaranteed capacity!)

---

## Capacity Blocks - Reserved GPU Capacity

### Find Capacity Blocks

```bash
# Show available Capacity Blocks (ML training instances)
truffle capacity --blocks --instance-types p5.48xlarge --regions us-east-1

# Show all GPU Capacity Blocks across regions
truffle capacity --blocks --gpu-only

# Output shows: instance, region, start time, duration, price, total cost, savings %
```

### Reserve Capacity Block and Launch

```bash
# Reserve via AWS Console: EC2 → Capacity Reservations → Capacity Blocks
# Or via AWS CLI:

# Step 1: Find available Capacity Block offerings
aws ec2 describe-capacity-block-offerings \
  --instance-type p5.48xlarge \
  --capacity-duration-hours 48 \
  --region us-east-1

# Step 2: Purchase using the offering ID from Step 1
aws ec2 purchase-capacity-block \
  --capacity-block-offering-id cb-0abc123def456 \
  --instance-platform Linux/UNIX \
  --region us-east-1

# Launch using reservation (on the start date/time)
spawn launch --count 1 --instance-type p5.48xlarge \
  --region us-east-1 \
  --use-reservation \
  --ttl 48h \
  --user-data '#!/bin/bash
  python train_model.py --epochs 100
  '
```

### When to Use Capacity Blocks

**✅ Use Capacity Blocks when**:
- Large ML training you can schedule in advance
- Need guaranteed GPU availability
- Want savings but can't tolerate Spot interruptions
- Training runs >4 hours

**❌ Don't use when**:
- Need instances immediately (use Spot)
- Short runs (<4 hours)
- Can tolerate Spot interruptions

**Cost Comparison** (48-hour H100 training):
- On-Demand: $98.32/hr × 48hr = **$4,719**
- Capacity Block: ~$68/hr × 48hr = **$3,264** (31% savings, guaranteed!)
- Spot: ~$29/hr × 48hr = **$1,392** (70% savings, but may interrupt!)

**💡 Best Practice**: Book 1-2 weeks ahead for best pricing!

---

## Cost Optimization Checklist

1. **✅ Always check Spot prices first**
   ```bash
   truffle spot "c7i.*" --sort-by-price
   ```

2. **✅ Use TTL + auto-stop for development**
   ```bash
   spawn --instance-type t3.xlarge --ttl 8h --on-complete stop
   ```

3. **✅ Stage reusable data**
   ```bash
   spawn stage upload reference.tar.gz /mnt/data/reference.tar.gz
   ```

4. **✅ Right-size instances**
   ```bash
   truffle find "32gb memory compute optimized"
   ```

5. **✅ Monitor daily**
   ```bash
   spawn list  # See what's running and costing money
   ```

6. **✅ Use job arrays for batch workloads**
   ```bash
   spawn launch --count 100 --job-array-name my-pipeline ...
   ```

---

## Fault Tolerance with Spot

Spot instances can be interrupted. Use checkpointing!

```bash
spawn launch --count 100 --job-array-name fault-tolerant \
  --instance-type c7i.xlarge --spot --ttl 48h \
  --user-data '#!/bin/bash
  RANK=$SPORE_RANK
  CHECKPOINT="s3://bucket/checkpoint_${RANK}.json"

  # Resume from checkpoint if exists
  if aws s3 ls $CHECKPOINT; then
    aws s3 cp $CHECKPOINT ./checkpoint.json
    START=$(jq -r .step checkpoint.json)
  else
    START=0
  fi

  # Process with checkpointing
  for step in $(seq $START 1000); do
    process_step $step

    # Checkpoint every 100 steps
    if [ $((step % 100)) -eq 0 ]; then
      echo "{\"step\": $step}" > checkpoint.json
      aws s3 cp checkpoint.json $CHECKPOINT
    fi
  done

  # Cleanup
  aws s3 rm $CHECKPOINT
  '
```

If interrupted, relaunch → resumes from checkpoint!

---

## Multi-Region Workflows

```bash
# Stage data in multiple regions
spawn stage upload dataset.tar.gz /mnt/data/dataset.tar.gz \
  --regions us-west-2,us-east-1,eu-west-1,ap-southeast-1

# Launch in each region
spawn launch --count 50 --job-array-name analysis-us-west \
  --instance-type c7i.xlarge --spot --region us-west-2 ...

spawn launch --count 50 --job-array-name analysis-eu \
  --instance-type c7i.xlarge --spot --region eu-west-1 ...

# Monitor all regions (automatic!)
spawn list
```

---

## Troubleshooting

### Can't find instance type
```bash
# Use natural language
truffle find "large amd with 32gb memory"

# Or search by pattern
truffle search "m7.*"
```

### Insufficient capacity
```bash
# Check before launching
truffle capacity --instance-types p3.2xlarge

# Find alternative regions (use -r flag)
truffle capacity --instance-types p3.2xlarge -r us-west-2,us-east-1,eu-west-1
```

### Quota exceeded

**Error**: `VcpuLimitExceeded` or `InstanceLimitExceeded`

**Cause**: Not enough vCPU quota available

**Solution**:
```bash
# Step 1: Check current quota usage
truffle quotas --family Standard

# Step 2: See which instances are using quota
spawn list --state running

# Step 3: Options:
# Option A: Stop some instances to free quota
spawn stop i-0abc123
# (To terminate: aws ec2 terminate-instances --instance-ids i-0def456 --region us-west-2)

# Option B: Request quota increase
truffle quotas --family Standard --request
# Copy/paste generated AWS command
# Wait 24-48 hours for approval

# Option C: Use smaller instance types
# Example: Use c7i.large (2 vCPUs) instead of c7i.xlarge (4 vCPUs)
# Can launch 2× as many instances with same quota

# Option D: Try different region
truffle quotas --regions us-west-2,us-east-1,eu-west-1
# Find region with more available quota
```

**Prevention**: Always check quota before launching!
```bash
# Before launching 20 instances:
truffle quotas --family Standard
# Calculate: 20 × instance_vcpus = total_needed
# Verify: total_needed < available
```

### Spot instance interrupted
- Use checkpointing (see Fault Tolerance section above)
- Consider On-Demand for critical workloads
- Or use Spot with auto-retry

### Job array not starting
```bash
# Check quotas first
truffle quotas --family Standard

# Check capacity
truffle capacity --instance-types c7i.xlarge

# Verify user data script (test on single instance first)
spawn --instance-type c7i.xlarge --ttl 1h --user-data '...'
```

---

## Best Practices

### Daily Routine
```bash
# Morning check
spawn list

# See what's costing money
spawn list --state running
```

### Development Workflow
```bash
# Launch with auto-stop (not terminate)
spawn --instance-type t3.xlarge --ttl 8h --on-complete stop --idle-timeout 1h

# Stop when leaving for the day
spawn stop my-dev-instance

# Resume next day
spawn start my-dev-instance
```

### Production Workflow
```bash
# Always use Spot when possible
truffle spot "c7i.xlarge" --sort-by-price | spawn --ttl 12h

# Use TTL to prevent runaway costs
spawn --instance-type c7i.xlarge --spot --ttl 12h

# Stage reusable data
spawn stage upload reference.tar.gz /mnt/data/reference.tar.gz

# Use job arrays for batch processing
spawn launch --count 100 --job-array-name batch-job ...
```

---

## Useful Aliases

Add to your `~/.bashrc` or `~/.zshrc`:

```bash
# Quick monitoring
alias what='spawn list'
alias what-running='spawn list --state running'
alias what-stopped='spawn list --state stopped'

# Quick Spot price checking
alias spot-check='truffle spot'

# Find instances
alias aws-find='truffle find'

# Launch with common settings
alias aws-launch='spawn --spot --ttl 8h'
```

---

## Resources

**Documentation**:
- GitHub: https://github.com/scttfrdmn/mycelium
- Installation: https://github.com/scttfrdmn/mycelium#installation
- Examples: https://github.com/scttfrdmn/mycelium/tree/main/examples

**AWS Resources**:
- Cloud Credit for Research: https://aws.amazon.com/government-education/research-and-technical-computing/cloud-credit-for-research/
- GDEW Information: https://aws.amazon.com/government-education/research-and-technical-computing/ (see GDEW section)
- HPC on AWS: https://aws.amazon.com/hpc/

**Community**:
- Slack: [Ask for invite]
- GitHub Issues: https://github.com/scttfrdmn/mycelium/issues
- Discussions: https://github.com/scttfrdmn/mycelium/discussions

---

**Print this page for quick reference! 📄**
