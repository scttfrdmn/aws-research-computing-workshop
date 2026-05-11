# spore.host Workshop - Final Agenda

**Workshop Title**: From AWS Fundamentals to Production: spore.host Workshop
**Duration**: 2-3 hours (2 hours core + 30min advanced optional)
**Prerequisites**: Completed AWS fundamentals workshop OR basic AWS CLI experience
**Target Audience**: Researchers ready for production cloud workflows

**Workshop Structure**:
- **Core** (2 hours): Discovery, basic launch, job arrays, data staging
- **Advanced** (optional): Batch queues, detached mode, scheduled executions

---

## Complete Schedule

### 0:00 - 0:05 | Welcome & Prerequisites Check (5 minutes)

**Quick Poll**:
- ✋ Completed AWS fundamentals workshop?
- ✋ Familiar with AWS CLI?
- ✋ Have AWS credentials configured?
- ✋ spore.host tools installed (`truffle`, `spawn`)? (if not, install now while we introduce)

**Installation** (if needed):
```bash
# macOS / Linux (Homebrew)
brew install scttfrdmn/tap/truffle
brew install scttfrdmn/tap/spawn

# Windows: scoop bucket add scttfrdmn https://github.com/scttfrdmn/scoop-bucket && scoop install truffle spawn
# Linux .deb/.rpm: download per-tool packages from https://github.com/scttfrdmn/spore-host/releases/latest

# Verify
truffle --version
spawn --version
```

**Today's Goal**: Move from "learning AWS" to "doing real research on AWS efficiently"

**Six Execution Modes**:

| Mode | Use When | Instances | Jobs | Duration |
|------|----------|-----------|------|----------|
| **Regular Launch** | Interactive, wizard mode | One | Manual | Short |
| **One-Shot (TTL)** | Auto-terminate after time | One | Manual | Hours |
| **Job Arrays** | Parallel processing | Many (20+) | 1 per instance | Any |
| **Batch Queues** | Sequential pipeline | One | Many sequential | Hours |
| **Detached Mode** | Long + disconnect | Any | Any | Hours+ |
| **Scheduled** | Future time | Any | Any | Any |

---

### 0:05 - 0:35 | Part 1: Discovery with truffle (30 minutes)

#### 0:05 - 0:15 | Natural Language Instance Search (10 min)

**Demo**:
```bash
# No more memorizing AWS instance types!
truffle find h100                    # NVIDIA H100 GPUs
truffle find "large amd"             # Large AMD instances
truffle find "efa graviton"          # Graviton with EFA networking
truffle find "8 gpu nvidia"          # 8 GPU instances
```

**Key Point**: Works WITHOUT AWS credentials! Perfect for exploring.

**🧪 Hands-On** (3 min):
1. Find instances with 32 GB RAM
2. Find instances for your research workload (use natural language)
3. Find instances with local NVMe storage

---

#### 0:15 - 0:25 | Spot Price Discovery (10 min)

**The Goal**: Save 50-90% on compute costs

**Demo**:
```bash
# Find cheapest Spot instances
truffle spot "c7i.*" --sort-by-price

# Output:
# INSTANCE_TYPE  REGION      SPOT_PRICE  ON_DEMAND  SAVINGS
# c7i.large      us-west-2   $0.0123     $0.0893    86%

# Sort by price to find cheapest
truffle spot "c7i.xlarge" --sort-by-price
```

**Real Example**: 1,000 sample genomics pipeline
- On-Demand: $89.30
- Spot: **$12.30** (86% savings!)

**🧪 Hands-On** (3 min):
1. Find cheapest Spot price for t3.xlarge
2. Find cheapest GPU Spot instance
3. Calculate savings for your typical workload

---

#### 0:25 - 0:35 | Capacity & Quota Checking (10 min)

**The Problem**: Launch 20 instances → "VcpuLimitExceeded" or "InsufficientInstanceCapacity" error 😡

**Solution**: Check BEFORE launching!

**Key Concept**: AWS quotas limit vCPUs per account
- **Standard** family (C, M, R, T): Usually 32-256 vCPUs
- **P** family (GPU): Usually **0 vCPUs by default** ← Must request!
- **G** family (GPU): 0-128 vCPUs

**Quota Check (truffle)**:
```bash
# View all quota families
truffle quotas

# Check specific family
truffle quotas --family Standard
truffle quotas --family P  # GPU quota (likely 0!)

# Multi-region comparison
truffle quotas --regions us-west-2,us-east-1
```

**Request Quota Increase**:
```bash
# Generate increase request commands
truffle quotas --family P --request

# Copy/paste AWS command, approved in 24-48 hours
```

**Capacity Checking**:
```bash
# Check if instances are available
truffle capacity --instance-types p3.2xlarge
```

**Critical Workflow**:
1. ✅ Check quota: `truffle quotas`
2. ✅ Check capacity: `truffle capacity`
3. ✅ Launch confidently - no surprise errors!

**💡 Pro Tip**: ALWAYS check quotas before launching job arrays!

**🧪 Hands-On** (3 min):
1. Run `truffle quotas` - see all quota families
2. Check `truffle quotas --family P` (likely zero!)
3. Generate increase request: `truffle quotas --family P --request`

---

### 0:35 - 1:15 | Part 2: Launch & Manage with spawn (40 minutes)

#### 0:35 - 0:45 | Quick Launch Basics (10 min)

**Wizard Mode Demo**:
```bash
$ spawn
# [Press Enter 6 times with defaults]
# 🎉 Instance ready in 60 seconds!
```

**Direct Launch**:
```bash
# Simple
spawn --instance-type t3.medium --ttl 8h

# Spot
spawn --instance-type c7i.xlarge --spot --ttl 4h

# Auto-stop (not terminate)
spawn --instance-type t3.xlarge --ttl 8h --on-complete stop
```

**The Power Combo** (truffle → spawn):
```bash
# Find cheapest Spot, launch immediately
truffle spot "m7i.xlarge" --sort-by-price | spawn --ttl 8h

# Natural language to launch
truffle find "large amd" | spawn --spot --ttl 4h
```

**🧪 Hands-On** (5 min):
1. Launch t3.medium with wizard mode (4-hour TTL)
2. Find and launch cheapest Spot c7i.large (2-hour TTL)
3. Launch instance that auto-stops after 6 hours

---

#### 0:45 - 1:00 | Batch Mode - Parallel Computing (15 min)

**The Problem**: Process 20 samples in parallel

**⚠️ STEP 0: Check Quota First!**
```bash
# ALWAYS check before launching multiple instances
truffle quotas --family Standard
# Need: 20 × c7i.xlarge (4 vCPUs) = 80 vCPUs
# Verify available > 80, or request increase
```

**Old Way** (painful):
```bash
for i in {1..20}; do
  aws ec2 run-instances ...
done
# ❌ No quota checking → might fail partway!
# ❌ Manual rank assignment
# ❌ Hard to manage
```

**spawn Batch Mode** (elegant):
```bash
spawn launch --count 20 --job-array-name genomics \
  --instance-type c7i.xlarge --spot --ttl 24h \
  --user-data '#!/bin/bash
  # Automatic $SPORE_RANK (0-19)
  SAMPLE=$SPORE_RANK
  aws s3 cp s3://data/sample_${SAMPLE}.fastq ./
  gatk HaplotypeCaller -I sample_${SAMPLE}.fastq -O output_${SAMPLE}.vcf
  aws s3 cp output_${SAMPLE}.vcf s3://results/
  shutdown -h now
  '

# Manage entire batch
spawn list --job-array-name genomics
spawn stop --job-array-name genomics
spawn extend --job-array-name genomics 4h
```

**🎁 Bonus Features**:
1. **Automatic DNS**: `genomics.compute` resolves to all 20 instances
2. **Peer Discovery**: Each instance knows about others
3. **Built-in helpers**: `spore-rank`, `spore-size`, `spore-is-rank-0`

**Real Use Cases**:
- Genomics variant calling (20 samples)
- Image analysis (20 batches)
- Distributed ML training (8 GPUs)

**💡 Scaling Up**: Check quota, then increase count to 50, 100, or more!

**🧪 Hands-On** (8 min):
1. Launch batch with 10 instances
2. Check status: `spawn list --job-array-name YOUR_NAME`
3. Stop and restart entire batch
4. (Bonus) Launch batch where rank 0 is coordinator

---

#### 1:00 - 1:10 | Data Staging - 95% Cost Savings (10 min)

**The Problem**: Distribute 50GB to 20 instances
- Traditional: 1TB transfer = **$90** 💸
- Staging: One-time = **$4.50** ✅ (95% savings!)

**Demo**:
```bash
# Stage once
spawn stage upload genome-ref.tar.gz /mnt/data/genome-ref.tar.gz \
  --regions us-west-2

# Launch instances - data automatically available!
spawn launch --count 20 --job-array-name analysis \
  --instance-type c7i.xlarge --spot --ttl 24h \
  --user-data '#!/bin/bash
  # Already available at /mnt/data/genome-ref.tar.gz
  tar -xzf /mnt/data/genome-ref.tar.gz -C /data/
  # Your processing here...
  '

# Cleanup
spawn stage delete genome-ref.tar.gz
```

**When to Use**:
- ✅ >50GB to 10+ instances
- ✅ Multi-region deployments
- ✅ Frequently reused reference datasets
- ❌ One-off transfers (use S3)

**💡 Scales with instance count**: 50 instances? $225 traditional vs $4.50 staging!

**🧪 Hands-On** (5 min):
1. Stage small test file (10MB)
2. Launch 5-instance batch accessing staged data
3. Verify data availability
4. Delete staged data

---

#### 1:10 - 1:15 | Monitoring & Management (5 min)

**See Everything You're Running**:
```bash
# All instances, all regions, instant overview
spawn list

# Example output:
# NAME            ID         TYPE       REGION     STATE    COST/HR  TTL
# research-01     i-0abc123  t3.medium  us-west-2  running  $0.04    6h
# genomics-0      i-0def456  c7i.large  us-east-1  running  $0.09    2h
# ...
# Total: $18.22/hour

# Filter views
spawn list --state stopped
spawn list --job-array-name genomics
spawn list --region us-west-2
```

**Lifecycle Management**:
```bash
spawn stop i-0abc123              # Stop (99% savings)
spawn start i-0abc123             # Resume
spawn hibernate i-0abc123         # Save RAM state
spawn extend i-0abc123 4h         # Need more time
spawn connect research-01         # SSH by name
```

💡 **Pro Tip**: Add `alias what='spawn list'` to your .bashrc

**🧪 Hands-On** (2 min):
1. Run `spawn list` - see your hourly cost
2. Stop instances you're not using
3. Connect to a running instance

---

### 1:15 - 1:45 | Part 3: Real Research Workflows (30 minutes)

#### 1:15 - 1:25 | Genomics Variant Calling (10 min)

**Scenario**: Call variants on 20 whole genomes

**Full Workflow**:
```bash
# 1. Stage reference (one-time)
spawn stage upload human_g1k_v37.fasta.tar.gz /mnt/data/reference.tar.gz \
  --regions us-west-2

# 2. Launch batch of 20 instances
spawn launch --count 20 --job-array-name variant-calling \
  --instance-type c7i.2xlarge --spot --ttl 2h \
  --region us-west-2 \
  --user-data '#!/bin/bash
  tar -xzf /mnt/data/reference.tar.gz -C /data/
  SAMPLE=$SPORE_RANK
  aws s3 cp s3://1000genomes/data/sample_${SAMPLE}.bam ./
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

**Cost**: ~$3.20 (compute) + $0.27 (staging) vs $5.40 (traditional transfer)
**Time**: 30 minutes (all parallel!)

**💡 Scaling**: Have quota for 50? Just change `--count 20` to `--count 50`!

**🧪 Hands-On** (5 min):
Simulate mini pipeline with 10 "samples"

---

#### 1:25 - 1:35 | Microscopy Image Analysis (10 min)

**Scenario**: Analyze 10,000 microscopy images (20 batches × 20GB)

**Workflow**:
```bash
# Find cheapest Spot
truffle spot "r7i.xlarge" --regions us-west-2 --sort-by-price

# Launch analysis
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

**Cost**: ~$6 (Spot) vs $20 (On-Demand)

**🧪 Hands-On** (5 min):
Simulate image processing with 5 "batches"

---

#### 1:35 - 1:45 | Distributed ML Training (10 min)

**Scenario**: Train model across 8 GPUs with PyTorch DDP

**Workflow**:
```bash
# Stage training data
spawn stage upload imagenet.tar.gz /mnt/data/training.tar.gz --regions us-east-1

# Launch distributed training
spawn launch --count 8 --job-array-name ml-training \
  --instance-type p3.2xlarge --spot --ttl 30h \
  --user-data '#!/bin/bash
  export MASTER_ADDR=$(spore-peers | head -n1)
  export MASTER_PORT=29500
  export WORLD_SIZE=$SPORE_SIZE
  export RANK=$SPORE_RANK

  tar -xzf /mnt/data/training.tar.gz -C /data/

  python -m torch.distributed.launch train.py --epochs 100
  '

# Monitor
spawn list --job-array-name ml-training

# Extend if needed
spawn extend --job-array-name ml-training 6h
```

**Cost Comparison**:
- On-Demand: $587 (24 hours)
- Spot: **$176** (70% savings!)

**🧪 Hands-On** (5 min):
Simulate distributed training with 4 instances

---

### 1:45 - 2:15 | Part 4: Advanced Execution Modes (30 minutes, OPTIONAL)

**Note**: This section is optional for advanced users. Core workshop ends at 2:00.

---

#### 1:45 - 1:55 | Batch Queues - Sequential Pipelines (10 min)

**The Problem**: Run multi-step pipeline on ONE instance with dependencies

**Use When**:
- Sequential processing (step B needs step A's output)
- Single instance is sufficient
- Want automatic retry and result collection

**Demo**:
```bash
# Create pipeline configuration
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

# Launch instance with batch queue
spawn launch --instance-type c7i.2xlarge --spot --ttl 4h \
  --batch-queue ml-pipeline.json

# Monitor progress (pass the instance ID)
spawn queue status <instance-id>

# Download results when complete
spawn queue results <queue-id> --output ./results/

# Results also automatically collected in S3
```

**Key Features**:
- ✅ Automatic dependency resolution
- ✅ Retry failed jobs with backoff
- ✅ Results collected to S3
- ✅ State persists across restarts

**💡 When to Use**: ETL pipelines, CI/CD, multi-step analysis

---

#### 1:55 - 2:05 | Detached Mode - Disconnect-Proof Sweeps (10 min)

**The Problem**: Run 10-hour parameter sweep, but need to close laptop

**Old Way** (painful):
```bash
spawn launch --params sweep.yaml --max-concurrent 10
# ❌ Must keep terminal open for 10 hours
# ❌ Disconnection = lost sweep
```

**Detached Mode** (elegant):
```bash
# Launch sweep, CLI exits immediately
spawn launch --params sweep.yaml --max-concurrent 10 --detach

# Output:
# ✅ Sweep sweep-20260129-140530 launched in detached mode
# ✅ Lambda will manage execution
# ✅ Safe to close terminal now

# Later: Check status from ANY machine
spawn status --sweep-id sweep-20260129-140530

# Cancel if needed
spawn cancel --sweep-id sweep-20260129-140530
```

**How It Works**:
- Lambda self-reinvokes every 13 minutes
- State persists in DynamoDB
- Survives laptop sleep, network drops, CLI crashes
- Cost: ~$0.005 per sweep

**💡 When to Use**: Long sweeps, unstable connections, laptop workflows

**🧪 Hands-On** (3 min):
1. Launch small detached sweep
2. Close terminal, check status from new terminal
3. Check status: `spawn status --sweep-id <id>`

---

#### 2:05 - 2:15 | Scheduled Executions - Run Later (10 min)

**The Problem**: Start training at 2 AM for cheap Spot prices

**Demo**:
```bash
# One-time execution (specific date/time)
spawn schedule create --params training.yaml \
  --at "2026-01-30T02:00:00" \
  --timezone "America/Denver"

# Recurring (nightly at 2 AM)
spawn schedule create --params nightly-analysis.yaml \
  --cron "0 2 * * *" \
  --timezone "America/Denver" \
  --name "nightly-genomics"

# List schedules
spawn schedule list

# Pause temporarily
spawn schedule pause nightly-genomics

# Resume
spawn schedule resume nightly-genomics

# Cancel
spawn schedule cancel nightly-genomics
```

**Real Use Cases**:
- Nightly data processing at off-peak hours
- Weekly model retraining
- Monthly dataset refreshes
- Launch experiments during cheap Spot windows

**Timezone Support**:
- DST handled automatically
- 600+ timezones supported
- Default: your local timezone

**💡 When to Use**: Recurring workflows, off-peak execution, automated pipelines

**🧪 Hands-On** (3 min):
1. Schedule job for 5 minutes from now
2. List schedules to verify
3. Cancel before execution

---

### 2:15 - 2:30 | Part 5: Best Practices & Wrap-Up (15 minutes)

#### 2:15 - 2:25 | Advanced Patterns & Best Practices (10 min)

**Multi-Region Workflows**:
```bash
# Stage in multiple regions for global collaboration
spawn stage upload dataset.tar.gz /mnt/data/dataset.tar.gz \
  --regions us-west-2,us-east-1,eu-west-1,ap-southeast-1

# Each region launches instances
spawn launch --count 50 --region us-west-2 ...
spawn launch --count 50 --region eu-west-1 ...

# Monitor all regions
spawn list  # Automatic!
```

**Fault Tolerance with Spot**:
```bash
# Checkpoint your work every 100 steps
if [ $((step % 100)) -eq 0 ]; then
  echo "{\"step\": $step}" > checkpoint.json
  aws s3 cp checkpoint.json s3://bucket/checkpoint_${RANK}.json
fi

# Resume from checkpoint if interrupted
if aws s3 ls s3://bucket/checkpoint_${RANK}.json; then
  aws s3 cp s3://bucket/checkpoint_${RANK}.json ./checkpoint.json
  START_STEP=$(jq -r .step checkpoint.json)
fi
```

**Cost Optimization Checklist**:
1. ✅ Always check Spot prices first: `truffle spot`
2. ✅ Use TTL + auto-stop for dev: `--ttl 8h --on-complete stop`
3. ✅ Stage reusable data: `spawn stage upload`
4. ✅ Right-size instances: `truffle find`
5. ✅ Monitor daily: `spawn list`
6. ✅ Use job arrays for batch: `--count 100`

---

#### 2:25 - 2:30 | Wrap-Up & Next Steps (5 min)

**What You Learned**:
✅ Natural language instance search (`truffle find`)
✅ Automatic Spot price comparison (`truffle spot`)
✅ Quota/capacity checking before launch
✅ Six execution modes: regular launch, one-shot (TTL), job arrays, batch queues, detached mode, scheduled executions
✅ Job arrays with automatic DNS and peer discovery
✅ Data staging for 99% cost savings
✅ Real workflows: genomics, imaging, ML
✅ Cost monitoring with `spawn list`

**This Week**:
1. Install spore.host tools on your machine
2. Try `truffle find` (no AWS account needed!)
3. Launch one instance with wizard mode

**This Month**:
1. Convert one research workflow to spawn job arrays
2. Stage your reference datasets
3. Set up daily `spawn list` monitoring

**Long Term**:
1. Share spore.host with lab mates
2. Build reusable workflow scripts
3. Contribute examples to GitHub

**Resources**:
- GitHub: https://github.com/scttfrdmn/spore-host
- Documentation: [repo]/README.md
- Community Slack: [ask instructor]
- AWS Cloud Credit for Research: https://aws.amazon.com/government-education/research-and-technical-computing/cloud-credit-for-research/

**Feedback**: https://github.com/scttfrdmn/spore-host/discussions

---

## Timing Summary

### Core Workshop (2 hours)

| Time | Duration | Section |
|------|----------|---------|
| 0:00 - 0:05 | 5 min | Welcome & Prerequisites |
| 0:05 - 0:35 | 30 min | Part 1: Discovery (truffle) |
| 0:35 - 1:15 | 40 min | Part 2: Launch & Manage (spawn) |
| 1:15 - 1:45 | 30 min | Part 3: Real Workflows |
| 1:45 - 2:00 | 15 min | Wrap-Up & Next Steps |
| **CORE TOTAL** | **120 min** | **2:00:00** ✅ |

### Optional Advanced Topics (+30 minutes)

| Time | Duration | Section |
|------|----------|---------|
| 1:45 - 1:55 | 10 min | Batch Queues (Sequential Pipelines) |
| 1:55 - 2:05 | 10 min | Detached Mode (Disconnect-Proof) |
| 2:05 - 2:15 | 10 min | Scheduled Executions (Run Later) |
| 2:15 - 2:25 | 10 min | Advanced Patterns & Best Practices |
| 2:25 - 2:30 | 5 min | Extended Wrap-Up |
| **ADVANCED TOTAL** | **45 min** | **+0:45:00** |

### Full Workshop

| **TOTAL (with advanced)** | **165 min** | **2:45:00** |

---

**Thank you for attending! Happy computing! 🚀**
