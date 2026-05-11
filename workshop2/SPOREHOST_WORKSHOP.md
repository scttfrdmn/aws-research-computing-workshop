# spore.host for Research Computing: Production Cloud Workflows

**Workshop Title**: From AWS Fundamentals to Production: spore.host Workshop
**Duration**: 2-3 hours (2 hours core + 30min optional advanced topics)
**Prerequisites**: Completed "Introduction to AWS for Research Computing" workshop OR basic AWS experience
**Target Audience**: Researchers ready to move from learning to production cloud workflows

**Workshop Structure**:
- **Core** (2 hours): Discovery, basic launch modes, job arrays, data staging
- **Advanced** (optional 30-60 min): Batch queues, detached mode, scheduled executions

---

## Workshop Overview

**What You Already Know** (from previous workshop):
- ✅ AWS basics (EC2, S3, IAM)
- ✅ Console navigation
- ✅ AWS CLI commands
- ✅ Cost management concepts
- ✅ Spot instances, tags, lifecycle policies

**What You'll Learn Today**:
- 🚀 Launch instances without memorizing AWS instance types (natural language!)
- 🎯 Find cheapest Spot instances automatically
- 📊 Four powerful execution modes:
  - **Job Arrays**: Parallel processing across multiple instances
  - **Batch Queues**: Sequential pipelines with dependencies on one instance
  - **Detached Mode**: Unattended execution that survives laptop sleep
  - **Scheduled Execution**: Run sweeps at future times (one-time or recurring)
- 💾 Stage data efficiently (95% cost savings on multi-instance distribution)
- 🔄 Monitor and manage instances across all regions with one command
- ⏰ Never forget to terminate instances (TTL + auto-stop)
- 📅 Reserve GPU capacity in advance with Capacity Blocks
- 🧪 Real research workflows (genomics, imaging, ML training)

**Philosophy**: "Console taught you concepts. CLI made them scriptable. **spore.host makes them practical.**"

---

## Installation & Setup (Pre-workshop)

### Install spore.host tools

spore.host packages each tool separately. For this workshop you need `truffle` (discovery) and `spawn` (launch/manage). See [spore.host](https://spore.host) for full install options.

**macOS / Linux (Homebrew)**:
```bash
brew install scttfrdmn/tap/truffle
brew install scttfrdmn/tap/spawn
```

**Linux (.deb / .rpm)**: download the per-tool packages from the [latest release](https://github.com/scttfrdmn/spore-host/releases/latest), then install with `sudo dpkg -i truffle_*.deb spawn_*.deb` or `sudo rpm -i truffle_*.rpm spawn_*.rpm`.

**Windows** (via [Scoop](https://scoop.sh)):
```powershell
scoop bucket add scttfrdmn https://github.com/scttfrdmn/scoop-bucket
scoop install truffle spawn
```

> Optional tools (`lagotto`, `spore-host-mcp`) install the same way — `brew install scttfrdmn/tap/<tool>`. Not required for this workshop.

### Verify Installation

```bash
truffle --version
spawn --version
```

### AWS Credentials

spore.host tools use your existing AWS credentials:
```bash
# AWS SSO (recommended)
aws sso login --profile your-profile

# Or traditional IAM credentials
aws configure
```

**Note**: `truffle find` and `truffle search` work WITHOUT AWS credentials! Perfect for exploring before you even have an account.

---

## Four Execution Modes - Quick Reference

| Mode | Use When | Instances | Jobs | Duration | Example |
|------|----------|-----------|------|----------|---------|
| **Job Arrays** | Parallel processing | Many (20+) | 1 per instance | Any | Process 20 samples in parallel |
| **Batch Queues** | Sequential pipeline | One | Many sequential | Hours | ML pipeline: preprocess → train → eval |
| **Detached Mode** | Long running + disconnect | Any | Any | Hours+ | Overnight hyperparameter sweep |
| **Scheduled** | Run at future time | Any | Any | Any | Nightly training at 2 AM |

**Can combine**: Run detached batch queues on a schedule! 🚀

---

## Part 1: Discovery with truffle (30 minutes)

### 1.1: Natural Language Instance Search (10 min)

**The Problem**: "I need a machine with H100 GPUs, but what's the AWS instance type?"

**Old Way**:
1. Google "AWS H100 instances"
2. Read documentation
3. Find instance family (p5)
4. Check specific types (p5.48xlarge)
5. Hope it's available

**spore.host way**:
```bash
# Natural language search - NO AWS CREDENTIALS NEEDED!
truffle find h100

# Output:
# p5.48xlarge
# - 192 vCPUs
# - 2048 GB RAM
# - 8x NVIDIA H100 GPUs
# - 3200 Gbps network
# - $98.32/hour

# Want something specific?
truffle find "large amd"              # Find large AMD instances
truffle find "efa graviton"           # Graviton with EFA networking
truffle find "100gbps intel"          # High-bandwidth Intel
truffle find "8 gpu nvidia"           # 8 NVIDIA GPUs
truffle find "high memory postgres"   # Memory-optimized for databases
```

**🧪 Lab Exercise**:
1. Find instances for your research workload (use natural language)
2. Find the cheapest instance with 32 GB RAM
3. Find instances with local NVMe storage for fast I/O

---

### 1.2: Spot Price Discovery (10 min)

**Real Research Scenario**: Process 1,000 genomic samples. Cost matters!

```bash
# Find cheapest Spot instances for compute workload
truffle spot "c7i.*" --sort-by-price

# Output shows:
# INSTANCE_TYPE  REGION      SPOT_PRICE  ON_DEMAND  SAVINGS
# c7i.large      us-west-2   $0.0123     $0.0893    86%
# c7i.large      us-east-1   $0.0145     $0.0893    84%
# c7i.xlarge     us-west-2   $0.0246     $0.1786    86%

# Sort to find cheapest option
truffle spot "c7i.*" --sort-by-price

# Check multiple instance types at once
truffle spot "m7i.xlarge,c7i.xlarge,r7i.xlarge" --sort-by-price

# Filter by region
truffle spot "p3.2xlarge" --regions us-west-2,us-east-1
```

**Cost Comparison Example** (20 samples):
- **On-Demand**: 20 samples × $0.1786/hr × 0.5hr = $1.79
- **Spot**: 20 samples × $0.0246/hr × 0.5hr = **$0.25** (86% savings!)

**🧪 Lab Exercise**:
1. Find the cheapest Spot price for t3.xlarge across all regions
2. Find the cheapest GPU Spot instance
3. Compare Spot vs On-Demand for your typical workload

---

### 1.3: Capacity & Quota Checking (10 min)

**The Problem**: Launch 50 instances → "InsufficientInstanceCapacity" or "VcpuLimitExceeded" error 😡

**spore.host solution**: Check BEFORE launching!

#### Understanding AWS Quotas

AWS limits resources per account to prevent accidental large bills:

| Family | Instance Types | Common Default | Notes |
|--------|---------------|----------------|-------|
| **Standard** | A, C, D, H, I, M, R, T, Z | 32-256 vCPUs | Most research instances |
| **G** | g4dn, g5, g6 | 0-128 vCPUs | Graphics/GPU |
| **P** | p3, p4, p5 | **0 vCPUs** | GPU training (must request!) |
| **Inf** | inf1, inf2 | **0 vCPUs** | Inferentia (must request!) |

**Critical**: GPU quotas (P, Inf) are often **ZERO by default** - you must request them!

#### Quota Check (truffle)

```bash
# View all quotas across families
truffle quotas

# Output:
# ┌──────────┬────────────┬────────────┬───────┬────────────┬────────┐
# │ Family   │ Type       │ Quota      │ Usage │ Available  │ Status │
# ├──────────┼────────────┼────────────┼───────┼────────────┼────────┤
# │ Standard │ On-Demand  │ 256 vCPUs  │ 45    │ 211 vCPUs  │ ✅ OK  │
# │ G        │ On-Demand  │ 128 vCPUs  │ 0     │ 128 vCPUs  │ ✅ OK  │
# │ P        │ On-Demand  │ 0 vCPUs    │ 0     │ 0 vCPUs    │ ❌ Zero│
# └──────────┴────────────┴────────────┴───────┴────────────┴────────┘

# Check specific family
truffle quotas --family Standard
truffle quotas --family P

# Multi-region comparison
truffle quotas --regions us-west-2,us-east-1,eu-west-1
```

#### Requesting Quota Increases

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
# Typically approved in 24-48 hours
# GPU quotas require business justification
```

#### Capacity Checking

```bash
# Check if instances are available
truffle capacity --instance-types p3.2xlarge

# Output:
# REGION      AVAILABLE  SPOT_PRICE
# us-west-2   YES        $0.918
# us-east-1   YES        $1.008
# us-east-2   NO         -

# Check multiple types
truffle capacity --instance-types "p3.2xlarge,p3.8xlarge"

# GPU-only capacity across regions (use -r flag for specific regions)
truffle capacity --gpu-only
```

**Critical Workflow**:
1. **Check quota**: `truffle quotas`
2. **Check capacity**: `truffle capacity --instance-types TYPE`
3. **Launch confidently**: No surprise errors!

**💡 Pro Tip**: Always check quotas before launching job arrays with 20+ instances!

**🧪 Lab Exercise**:
1. Run `truffle quotas` - see all quota families
3. Check capacity for p3.2xlarge: `truffle capacity --instance-types p3.2xlarge`
4. Try `truffle quotas --family P` - likely zero! (GPU quota must be requested)
5. Generate quota increase request: `truffle quotas --family P --request`

---

## Part 2: Launch & Manage with spawn (40 minutes)

### 2.1: Quick Launch Basics (10 min)

**Wizard Mode** (Perfect for Beginners):
```bash
# Just type 'spawn' and answer prompts
spawn

# Wizard guides you through:
# - Region selection
# - Instance type
# - Key pair (auto-creates if missing!)
# - TTL (auto-termination time)
# - Spot vs On-Demand

# Result: Instance ready in 60 seconds!
```

**Direct Launch** (When You Know What You Want):
```bash
# Simple launch with defaults
spawn --instance-type t3.medium --ttl 8h

# Spot instance
spawn --instance-type c7i.xlarge --spot --ttl 4h

# Auto-STOP (not terminate) to save money
spawn --instance-type t3.xlarge --ttl 8h --on-complete stop

# Hibernate (saves RAM state)
spawn --instance-type p3.2xlarge --ttl 24h --on-complete hibernate
```

**Pipe from truffle** (The Power Combo):
```bash
# Find cheapest Spot, launch immediately
truffle spot "m7i.xlarge" --sort-by-price | spawn --ttl 8h

# Natural language to launch
truffle find "large amd" | spawn --spot --ttl 4h
```

**🧪 Lab Exercise**:
1. Launch a t3.medium with 4-hour TTL using wizard mode
2. Find and launch the cheapest Spot c7i.large with 2-hour TTL
3. Launch an instance that auto-stops (not terminates) after 6 hours

---

### 2.2: Batch Mode - Parallel Computing Made Easy (15 min)

**Real Research Problem**: Process 20 genomic samples in parallel

**⚠️ CRITICAL FIRST STEP: Check Quota!**

Before launching 20 instances, verify you have enough vCPU quota:

```bash
# Step 1: Check quota
truffle quotas --family Standard

# Example output:
# Standard | On-Demand | 256 vCPUs | 45 | 211 vCPUs | ✅ OK
#                                         ↑ Check this!

# Step 2: Calculate needed vCPUs
# 20 instances × c7i.xlarge (4 vCPUs each) = 80 vCPUs needed

# Step 3: Verify: 80 needed < 211 available ✅ Can launch!

# If insufficient quota:
truffle quotas --family Standard --request
# Then wait 24-48 hours for approval
```

**Traditional Approach** (Painful):
```bash
# Launch instances one by one
for i in {1..20}; do
  aws ec2 run-instances --instance-type c7i.xlarge --user-data "process sample $i"
done

# Problems:
# ❌ No quota checking → might fail after launching 10!
# ❌ Manual rank assignment
# ❌ No peer discovery
# ❌ Hard to manage 20 instances individually
```

**spawn Batch Mode** (Elegant):
```bash
# Launch 20 instances with automatic rank assignment
spawn launch --count 20 --job-array-name genomics-pipeline \
  --instance-type c7i.xlarge --spot --ttl 24h \
  --user-data '#!/bin/bash
  # Each instance gets automatic $SPORE_RANK (0-19)
  SAMPLE_ID=$SPORE_RANK

  # Download sample
  aws s3 cp s3://data/sample_${SAMPLE_ID}.fastq ./

  # Process with GATK
  gatk HaplotypeCaller -I sample_${SAMPLE_ID}.fastq -O output_${SAMPLE_ID}.vcf

  # Upload results
  aws s3 cp output_${SAMPLE_ID}.vcf s3://results/

  # Auto-terminate when done
  shutdown -h now
  '

# Monitor progress
spawn list --job-array-name genomics-pipeline

# Manage entire batch as one unit
spawn stop --job-array-name genomics-pipeline     # Stop all
spawn start --job-array-name genomics-pipeline    # Resume all
spawn extend --job-array-name genomics-pipeline 4h  # Extend TTL for all
```

**🎁 Bonus Features**:

**1. Automatic DNS** - All instances in batch share DNS:
```bash
# On any instance in the batch:
ping genomics-pipeline.compute
# Resolves to all 20 instances!

# Use for distributed computing:
mpirun -n 20 -hostfile <(echo "genomics-pipeline.compute") ./my_mpi_program
```

**2. Peer Discovery** - Each instance knows about others:
```bash
# Environment variables automatically set:
echo $SPORE_RANK              # 0-19 (unique rank)
echo $SPORE_SIZE              # 20 (total instances)
echo $SPORE_JOB_ARRAY_NAME    # genomics-pipeline
echo $SPORE_PEERS             # DNS name of peer instances
```

**3. Automatic User Data Templates**:
```bash
# spawn provides helper functions in user data:
spawn launch --count 8 --job-array-name ml-training \
  --instance-type p3.2xlarge --spot --ttl 48h \
  --user-data '#!/bin/bash
  # Built-in helpers available:
  spore-rank            # Get my rank (0-7)
  spore-size            # Get total size (8)
  spore-is-rank-0       # Am I rank 0? (useful for coordinator)
  spore-peers           # Get list of peer IPs

  if spore-is-rank-0; then
    echo "I am the coordinator!"
    # Coordinate distributed training
  fi
  '
```

**Scaling Up**: Start with 20, then check quotas and scale!
```bash
# Check your quota first
truffle quotas --family Standard

# If you have quota, scale up to 50, 100, or more
spawn launch --count 50 --job-array-name large-batch \
  --instance-type c7i.xlarge --spot --ttl 24h \
  --user-data '...'
```

**Real Research Use Cases**:

**Genomics Pipeline** (20 samples):
```bash
spawn launch --count 20 --job-array-name variant-calling \
  --instance-type c7i.2xlarge --spot --ttl 12h \
  --user-data '#!/bin/bash
  RANK=$SPORE_RANK
  aws s3 cp s3://genomes/sample_${RANK}.bam ./
  bcftools mpileup -f reference.fa sample_${RANK}.bam | bcftools call -mv -O v -o ${RANK}.vcf
  aws s3 cp ${RANK}.vcf s3://results/vcf/
  '
```

**Image Processing** (20 batches):
```bash
spawn launch --count 20 --job-array-name image-analysis \
  --instance-type m7i.xlarge --spot --ttl 8h \
  --user-data '#!/bin/bash
  RANK=$SPORE_RANK
  aws s3 cp s3://microscopy/images/batch_${RANK}.tar.gz ./
  tar -xzf batch_${RANK}.tar.gz
  python analyze_images.py --input batch_${RANK}/ --output results_${RANK}.json
  aws s3 cp results_${RANK}.json s3://results/
  '
```

**Distributed ML Training** (PyTorch DDP):
```bash
spawn launch --count 8 --job-array-name distributed-training \
  --instance-type p3.8xlarge --spot --ttl 24h \
  --user-data '#!/bin/bash
  # Setup PyTorch Distributed
  export MASTER_ADDR=$(spore-peers | head -n1)  # Rank 0 is master
  export MASTER_PORT=29500
  export WORLD_SIZE=$SPORE_SIZE
  export RANK=$SPORE_RANK

  python -m torch.distributed.launch train.py --epochs 100
  '
```

**🧪 Lab Exercise**:
1. Launch a job array with 10 instances to simulate parallel processing
2. Check the status of your job array with `spawn list`
3. Stop and restart the entire job array with one command
4. (Bonus) Launch a job array where rank 0 is the coordinator

---

### 2.3: Data Staging - 99% Cost Savings on Data Transfer (10 min)

**The Problem**: Distribute 50GB reference genome to 20 instances

**Traditional Approach** (Expensive):
```bash
# Each instance downloads from S3 independently
# 20 instances × 50GB = 1TB data transfer
# Cost: $0.09/GB × 1,000GB = $90 💸
```

**spawn Staging** (Smart):
```bash
# 1. Stage data once in the region
spawn stage upload genome-reference.tar.gz /mnt/data/genome-ref.tar.gz \
  --regions us-west-2

# Cost: $0.09/GB × 50GB = $4.50 (one-time)

# 2. Launch instances - data automatically available!
spawn launch --count 20 --job-array-name genome-analysis \
  --instance-type c7i.xlarge --spot --ttl 24h \
  --region us-west-2 \
  --user-data '#!/bin/bash
  # Data already available at /mnt/data/genome-ref.tar.gz
  # NO download needed!
  tar -xzf /mnt/data/genome-ref.tar.gz -C /data/

  # Process your sample
  SAMPLE=$SPORE_RANK
  gatk HaplotypeCaller -R /data/genome-ref.fa -I sample_${SAMPLE}.bam
  '

# 3. Cleanup when done
spawn stage delete genome-reference.tar.gz

# Total cost: $4.50 (staging) vs $90 (traditional) = 95% savings! ✅
```

**List Staged Data**:
```bash
# See what's staged in each region
spawn stage list

# Output:
# REGION      FILE                    SIZE     COST    UPLOADED
# us-west-2   genome-ref.tar.gz      100GB    $9.00   2024-12-15
# us-east-1   genome-ref.tar.gz      100GB    $9.00   2024-12-15
```

**Multi-Region Staging**:
```bash
# Stage in multiple regions for global research collaboration
spawn stage upload reference-data.tar.gz /mnt/data/reference.tar.gz \
  --regions us-west-2,us-east-1,eu-west-1,ap-southeast-1

# Researchers worldwide can launch instances without data transfer delays
```

**When to Use Staging**:
- ✅ Distributing >50GB to 10+ instances
- ✅ Multi-region deployments
- ✅ Frequently reused reference datasets (genomes, models, databases)
- ✅ Large container images
- ❌ One-off data transfers (just use S3)
- ❌ Data that changes frequently

**🧪 Lab Exercise**:
1. Stage a small test file (10MB) in your default region
2. Launch 5 instances in a job array that access the staged data
3. Verify the data is available on each instance
4. Delete the staged data after cleanup

---

### 2.4: Monitoring & Management (5 min)

**See Everything You're Running**:
```bash
# All instances, all regions, instant overview
spawn list

# Example output:
# NAME              ID          TYPE        REGION      STATE     COST/HR  TTL     TOTAL
# research-01       i-0abc123   t3.medium   us-west-2   running   $0.04    6h      $0.24
# genomics-array-0  i-0def456   c7i.xlarge  us-east-1   running   $0.18    2h      $0.36
# genomics-array-1  i-0def457   c7i.xlarge  us-east-1   running   $0.18    2h      $0.36
# ...
# genomics-array-99 i-0def555   c7i.xlarge  us-east-1   running   $0.18    2h      $0.36
#
# Total running cost: $18.22/hour
# Projected 24-hour cost: $437.28

# Filter by state
spawn list --state stopped       # See stopped instances (costing $0/hr)
spawn list --state running       # Only running

# Filter by job array
spawn list --job-array-name genomics-pipeline

# Filter by region
spawn list --region us-west-2
```

**Lifecycle Management**:
```bash
# Stop instance (99% cost savings, keeps data)
spawn stop i-0abc123

# Start stopped instance
spawn start i-0abc123

# Hibernate (saves RAM state too)
spawn hibernate i-0abc123

# Extend TTL (need more time)
spawn extend i-0abc123 4h
spawn extend --job-array-name genomics-pipeline 4h  # Extend all

# Terminate (use AWS CLI or let TTL expire)
aws ec2 terminate-instances --instance-ids i-0abc123 --region us-west-2
```

**Connection**:
```bash
# Connect by instance ID
spawn connect i-0abc123

# Connect by name
spawn connect research-01

# Connect to rank in job array
spawn connect genomics-pipeline-0  # Rank 0
spawn connect genomics-pipeline-42 # Rank 42
```

**Cost Monitoring Best Practices**:
```bash
# Add to your .bashrc or .zshrc:
alias what-is-running='spawn list'

# Run daily to avoid surprise bills
spawn list
```

**🧪 Lab Exercise**:
1. Run `spawn list` to see all your instances
2. Calculate your current hourly cost
3. Stop any instances you're not actively using
4. Connect to one of your running instances

---

### 2.5: Batch Queues - Sequential Pipelines (10 min)

**When to Use**: Multiple jobs with dependencies running on ONE instance sequentially.

**Job Arrays vs Batch Queues**:
```
Job Arrays:     20 instances × 1 job each = 20 parallel jobs
Batch Queues:   1 instance × 20 jobs = 20 sequential jobs
```

**The Problem**: ML pipeline with dependencies: preprocess → train → evaluate → export

**Traditional Approach**:
```bash
# Manually SSH and run commands one by one
ssh instance
python preprocess.py
python train.py
python evaluate.py
python export.py
# If you disconnect, everything stops!
```

**Batch Queue Approach**:

Create `ml-pipeline.json`:
```json
{
  "queue_id": "ml-pipeline",
  "queue_name": "end-to-end-ml",
  "jobs": [
    {
      "job_id": "preprocess",
      "command": "python preprocess.py --input /data/raw --output /data/processed",
      "timeout": "30m",
      "retry": {
        "max_attempts": 3,
        "backoff": "exponential"
      }
    },
    {
      "job_id": "train",
      "command": "python train.py --data /data/processed --output /models",
      "timeout": "2h",
      "depends_on": ["preprocess"],
      "env": {
        "CUDA_VISIBLE_DEVICES": "0",
        "BATCH_SIZE": "32"
      },
      "result_paths": ["/models/model.pt"]
    },
    {
      "job_id": "evaluate",
      "command": "python evaluate.py --model /models/model.pt --output /results",
      "timeout": "15m",
      "depends_on": ["train"],
      "result_paths": ["/results/metrics.json"]
    },
    {
      "job_id": "export",
      "command": "python export.py --model /models/model.pt --format onnx",
      "timeout": "10m",
      "depends_on": ["evaluate"],
      "result_paths": ["/export/model.onnx"]
    }
  ],
  "global_timeout": "4h",
  "on_failure": "stop",
  "result_s3_bucket": "my-results-bucket",
  "result_s3_prefix": "ml-pipeline"
}
```

**Launch**:
```bash
spawn launch \
  --batch-queue ml-pipeline.json \
  --instance-type g5.2xlarge \
  --region us-east-1
```

**Key Features**:
- ✅ **Dependencies**: Jobs run in order (DAG execution)
- ✅ **Automatic retry**: Exponential or fixed backoff
- ✅ **Result collection**: Auto-upload to S3
- ✅ **State persistence**: Resume after failures
- ✅ **Cost efficient**: One instance for entire pipeline

**Monitor**:
```bash
spawn queue status <instance-id>

# Output:
# Queue ID:    ml-pipeline
# Status:      running
# Jobs:
# preprocess    completed   1        0        yes
# train         running     1        -        no       (PID: 12345)
# evaluate      pending     0        -        no
# export        pending     0        -        no
```

**When to Use Batch Queues**:
- ✅ ML/data pipelines with dependencies
- ✅ ETL workflows (extract → transform → load)
- ✅ CI/CD pipelines
- ✅ Sequential processing on ONE instance
- ❌ Parallel processing (use job arrays instead!)

**🧪 Lab Exercise**:
1. Create a simple 3-job batch queue (setup → process → cleanup)
2. Launch with `--batch-queue`
3. Monitor with `spawn queue status`
4. Download results with `spawn queue results`

---

### 2.6: Detached Mode - Unattended Execution (5 min)

**The Problem**: Long-running sweep (4 hours), but you need to close your laptop!

**Traditional Approach**:
```bash
# Keep terminal open for 4 hours
spawn launch --params sweep.yaml --max-concurrent 10

# If laptop sleeps → sweep stops! 😱
# If network drops → sweep stops!
# If terminal closes → sweep stops!
```

**Detached Mode**: Lambda-orchestrated, survives disconnection
```bash
# Launch sweep, CLI exits immediately
spawn launch --params sweep.yaml --max-concurrent 10 --detach

# CLI exits after ~2 seconds!
# Lambda continues orchestration
# Close laptop, disconnect, sleep - sweep continues!
```

**How it Works**:
1. CLI uploads params to S3
2. CLI creates DynamoDB state record
3. CLI invokes Lambda function
4. **CLI exits** (you can disconnect!)
5. Lambda orchestrates instance launches
6. Lambda self-reinvokes every 13 minutes (unlimited duration!)
7. State persists in DynamoDB

**Monitor from ANY machine**:
```bash
# Check status (from different laptop/location)
spawn status --sweep-id sweep-20260122-140530

# Output:
# Sweep ID:        sweep-20260122-140530
# Status:          RUNNING
# Progress:        45/100 (45%)
# Active:          10 instances
# Completed:       45 instances
# Failed:          0 instances
# Next to launch:  46
```

**Resume if needed**:
```bash
# Resume from any machine
spawn resume --sweep-id sweep-20260122-140530 --detach
```

**Cancel if needed**:
```bash
# Terminate all instances and stop sweep
spawn cancel --sweep-id sweep-20260122-140530
```

**Cost**: ~$0.005 per sweep (Lambda + DynamoDB) - negligible!

**When to Use Detached Mode**:
- ✅ Overnight hyperparameter tuning
- ✅ Any sweep >30 minutes
- ✅ Production ML training
- ✅ When you need to close laptop/disconnect
- ✅ Multi-hour workloads
- ❌ Quick experiments (<10 minutes)

**🧪 Lab Exercise**:
1. Launch a sweep with `--detach`
2. Verify CLI exits quickly
3. Check status with `spawn status`
4. (Optional) Cancel with `spawn cancel`

---

### 2.7: Scheduled Executions - Run at Future Times (5 min)

**The Problem**: Run nightly training every day at 2 AM (automatically!)

**Traditional Approach**:
- Set alarm for 2 AM
- Wake up, launch sweep manually
- Go back to sleep
- Repeat forever 😴

**Scheduled Execution**: Set it once, runs automatically!

**One-Time Schedule** (run tomorrow at 3 PM):
```bash
spawn schedule create params.yaml \
  --at "2026-01-26T15:00:00" \
  --timezone "America/New_York" \
  --name "afternoon-experiment"

# Done! It will run automatically tomorrow at 3 PM
```

**Recurring Schedule** (nightly at 2 AM):
```bash
spawn schedule create nightly-training.yaml \
  --cron "0 2 * * *" \
  --timezone "America/New_York" \
  --name "nightly-training" \
  --max-executions 30  # Stop after 30 days
```

**Cron Examples**:
```bash
# Every day at 2 AM
--cron "0 2 * * *"

# Every Monday at 9 AM
--cron "0 9 * * 1"

# Every 6 hours
--cron "0 */6 * * *"

# Weekdays at 8 AM
--cron "0 8 * * 1-5"

# First day of every month
--cron "0 0 1 * *"
```

**Manage Schedules**:
```bash
# List all schedules
spawn schedule list

# Output:
# ID                      NAME               TYPE        NEXT RUN             STATUS
# sched-20260122-140530   nightly-training   recurring   2026-01-26 02:00:00  enabled
# sched-20260122-150000   weekend-exp        one-time    2026-01-27 15:00:00  enabled

# View details and execution history
spawn schedule describe sched-20260122-140530

# Pause temporarily (vacation!)
spawn schedule pause sched-20260122-140530

# Resume after vacation
spawn schedule resume sched-20260122-140530

# Cancel permanently
spawn schedule cancel sched-20260122-140530
```

**Execution History**:
```bash
spawn schedule describe sched-20260122-140530

# Shows:
# Last 10 executions:
# 2026-01-25 02:00:00  SUCCESS  sweep-20260125-020015  Duration: 1h 23m
# 2026-01-24 02:00:00  SUCCESS  sweep-20260124-020012  Duration: 1h 19m
# 2026-01-23 02:00:00  FAILED   sweep-20260123-020009  Error: quota exceeded
```

**Advanced: End after date**:
```bash
spawn schedule create params.yaml \
  --cron "0 */6 * * *" \
  --timezone "UTC" \
  --end-after "2026-02-01T00:00:00" \
  --name "january-runs"
```

**When to Use Scheduled Executions**:
- ✅ Nightly training runs with fresh data
- ✅ Weekly model retraining
- ✅ Monthly batch processing
- ✅ Continuous experimentation
- ✅ Any recurring workflow
- ❌ Ad-hoc runs (just use `spawn launch`)

**🧪 Lab Exercise**:
1. Schedule a sweep for 10 minutes from now
2. List schedules with `spawn schedule list`
3. View schedule details
4. Cancel schedule before it runs

---

## Part 3: Real Research Workflows (30 minutes)

### 3.1: Genomics Variant Calling Pipeline (10 min)

**Scenario**: Call variants on 20 whole genome samples

**Requirements**:
- Reference genome: 3GB
- Each sample: 30GB BAM file
- Processing time: ~30 minutes per sample
- Total samples: 20

**Without spawn**:
- Download reference 20 times: 60GB = $5.40 in wasted data transfer
- Launch 20 instances manually
- Monitor each individually
- Remember to terminate all
- Total time: 30+ minutes compute + manual overhead

**With spawn batch mode**:
```bash
# Step 1: Stage reference genome (one-time cost)
spawn stage upload human_g1k_v37.fasta.tar.gz /mnt/data/reference.tar.gz \
  --regions us-west-2

# Step 2: Launch batch of 20 instances
spawn launch --count 20 --job-array-name variant-calling \
  --instance-type c7i.2xlarge --spot --ttl 2h \
  --region us-west-2 \
  --user-data '#!/bin/bash
  set -e

  # Reference already staged!
  tar -xzf /mnt/data/reference.tar.gz -C /data/

  # Get my sample
  SAMPLE=$SPORE_RANK
  aws s3 cp s3://1000genomes/data/sample_${SAMPLE}.bam ./

  # Index
  samtools index sample_${SAMPLE}.bam

  # Call variants
  bcftools mpileup -f /data/human_g1k_v37.fasta sample_${SAMPLE}.bam | \
    bcftools call -mv -O z -o sample_${SAMPLE}.vcf.gz

  # Upload results
  aws s3 cp sample_${SAMPLE}.vcf.gz s3://my-results/vcf/

  # Auto-terminate
  shutdown -h now
  '

# Step 3: Monitor progress
spawn list --job-array-name variant-calling

# Step 4: Cleanup staged data when done
spawn stage delete human_g1k_v37.fasta.tar.gz

# Total cost: ~$3.20 (compute) + $0.27 (staging) vs $5.40 (traditional transfer)
# Total time: 30 minutes (all parallel!) + 2 minutes setup
```

**💡 Scaling Up**: Have more samples and quota? Just change `--count 20` to `--count 50` or `--count 100`!

**🧪 Lab Exercise** (Simulated):
Create a mini variant calling pipeline with 10 samples:
1. Stage a small reference file
2. Launch batch with 10 instances
3. Each instance processes one "sample" (simulate with sleep)
4. Monitor completion
5. Cleanup

---

### 3.2: High-Content Microscopy Image Analysis (10 min)

**Scenario**: Analyze 10,000 microscopy images from high-content screen

**Requirements**:
- Images: 400GB total (organized in 20 batches of 20GB each)
- Analysis: CellProfiler + custom Python
- Processing time: ~15 minutes per batch
- Total batches: 20

**Workflow**:
```bash
# Step 1: Check capacity for memory-optimized instances
truffle capacity --instance-types r7i.xlarge --regions us-west-2

# Step 2: Find cheapest Spot price
truffle spot "r7i.xlarge" --regions us-west-2 --sort-by-price

# Step 3: Launch batch of 20 instances
spawn launch --count 20 --job-array-name image-analysis \
  --instance-type r7i.xlarge --spot --ttl 4h \
  --region us-west-2 \
  --user-data '#!/bin/bash
  set -e

  # Install CellProfiler
  apt-get update && apt-get install -y cellprofiler

  # Get my batch
  BATCH=$SPORE_RANK
  aws s3 sync s3://microscopy-data/batch_${BATCH}/ /data/images/

  # Run CellProfiler pipeline
  cellprofiler -c -r -p /pipelines/analysis.cppipe -i /data/images/ -o /data/output/

  # Custom analysis
  python /scripts/quantify_features.py --input /data/output/ --output results_${BATCH}.csv

  # Upload results
  aws s3 cp results_${BATCH}.csv s3://analysis-results/

  shutdown -h now
  '

# Monitor
spawn list --job-array-name image-analysis

# Cost: ~$6 for entire analysis (Spot) vs $20 (On-Demand)
```

**💡 Scaling Up**: Have 50 batches? Check quota, then use `--count 50`!

**🧪 Lab Exercise** (Simulated):
Simulate image analysis workflow:
1. Launch 5-instance batch
2. Each instance "processes" a batch (simulate with computation)
3. Upload dummy results to S3
4. Monitor completion rate

---

### 3.3: Distributed Machine Learning Training (10 min)

**Scenario**: Train large model across 8 GPUs using PyTorch Distributed Data Parallel

**Requirements**:
- 8× V100 GPUs (p3.2xlarge instances)
- Training data: 500GB
- Synchronized gradient updates
- Training time: 24 hours

**Workflow**:
```bash
# Step 1: Stage training data
spawn stage upload imagenet-train.tar.gz /mnt/data/training-data.tar.gz \
  --regions us-east-1

# Step 2: Launch distributed training job
spawn launch --count 8 --job-array-name distributed-training \
  --instance-type p3.2xlarge --spot --ttl 30h \
  --region us-east-1 \
  --user-data '#!/bin/bash
  set -e

  # Setup environment
  export MASTER_ADDR=$(spore-peers | head -n1)  # Rank 0 is master
  export MASTER_PORT=29500
  export WORLD_SIZE=$SPORE_SIZE
  export RANK=$SPORE_RANK

  # Extract training data (already staged!)
  tar -xzf /mnt/data/training-data.tar.gz -C /data/

  # Launch PyTorch DDP training
  python -m torch.distributed.launch \
    --nproc_per_node=1 \
    --nnodes=$WORLD_SIZE \
    --node_rank=$RANK \
    --master_addr=$MASTER_ADDR \
    --master_port=$MASTER_PORT \
    train_model.py \
      --data-dir /data/imagenet/ \
      --epochs 100 \
      --batch-size 256

  # Save checkpoint (rank 0 only)
  if spore-is-rank-0; then
    aws s3 cp checkpoint.pth s3://model-checkpoints/final.pth
  fi
  '

# Monitor training
spawn list --job-array-name distributed-training

# Extend TTL if needed
spawn extend --job-array-name distributed-training 6h

# Check logs from rank 0
spawn connect distributed-training-0
```

**Cost Comparison** (24-hour training):
- **8× p3.2xlarge On-Demand**: $3.06/hr × 8 × 24hr = **$587**
- **8× p3.2xlarge Spot**: $0.918/hr × 8 × 24hr = **$176** (70% savings!)
- **8× p3.2xlarge Capacity Block**: Variable pricing (often 30-50% off On-Demand)

**🧪 Lab Exercise** (Simulated):
Simulate distributed training:
1. Launch 4-instance batch with GPU instances (or simulate with CPU)
2. Set up coordinator (rank 0) and workers
3. Verify peer discovery with `spore-peers`
4. Simulate synchronized training steps

---

### 3.4: Capacity Blocks for Planned ML Training (Bonus)

**What are Capacity Blocks?**
- Reserve GPU capacity for future use (days or weeks ahead)
- Guaranteed availability (no Spot interruptions!)
- Substantial discount over On-Demand (30-50% typical, varies by demand)
- Perfect for planned training runs

**When to Use Capacity Blocks**:
- ✅ Large ML training jobs you can schedule in advance
- ✅ Need guaranteed GPU availability
- ✅ Want savings but can't tolerate Spot interruptions
- ❌ Need instances right now (use Spot instead)
- ❌ Short training runs (<4 hours)

**Find Capacity Blocks with truffle**:
```bash
# Show available Capacity Blocks for GPU instances
truffle capacity --blocks --instance-types p5.48xlarge --regions us-east-1

# Show all GPU Capacity Blocks
truffle capacity --blocks --gpu-only

# Output shows:
# INSTANCE_TYPE  REGION     START_DATE         DURATION  PRICE_PER_HOUR  TOTAL_COST  SAVINGS
# p5.48xlarge    us-east-1  2026-02-01 09:00  48h       $68.00          $3,264      38%
```

**Reserve and Launch**:
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

# On start date/time, launch with reserved capacity
spawn launch --count 1 --instance-type p5.48xlarge \
  --region us-east-1 \
  --use-reservation \
  --ttl 48h \
  --user-data '#!/bin/bash
  # Your ML training code
  python train_model.py --epochs 100
  '
```

**Real Example**: Training LLM on 8× H100s for 2 days
```bash
# Check available Capacity Blocks in target regions
truffle capacity --blocks --instance-types p5.48xlarge -r us-east-1,us-west-2

# Compare costs:
# On-Demand: $98.32/hr × 48hr = $4,719
# Capacity Block: ~$68/hr × 48hr = $3,264 (31% savings!)
# Spot: ~$29/hr × 48hr = $1,392 (BUT: might be interrupted!)

# For critical training: Capacity Block gives guaranteed capacity at a discount
```

**Best Practice**: Book Capacity Blocks 1-2 weeks ahead for best pricing!

---

## Part 4: Advanced Patterns & Best Practices (15 minutes)

### 4.1: Multi-Region Workflows (5 min)

**Use Case**: Collaborate with researchers worldwide

```bash
# Stage data in multiple regions
spawn stage upload dataset.tar.gz /mnt/data/dataset.tar.gz \
  --regions us-west-2,us-east-1,eu-west-1,ap-southeast-1

# US West Coast team
spawn launch --count 50 --job-array-name analysis-us-west \
  --instance-type c7i.xlarge --spot --region us-west-2 ...

# US East Coast team
spawn launch --count 50 --job-array-name analysis-us-east \
  --instance-type c7i.xlarge --spot --region us-east-1 ...

# European team
spawn launch --count 50 --job-array-name analysis-eu \
  --instance-type c7i.xlarge --spot --region eu-west-1 ...

# Monitor all regions
spawn list  # Shows all regions automatically
```

---

### 4.2: Fault Tolerance with Spot (5 min)

**The Challenge**: Spot instances can be interrupted

**Solution**: Checkpointing + Auto-restart

```bash
spawn launch --count 100 --job-array-name fault-tolerant \
  --instance-type c7i.xlarge --spot --ttl 48h \
  --user-data '#!/bin/bash
  set -e

  RANK=$SPORE_RANK
  CHECKPOINT_KEY="checkpoints/sample_${RANK}.checkpoint"

  # Check for existing checkpoint
  if aws s3 ls s3://my-bucket/$CHECKPOINT_KEY; then
    echo "Resuming from checkpoint..."
    aws s3 cp s3://my-bucket/$CHECKPOINT_KEY ./checkpoint.json
    START_STEP=$(jq -r .step checkpoint.json)
  else
    START_STEP=0
  fi

  # Process with checkpointing
  for step in $(seq $START_STEP 1000); do
    # Do work
    process_step $step

    # Checkpoint every 100 steps
    if [ $((step % 100)) -eq 0 ]; then
      echo "{\"step\": $step}" > checkpoint.json
      aws s3 cp checkpoint.json s3://my-bucket/$CHECKPOINT_KEY
    fi
  done

  # Cleanup checkpoint on completion
  aws s3 rm s3://my-bucket/$CHECKPOINT_KEY
  '
```

**If instance gets interrupted**: Relaunch, it resumes from checkpoint!

---

### 4.3: Cost Optimization Strategies (5 min)

**1. Always Check Spot Prices First**:
```bash
# Find cheapest region + instance combo
truffle spot "c7i.xlarge,m7i.xlarge,r7i.xlarge" --sort-by-price
```

**2. Use TTL + Auto-Stop for Development**:
```bash
# Stops (not terminates) after 8 hours of inactivity
spawn --instance-type t3.xlarge --ttl 8h --on-complete stop --idle-timeout 1h
```

**3. Stage Reusable Data Once**:
```bash
# Stage reference genomes, model weights, datasets
spawn stage upload reference.tar.gz /mnt/data/reference.tar.gz --regions us-west-2
```

**4. Right-Size Instances**:
```bash
# Use truffle find to explore options
truffle find "32gb memory compute optimized"

# Don't overpay for resources you won't use
```

**5. Monitor Daily**:
```bash
# Add to daily routine
spawn list
```

**6. Use Job Arrays for Batch Workloads**:
- Automatic DNS and peer discovery
- Manage hundreds of instances as one unit
- No manual loop scripting

---

## Part 5: Wrap-Up & Next Steps (5 minutes)

### What You Learned

✅ **Discovery**:
- Natural language instance search (no memorizing AWS types!)
- Automatic Spot price comparison
- Capacity and quota checking before launch

✅ **Four Execution Modes**:
- **Job Arrays**: Parallel processing across multiple instances
- **Batch Queues**: Sequential pipelines with dependencies
- **Detached Mode**: Unattended execution that survives disconnection
- **Scheduled Execution**: Automatic runs at future times

✅ **Launch & Manage**:
- Wizard, direct, and piped launch modes
- Data staging for 95% cost savings
- Capacity Blocks for planned GPU reservations
- Lifecycle management (stop/start/hibernate)
- Multi-region monitoring with `spawn list`

✅ **Real Workflows**:
- Genomics variant calling at scale
- High-content microscopy analysis
- Distributed ML training
- Fault tolerance with Spot

✅ **Best Practices**:
- Always check Spot prices first
- Use TTL to prevent surprise bills
- Stage reusable data
- Monitor with `spawn list` daily

---

### Resources

**spore.host documentation**:
- GitHub: https://github.com/scttfrdmn/spore-host
- Installation: https://github.com/scttfrdmn/spore-host#installation
- Examples: https://github.com/scttfrdmn/spore-host/tree/main/examples

**Community**:
- Slack: [Ask instructor for invite]
- Issues/Feature Requests: https://github.com/scttfrdmn/spore-host/issues

**AWS Resources**:
- Cloud Credit for Research: https://aws.amazon.com/government-education/research-and-technical-computing/cloud-credit-for-research/
- GDEW Information: https://aws.amazon.com/government-education/research-and-technical-computing/ (see GDEW section)

---

### Next Steps

**This Week**:
1. Install spore.host tools on your machine
2. Try `truffle find` to explore instances (no AWS account needed!)
3. Launch one instance with `spawn` wizard mode

**This Month**:
1. Convert one of your research workflows to use spawn job arrays
2. Stage your reference datasets with `spawn stage`
3. Set up daily `spawn list` monitoring

**Long Term**:
1. Share spore.host with lab mates
2. Build reusable workflow scripts
3. Contribute examples to GitHub

---

### Feedback

**What worked well?**
**What was confusing?**
**What workflows would you like to see next?**

Share feedback: https://github.com/scttfrdmn/spore-host/discussions

---

**Thank you for attending! Happy computing! 🚀**
