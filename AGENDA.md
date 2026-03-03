# AWS Research Computing Workshop - Final Agenda

**Workshop Title**: Introduction to AWS for Research Computing: From Campus HPC to Cloud
**Duration**: 2 hours (hard stop)
**Institution**: University of Colorado Boulder
**Target Audience**: Researchers transitioning from on-premises HPC to cloud

---

## Approach

**Workshop Philosophy**:
> Console is the primary path. CLI is shown as **optional sidebars** for those who want to automate.
>
> "AWS was built for Netflix, not for you — but you can use it too."

**CLI recommendation**: Use **AWS CloudShell** (click `>_` in the top nav bar) — browser-based, pre-authenticated, works on all OS including Windows. No installation needed.

**What's Different from Traditional Workshops**:
- ✅ **Lab 0 pre-flight check** — VPC, security group, region set up before anything else
- ✅ **No SSH key management** — use EC2 Instance Connect (browser-based terminal)
- ✅ **Tag everything** — one-command cleanup at the end
- ✅ **CLI is optional** — Console is the primary path; CLI sidebars for those who want them

---

## Complete Schedule

### 0:00 - 0:08 | Introduction & Motivation (8 minutes)

**Topics**:
- AWS is for Netflix — and for you (honest framing)
- Where participants are coming from: campus HPC or laptop
- Two tools, one researcher: cloud and campus HPC both have a place
- Cost reality check (transparent pricing)
- Workshop structure: Console first, CLI optional sidebars

**Key messages**:
- "AWS is powerful but not beginner-friendly — that's why we go step by step"
- **Campus HPC users**: EC2 = dedicated node (no queue), S3 = shared data layer (object storage, not a filesystem), Spot = preemptible queue you control
- **Laptop users**: EC2 = remote computer that doesn't need to stay awake, S3 = a hard drive that scales

**Deliverables**:
- Participants know why they're here (even if they use campus HPC)
- Set expectations: Console is primary, CLI is optional

---

### 0:08 - 0:18 | Lab 0: Pre-flight Check (10 minutes)

**Do this before anything else.** Prevents the most common "nothing is working" problems.

1. **Set region** (30 sec): Top-right corner → **US West (Oregon) — us-west-2**

2. **Verify default VPC** (1 min): Search `VPC` in top bar → VPC Dashboard → confirm "Default VPC: Yes"

3. **Create workshop-sg security group** (2 min):
   - Search `Security Groups` in top bar → click **EC2 > Security Groups** → **Create security group**
   - Name: `workshop-sg`, Inbound rule: **SSH, Anywhere-IPv4**

4. **Verify CLI auth** (30 sec): Open **CloudShell** (`>_` icon) → `aws sts get-caller-identity`

5. **Create IAM role for EC2** (2 min):
   - Search `IAM` in top bar → **Roles** → **Create role**
   - Trusted entity: **AWS service → EC2** → Next
   - Search and select `AmazonS3FullAccess` → Next
   - Role name: `ec2-workshop-role` → **Create role**

✅ Pre-flight complete when: right region, VPC visible, workshop-sg and ec2-workshop-role created, CLI responds

> 💡 **Notice anything?** Five steps before a single instance launches. This overhead exists every time — it's also exactly what Spore.host eliminates.

---

### 0:18 - 0:50 | Hands-On Lab 1: Launch EC2 & Store Data in S3 (32 minutes)
<!-- Timing: EC2 console 15 min + stop/restart 3 min + spot 2 min + S3 console 12 min = 32 min -->

> **CLI note**: All CLI commands run in **AWS CloudShell** (`>_` in top nav bar) — no installation needed on any OS. CLI sections are marked as optional sidebars.

#### Part A: Launch EC2 Instance (15 minutes)

> **⚠️ AWS UX warning**: Two critical settings are buried under **"Advanced details"** at the bottom of the launch page. Steps 7 and 8 below cover them explicitly — don't skip them.

**Console** (primary path):
1. EC2 → **Launch Instance**
2. **Name**: `research-compute-01`
3. **AMI**: Amazon Linux 2023 (already selected)
4. **Instance type**: `m6a.xlarge` (4 vCPU, 16 GB, ~$0.17/hr) — realistic for research workloads
5. **Key pair**: "Proceed without a key pair" (we'll use Instance Connect)
6. **Network settings → Edit**: select existing security group → **`workshop-sg`**; set **Auto-assign public IP** to **"Enable"** (explicitly — don't leave on "Use subnet setting")
7a. **Advanced details** (scroll to bottom, expand) → **IAM instance profile**: `ec2-workshop-role`
7b. Still in **Advanced details** → **Resource tags**: `Workshop=cu-boulder-2025`, `Owner=your-name`
8. **Launch instance** → wait ~60 seconds for "running"
9. **Connect**: select instance → Connect → **EC2 Instance Connect** → Connect

> **Why public IP must be explicit**: If left on "Use subnet setting" and the subnet default is off, Instance Connect fails silently.

---

**💻 CLI Sidebar** (optional — CloudShell):
```bash
AMI_ID=$(aws ssm get-parameters \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --region us-west-2 --query 'Parameters[0].Value' --output text)
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=workshop-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)
aws ec2 run-instances \
    --image-id $AMI_ID --instance-type m6a.xlarge \
    --iam-instance-profile Name=ec2-workshop-role \
    --security-group-ids $SG_ID \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=research-compute-cli},{Key=Workshop,Value=cu-boulder-2025}]' \
    --count 1
```

---

#### Stop and Restart Instances (3 minutes)

**Running costs money even when idle. Stop instances when you're done for the day.**

| Action | Cost | Data? |
|--------|------|-------|
| Stop | ~$0.80/mo (storage only, 8 GB) | ✅ Kept |
| Terminate | $0 | ❌ Gone |

**Console**: EC2 → your instance → Actions → Instance State → **Stop**

**💻 CLI Sidebar**:
```bash
aws ec2 stop-instances --instance-ids $INSTANCE_ID
aws ec2 start-instances --instance-ids $INSTANCE_ID   # later
```

---

#### 💰 Know About Spot Instances (2 minutes)

50-90% discount on unused EC2 capacity. Interruptible with 2-minute warning — perfect for batch research workloads (genomics, simulations, ML training). Not for databases or interactive sessions.

**Why not today**: Using Spot safely requires your workflow to handle termination — checkpointing to S3, resuming mid-run. That's a design pattern we haven't covered. Spot without it means losing work when AWS reclaims the instance.

*When ready: "Advanced details" → "Purchasing option" → check "Spot instance." See QUICK_REFERENCE.md.*

---

#### Part B: S3 Storage Setup (12 minutes)

**Console**:
1. Search `S3` in top bar → **Create bucket**
2. **Bucket name**: `rcws-yourname-0302` (replace `yourname` and `0302` with your name and today's date — the date prevents collisions if the workshop runs again)
3. **Region**: us-west-2
4. **Block Public Access**: leave checked ✅
5. **Create bucket** → click into bucket → **Upload** a test file

> 💡 S3 can auto-archive old data to Glacier (80-95% savings). See **QUICK_REFERENCE.md** when ready.

**Set `$BUCKET_NAME` for Lab 2 CLI commands**:
```bash
BUCKET_NAME="rcws-yourname-0302"  # replace 'yourname' and '0302' with today's date
```

---

### 0:50 - 1:00 | Break (10 minutes)

**During break**: Instructor checks that everyone is caught up

---

### 1:00 - 1:45 | Hands-On Lab 2: Cost Management & Data Transfer (45 minutes)

> **Start of Lab 2 check**: (1) Is your Instance Connect tab still open? If not, reconnect: EC2 → your instance → Connect → EC2 Instance Connect. (2) Re-set `$BUCKET_NAME` if your CloudShell session timed out: `BUCKET_NAME="rcws-yourname-0302"  # replace 0302 with today's date`

#### Part A: Cost Management & Savings Programs (15 minutes)

**1. Set Up Budget Alerts (4 min)**

*Console*:
- Billing → Budgets → Create budget
- Type: Cost budget
- Amount: $50/month
- Alert: 80% threshold
- Email notification

**Result**: Email when you hit $40 of $50 budget

---

**2. Check Your AWS Credits (3 min)** 💳

*Console*:
- Account menu → Billing → Credits
- View active credits balance
- Check expiration dates

**Common sources**:
- AWS Research Credits Program (apply at aws.amazon.com/research-credits)
- AWS Educate (students/faculty)
- Conference/event promotions

**Many researchers have credits and don't know it!**

---

**3. AWS Global Data Egress Waiver (GDEW) (3 min)**

**What is it?**
- Downloading data from AWS normally costs $0.09/GB
- The GDEW provides a **credit toward those egress costs** for eligible academic institutions
- The credit is capped based on CU's institutional AWS spending (not individual accounts)

**For CU researchers**: The GDEW is already applied through CU Boulder's AWS agreement — there is nothing you need to do individually.

---

**4. Cost Explorer (5 min)**

*Console*:
- Billing → Cost Explorer → Launch
- Group by: Service
- View: Last 7 days

**See exactly**: EC2 costs, S3 costs, data transfer costs

---

#### Part B: Data Transfer (15 minutes)

**Upload to S3** (Console):
- S3 → your bucket → **Upload** → drag files (for small files)

**Access from EC2** (after attaching IAM role in Lab 1):
- Connect to instance via Instance Connect
- S3 data is available via `aws s3 cp` — because the IAM role handles auth

**💻 CLI Sidebar** (CloudShell or local terminal):
```bash
# Upload single file or directory
aws s3 cp large-dataset.tar.gz s3://$BUCKET_NAME/datasets/
aws s3 sync /research/data/ s3://$BUCKET_NAME/data/ --progress

# From your EC2 instance (Instance Connect terminal):
aws s3 cp s3://$BUCKET_NAME/test-data.txt ./
```

**For huge datasets (>10TB)**: Contact your institution's research computing team — campus HPC often has Globus endpoints or dedicated transfer infrastructure for this

---

#### Part C: Cleanup (10 minutes)

**EC2** (tag-based — this is why we tagged):
1. EC2 → Instances → filter: **Tag: Workshop = cu-boulder-2025**
2. Select all → Actions → Instance State → **Terminate instance**

**S3** (manual):
1. S3 → click your bucket → **Empty** → confirm → **Empty**
2. Back to bucket list → select bucket → **Delete** → type name → **Delete bucket**

---

**💻 CLI Sidebar** (EC2 only — CloudShell):

```bash
aws ec2 terminate-instances --instance-ids $(
    aws ec2 describe-instances \
        --filters "Name=tag:Workshop,Values=cu-boulder-2025" \
                  "Name=instance-state-name,Values=running,stopped" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text
) && echo "All workshop instances terminated!"
```

---

### 1:45 - 2:00 | Wrap-Up & Resources (15 minutes)

#### What You Learned

✅ Lab 0 pre-flight: region, VPC, security group, IAM role — before anything else
✅ Launch EC2 (m6a.xlarge) with IAM role, public IP, and tags set correctly
✅ Connect via EC2 Instance Connect — no SSH keys
✅ Install miniforge and run an analysis on the instance
✅ Complete loop: pull data from S3 → run analysis → push results back
✅ Set up budget alerts to prevent surprise bills
✅ Know about Spot and why checkpointing comes first
✅ Tag-based one-command cleanup
✅ Spore.host available as bonus if staying after

---

#### Cost Optimization Recap

| Technique | Potential Savings | Time to Implement |
|-----------|-------------------|-------------------|
| **Spot instances** | 50-90% on compute | 2 minutes (add one flag) |
| **S3 lifecycle policies** | 80-95% on old data | 5 minutes |
| **AWS credits** | $1,000-$100,000 | 10 min application |
| **GDEW** | Credit on egress costs | Already applied through CU agreement |
| **Tag-based cleanup** | Prevents forgotten resources | 30 seconds per resource |
| **Auto-termination (TTL)** | Prevents overnight costs | Built into Spore.host (see SPOREHOST_TEASER.md) |

**Total potential annual savings**: $5,000-$50,000+ for typical researcher

---

#### The Key Insight

> **"Console may seem easier, but it's error-prone and not repeatable.**
> **CLI is better because it's scriptable.**
> **Spore.host is best: simple AND scriptable."**

**Your research requires reproducibility. Your future self will thank you.**

---

#### Resources

**AWS**:
- AWS Research Credits: https://aws.amazon.com/research-credits/
- GDEW Information: aws.amazon.com/government-education/research-and-technical-computing/data-egress-waiver/
- AWS for Research: https://aws.amazon.com/government-education/research/

**Spore.host**:
- Quick start: See **SPOREHOST_TEASER.md** (distributed with this workshop)
- GitHub: https://github.com/scttfrdmn/mycelium

**CU Boulder**:
- Research Computing: https://www.colorado.edu/rc/
- Workshop materials: https://github.com/scttfrdmn/aws-research-computing-workshop

---

#### Next Steps

**Today**:
1. Run your cleanup script!
2. Check your AWS credits balance
3. Remember: GDEW credit on egress costs is already applied through CU's AWS agreement

**This Week**:
1. Read SPOREHOST_TEASER.md and try `truffle find` (no AWS account needed!)
2. Apply for AWS Research Credits
3. Set up budget alerts for your real account

**This Month**:
1. Use Spot instances for your batch processing
2. Move old data to Glacier (save 90%)
3. Share what you learned with lab mates

---

#### Questions?

**Thank you for attending!** 🎉

**Remember**: Tag everything, use Spot, check your credits, GDEW credit is already applied!

---

---

## 2:00+ | Bonus: Spore.host Teaser (for those staying)

> **Hard stop was at 2:00. This is entirely optional — participants are free to leave.**

You've just done five steps of pre-flight just to launch one instance. This is the AWS tax. Spore.host (`truffle` + `spawn`) eliminates it.

See **SPOREHOST_TEASER.md** for the full reference. Quick taste:

```bash
# Install
curl -L https://github.com/scttfrdmn/mycelium/releases/latest/download/mycelium-$(uname -s)-$(uname -m).tar.gz | tar xz
export PATH=$PATH:$PWD/mycelium/bin

# Search in plain English — no AWS account needed
truffle find "large amd"             # Find m6a instances
truffle find h100                    # Finds p5.48xlarge (H100 GPU)

# Launch with auto-termination — press Enter through defaults
spawn

# Everything running, across all regions, with cost/hr
spawn list

# Find cheapest Spot + launch in one line
truffle spot "m6a.*" --sort-by-price | spawn --spot --ttl 8h
```

> "Console for learning. CLI for scripts. **Spore.host for production research.**"

📄 **SPOREHOST_TEASER.md**: installation, all commands, real research examples (genomics, GPU, parallel jobs), Workshop 2 preview.

---

## Workshop Materials Provided

📄 **AGENDA.md** - This document
📄 **CURRICULUM.md** - Complete 2-hour workshop curriculum with all commands
📄 **INSTRUCTOR_NOTES.md** - Teaching guide, timing, troubleshooting
📄 **QUICK_REFERENCE.md** - Command reference for participants
📄 **CONSOLE_QUICK_REFERENCE.md** - Where to find things in Console
📄 **INSTRUCTOR_LIVE_DEMO.md** - What to show on the projector at each step
📄 **REMOTE_ACCESS_AND_TRANSFER.md** - SSH connection, Jupyter port forwarding, rclone, Cyberduck, WinSCP, VS Code Remote SSH

---

## Pre-Workshop Checklist

**1 Week Before**:
- [ ] Send participant email with AWS account setup instructions
- [ ] Share pre-reading materials (optional)

**1 Day Before**:
- [ ] Test AWS account access
- [ ] Launch test instance to verify quotas
- [ ] Download Spore.host binaries to USB drive (backup)
- [ ] Print CONSOLE_QUICK_REFERENCE.md (1 per participant)

**30 Min Before**:
- [ ] Test AV setup (projector, mic)
- [ ] Write WiFi password on whiteboard
- [ ] Launch test instance (verify no issues)
- [ ] Have cleanup script ready on screen

---

**Workshop Version**: 2.0 (Modern 2026 Edition)
**Last Updated**: March 2026
**Prepared for**: CU Boulder Research Computing Team

**Total Duration**: Exactly 2:00:00 ⏱️
