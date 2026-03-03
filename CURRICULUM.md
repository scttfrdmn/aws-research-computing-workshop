# Introduction to AWS for Research Computing: From Campus HPC to Cloud

**Duration**: 2 hours
**Target Audience**: Researchers new to cloud computing, transitioning from on-premises HPC systems
**Prerequisites**: No prior cloud experience required

---

## Workshop Overview

### The honest version

**AWS was built for Netflix, not for you.**

It runs 200+ services with thousands of configuration options, designed by infrastructure engineers for infrastructure engineers. When AWS says "easy," they mean "easy if you already know what a VPC, IAM role, and security group are."

The good news: you only need about 5% of AWS to do serious research computing — EC2 for compute, S3 for storage, a bit of IAM for permissions, and some safety features so you don't get a surprise bill. That's this workshop.

AWS is powerful enough to run the internet. Your genomics pipeline is well within reach.

---

### Learning Objectives

By the end of this workshop, you will be able to:

1. Complete a pre-flight check (region, VPC, security group, IAM role) before launching anything
2. Launch an EC2 instance with the correct settings and connect via browser terminal — no SSH keys
3. Create S3 buckets for research data storage and complete the full research loop: pull data → analyze → push results back
4. Set up budget alerts and understand AWS cost monitoring tools
5. Check your AWS credits balance and understand the Global Data Egress Waiver (GDEW) credit already applied through CU's AWS agreement
6. Clean up all resources using tag-based filtering

CLI equivalents are shown as optional sidebars throughout — useful for automating your work later.

---

### Using the CLI in this workshop

The primary path is the AWS Console (point and click). CLI commands are shown as **optional sidebars** for those who want them.

**The easiest way to run CLI commands — on any OS including Windows:**

> **AWS CloudShell** — click the `>_` icon in the top navigation bar of the AWS Console. It's a browser-based Linux terminal, pre-authenticated, no installation needed. This is the recommended CLI option for this workshop.

If you prefer a local terminal: macOS/Linux Terminal works as-is. Windows users need Git Bash or WSL.

---

### Workshop Structure (2 hours)

```
0:00 - 0:08  Introduction
0:08 - 0:18  Lab 0: Pre-flight check (region, VPC, security group, auth, IAM role)
0:18 - 0:50  Lab 1: Launch EC2 & Store Data in S3 (32 min)
0:50 - 1:00  Break
1:00 - 1:45  Lab 2: Cost Management & Data Transfer (45 min)
1:45 - 2:00  Wrap-up & Resources (15 min)
2:00+        Bonus: spore.host teaser (for those who want to stay)
```

---

## Introduction & Motivation (8 minutes)

### AWS is for Netflix — and for you

AWS runs Netflix, Airbnb, NASA, and Amazon.com itself. It's engineered for scale most of us will never need. That's why it can feel overwhelming: you're looking at infrastructure designed to serve hundreds of millions of users, and you just want to run a GATK pipeline.

Here's what actually matters for research computing:

| What you need | AWS service | Plain English |
|---|---|---|
| A computer to run code on | **EC2** | "Elastic Compute Cloud" — rent a server |
| A place to store data | **S3** | "Simple Storage Service" — like a hard drive in the cloud |
| Permissions management | **IAM** | "Identity & Access Management" — who can do what |
| Cost guardrails | **Budgets** | Email alerts before you overspend |

Everything else in AWS is optional for now.

### Where you're coming from

This workshop is designed for two groups of people. Both are welcome. Both will get something different out of it.

**If you use campus HPC (Alpine, Blanca, or similar)**:

You know `sbatch` or `qsub`. You've waited in the queue. You've run `module load python/3.9` to get software. Your files live on `/projects` or `/scratch`.

Think of AWS this way:
- **EC2** = your own dedicated node, available in 60 seconds — no queue, no sharing
- **S3** = a data store that scales to petabytes and persists forever — accessed by commands, not file paths (unlike `/scratch`)
- **Conda or containers** = your `module load` equivalent
- **IAM roles** = permissions (think: group ownership on a shared filesystem)
- **Spot instances** = like a preemptible queue, but you control it

The main adjustment: you're billed by the hour, so you'll learn to stop instances when not in use. That's the tradeoff for instant access.

**If you work on your laptop**:

Your analysis runs locally — limited by your RAM (probably 8-32 GB) and CPU (4-16 cores). Jobs run overnight and your laptop can't close. Moving to a bigger dataset means waiting a week for results.

Think of AWS this way:
- **EC2** = a powerful remote computer that doesn't need to stay awake
- **S3** = a hard drive that doesn't fill up and doesn't fail
- **Instance types** = choosing how powerful a machine to rent, for exactly as long as you need it

The main adjustment: you're renting hardware, not owning it. The goal is to spin it up when you need it and shut it down when you don't.

---

### Two tools, one researcher

| Situation | Use Cloud | Use Campus HPC |
|---|---|---|
| Queue wait > 2 hours | ✅ | |
| Need more cores than campus quota allows | ✅ | |
| Collaborators outside CU need access | ✅ | |
| GPU workload when campus GPUs are busy | ✅ | |
| Routine batch jobs within campus quota | | ✅ |
| Long-running 24/7 services | | ✅ (or dedicated server) |

**Cost reality**: Cloud is cost-effective for burst workloads.

| Workload | Campus HPC | AWS On-Demand | AWS Spot |
|---|---|---|---|
| 8-core compute, 8 hours | Free (if available) | $3.20 | $0.96 |
| GPU (g5.xlarge), 4 hours | Free (if quota permits) | $4.02 | $1.20 |
| 1TB storage, 1 month | Free (campus) | $23.00 | — |

**Key insight**: Cloud is not cheaper than free campus resources — it's available *right now*, without a queue.

---

## Lab 0: Pre-flight Check (10 minutes)

**Do this before anything else.** These steps prevent the most common "nothing is working" problems.

### Step 1: Set your region (30 seconds)

Look at the top-right corner of the AWS Console. You'll see a region name like "N. Virginia" or "Ohio."

**Change it to: `US West (Oregon) — us-west-2`**

Click the region name → select "US West (Oregon)."

⚠️ Everything in this workshop assumes us-west-2. AMI IDs, pricing, and resources are region-specific. If your region is wrong, nothing will match.

---

### Step 2: Verify your default VPC exists (1 minute)

A VPC (Virtual Private Cloud) is the private network your instances run in. AWS creates a default one per region, but it can be missing in cleaned-up accounts.

**Console**: Type "VPC" in the search bar → VPC Dashboard → look for "Default VPC: Yes" in the list.

**CloudShell** (click `>_` in the top nav):
```bash
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
    --query 'Vpcs[0].VpcId' --output text
```
Should return something like `vpc-0abc1234`. If it returns `None`, tell your instructor — you need to create a default VPC before continuing.

> **If no default VPC**: VPC Console → "Actions" → "Create default VPC." Takes 30 seconds.

---

### Step 3: Create a workshop security group (2 minutes)

A security group is a firewall that controls what traffic can reach your instance. Without the right rules, you can't connect to your instance — and the error is just a silent timeout.

**Console**:
1. Type `Security Groups` in the top search bar → click **EC2 > Security Groups**

![Search bar showing EC2 > Security Groups result](SCREENSHOTS/01-security-group-search.png)

2. Click **Create security group**
3. **Name**: `workshop-sg`
4. **Description**: `Workshop: allow SSH`
5. **VPC**: select the default VPC
6. **Inbound rules** → Add rule: Type **SSH**, Source **Anywhere-IPv4** (0.0.0.0/0)
7. Click **Create security group**

> **Note**: "Anywhere-IPv4" (0.0.0.0/0) is acceptable for a workshop. In production, use the EC2 Instance Connect prefix list (`com.amazonaws.us-west-2.ec2-instance-connect`) to restrict to only AWS's connection service IPs.

---

### Step 4: Verify AWS CLI authentication (30 seconds)

Open **CloudShell** (click `>_` in the top nav bar) and run:

```bash
aws sts get-caller-identity
```

You should see your account ID, user ARN, and user ID. If you get an error, talk to your instructor before continuing.

---

### Step 5: Create the IAM role for EC2 (2 minutes)

This role lets your EC2 instance access S3. Create it now so you can select it during launch — no mid-wizard detour.

1. Type `IAM` in the top search bar → click **IAM**
2. In the left menu: **Roles** → **Create role**
3. Trusted entity: **AWS service** → Use case: **EC2** → **Next**
   *(This tells AWS that EC2 instances are allowed to assume this role — they'll automatically have its permissions at launch)*
4. Search `AmazonS3FullAccess`, check the box → **Next**
5. Role name: `ec2-workshop-role` → **Create role**

Done. You'll pick this role from a dropdown during the EC2 launch in Lab 1.

---

✅ **Pre-flight complete.** You have: the right region, a working VPC, a security group, CLI access, and an IAM role ready to attach. Now let's launch something.

> 💡 **Notice anything?** You just completed five setup steps before launching a single instance. This is the AWS tax — configuration overhead that exists regardless of what you actually want to compute. It's also exactly what spore.host is designed to eliminate: `spawn` handles all of this automatically.

---

## Hands-On Lab 1: Launch EC2 & Store Data in S3 (32 minutes)

### Part A: Launch Your First EC2 Instance (15 min)

The Console is the primary method. A CLI sidebar follows for those who want to automate this later.

> **⚠️ AWS UX warning**: One critical setting is buried at the bottom of the launch page under **"Advanced details."** The name implies it's optional — it's not. Before clicking Launch, scroll to the bottom, expand that section, and set your IAM role. We'll call this out explicitly in Step 7 below.

![Advanced details section collapsed at bottom of launch page](SCREENSHOTS/02-advanced-details-collapsed.png)

#### AWS Console — Launch an Instance

**Step 1: Navigate to EC2**
1. Search for "EC2" in the top search bar → click **EC2**
2. Click **"Launch instance"** (orange button)

**Step 2: Name and tags**
- **Name**: `research-compute-01`
- Click **"Add new tag"** (just below the Name field)
  - Key `Workshop` / Value `cu-boulder-2026`
  - Key `Owner` / Value `your-name`
  - Without tags, the one-command cleanup at the end won't find your instance.
- **AMI**: Amazon Linux 2023 (already selected — this is fine)
  - *Amazon Linux 2023 is AWS's own Linux, pre-configured and free-tier eligible*

**Step 3: Instance type**
- Select `m6a.xlarge` (4 vCPUs, 16 GB RAM, ~$0.173/hr)
- *This is a realistic size for research computing — enough RAM for most bioinformatics, data processing, and analysis workflows*
- *t3 instances are for web servers, not research — they'll frustrate you when you try real workloads*

**Step 4: Key pair**
- From the dropdown, select **"Proceed without a key pair"** — we'll connect using EC2 Instance Connect (browser-based, no key file needed)
- *If you skip this and click Launch without selecting anything, a confirmation dialog will appear — click **"Proceed without key pair"** there instead. Either path gets you to the same place.*
- *If you already have an AWS key pair, you can select it — either works*

**Step 5: Network settings**
- Click **"Edit"**
- **Security group**: Select existing → choose **`workshop-sg`** (from Lab 0)
- **Auto-assign public IP**: change to **"Enable"** — set this explicitly, 

![Auto-assign public IP dropdown set to Enable](SCREENSHOTS/03-public-ip-enable.png)

> **Why the public IP matters**: EC2 Instance Connect requires a public IP to reach your instance. If this is left on "Disable", Instance Connect will fail with no useful error message. Always set it explicitly to Enable.

**Step 6: Storage**
- 8 GB gp3 (default) — fine for testing
- For real research data: attach a larger volume or use S3

**Step 7: Advanced details → IAM instance profile** *(scroll to bottom of page, expand "Advanced details")*
- Find **"IAM instance profile"** → select **`ec2-workshop-role`**
- Without this, your instance gets "Access Denied" on any S3 command.

![Advanced details expanded showing IAM role selected](SCREENSHOTS/04-advanced-details-expanded.png)

**Step 8: Launch**
- Click **"Launch instance"** → wait ~60 seconds until state shows **"running"**

**Step 9: Connect to your instance**

1. In EC2 → Instances, check the box next to your running instance
2. Click **"Connect"** (in the action bar above the instance list) — this opens the "Connect to instance" page
3. Click the **"EC2 Instance Connect"** tab (first tab on the left)
4. Leave all settings as default: Connection type = Public IP, Username = ec2-user
5. Click the orange **"Connect"** button

> ⚠️ **Wrong tab?** The page may open on "SSM Session Manager" — if you see DHMC/SSM error messages, click **EC2 Instance Connect** (first tab on the left) instead.

![EC2 Instance Connect tab selected, Connect button visible](SCREENSHOTS/05-instance-connect-tab.png)

6. A terminal opens in your browser — you're in.

> **EC2 Instance Connect** is browser-based and requires no SSH keys or local software. It works because `workshop-sg` allows port 22 and your instance has a public IP.
>
> 💡 **Check the IAM role**: The Connect page shows a summary bar with Instance ID, VPC ID, Security groups, and IAM role. If IAM role shows "–", your instance doesn't have `ec2-workshop-role` attached — S3 commands will fail with Access Denied. Stop the instance, attach the role under Actions → Security → Modify IAM role, then start it again.

> 💡 **While you're here — start this now.** Run the following in your Instance Connect terminal. It takes about 60 seconds and will be ready by Lab 2:
> ```bash
> curl -sL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o miniforge.sh
> bash miniforge.sh -b -p $HOME/miniforge3 && echo "Miniforge ready."
> ```
> **Leave this browser tab open** — if you close Instance Connect you'll need to reconnect, and you'll need to `source $HOME/miniforge3/bin/activate` again before Lab 2. The files stay on the instance; only the terminal session is lost.

---

#### 💻 CLI Sidebar: Launch an instance from the command line

*Skip this if the Console worked for you. Use **AWS CloudShell** (click `>_` in the top nav bar) — no installation needed, works on any OS.*

```bash
# Get the current Amazon Linux 2023 AMI for us-west-2 (recommended — always up to date)
AMI_ID=$(aws ssm get-parameters \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --region us-west-2 \
    --query 'Parameters[0].Value' --output text)

# Get your workshop-sg ID
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=workshop-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)

# Launch with IAM role and tags (for cleanup later)
aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type m6a.xlarge \
    --iam-instance-profile Name=ec2-workshop-role \
    --security-group-ids $SG_ID \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Name,Value=research-compute-cli},{Key=Workshop,Value=cu-boulder-2026},{Key=Owner,Value=your-name}]' \
    --count 1

# Get instance ID once running
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=research-compute-cli" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)

# Connect (no SSH key needed)
aws ec2-instance-connect ssh --instance-id $INSTANCE_ID
```

---

#### 💡 Stop and Restart Instances (Save Money When Not Using Them)

**The Problem**: Running instances cost money 24/7, even when idle.

**The Solution**: Stop instances when not using them!

**Cost Savings**:
- **Running**: Pay for compute + storage ($0.173/hour for m6a.xlarge = $125/month 24/7)
- **Stopped**: Pay only for storage (~$0.64/month for 8 GB EBS volume)
- **Terminated**: Pay nothing (but lose everything)

**When to Stop vs Terminate**:
| Action | When to Use | Cost | Data Persists? |
|--------|-------------|------|----------------|
| **Stop** | Done for the day, will use tomorrow | Storage only (~$0.64/mo for 8 GB) | ✅ Yes |
| **Terminate** | Done forever, don't need again | $0 | ❌ No (gone!) |

---

**Console Method**: Stop Instance

1. EC2 → Instances
2. Select your instance
3. **Instance state** → **Stop instance**
4. Wait 30-60 seconds (state changes to "stopped")

**Later**: Start it again
1. Select stopped instance
2. **Instance state** → **Start instance**
3. EC2 Instance Connect works fine after restart — it finds the new IP automatically

**💡 Pro tips**:
- Stop overnight/weekends → save 60-70% on monthly costs
- Your data stays intact — only compute charges stop

---

#### 💻 CLI Sidebar: Stop and start

*CloudShell or local terminal. `$INSTANCE_ID` from the launch sidebar above.*

```bash
aws ec2 stop-instances --instance-ids $INSTANCE_ID

# Later: restart
aws ec2 start-instances --instance-ids $INSTANCE_ID

# Connect (Instance Connect handles the new public IP automatically)
aws ec2-instance-connect ssh --instance-id $INSTANCE_ID
```

---

#### 💰 Know About Spot Instances (2 minutes)

Spot instances are unused EC2 capacity sold at 50-90% discount. They can be interrupted with a 2-minute warning — AWS needs the capacity back and will terminate your instance.

**Use Spot for**: genomics pipelines, simulations, ML training, anything that checkpoints to S3
**Don't use Spot for**: databases, interactive sessions, anything that can't restart

| Instance | On-Demand | Spot | Savings |
|---|---|---|---|
| m6a.xlarge | $0.173/hr | ~$0.052/hr | 70% |
| g5.xlarge (GPU) | $1.006/hr | ~$0.30/hr | 70% |

**Why not Spot today**: To use Spot safely, your workflow needs to handle being terminated mid-run — saving checkpoints to S3, resuming from where it left off. That's a design pattern, not just a launch flag. We haven't covered that yet. Launching Spot without it means losing work when the instance disappears.

*When you're ready: in the EC2 launch wizard, "Advanced details" → "Purchasing option" → check "Spot instance." See **QUICK_REFERENCE.md** for the CLI flag.*

---

### Part B: Set Up S3 for Research Data (12 min)

#### AWS Console

**Step 1: Create bucket**
1. Search for "S3" in the top bar → click **S3**
2. Click **"Create bucket"**
3. **Bucket name**: `rcws-yourname-0302` (replace `0302` with today's date — the date prevents name collisions if the workshop runs again)
4. **Region**: us-west-2
5. **Block Public Access**: leave all checked (default — this is correct)
6. Click **"Create bucket"**

**Step 2: Upload a test file**
1. Click on your bucket name
2. Click **"Upload"** → drag a file or click "Add files" → **"Upload"**

> 💡 **For later**: S3 can automatically move old data to cheaper storage (Glacier) — 80-95% savings. When you're ready to explore that, see **QUICK_REFERENCE.md** for the lifecycle policy commands.

---

#### 💻 CLI Sidebar: Create bucket and upload

*Use CloudShell. Replace `yourname` with something unique.*

```bash
BUCKET_NAME="rcws-yourname-0302"  # replace 0302 with today's date
aws s3 mb s3://$BUCKET_NAME --region us-west-2

echo "Research data test" > test-data.txt
aws s3 cp test-data.txt s3://$BUCKET_NAME/
```

---

## Break (10 minutes)

---

## Hands-On Lab 2: Cost Management & Data Transfer (45 minutes)

### Part A: Set Up Cost Alerts (15 min)

> A forgotten instance running over a weekend costs ~$10 (m6a.xlarge × ~60 hours). A stopped-but-not-terminated instance for a month costs ~$0.64 in storage (8 GB default). This 5-minute setup is your safety net.

#### AWS Budgets - Console Method

**Step 1: Navigate to AWS Budgets**
1. Search for "Billing" or "Budgets" in Console
2. Click "Budgets" in left menu
3. Click "Create budget"

**Step 2: Configure Budget**
- **Budget type**: Cost budget
- **Period**: Monthly
- **Budget amount**: $50 (adjust for your needs)
- **Budget name**: `research-monthly-budget`

**Step 3: Set Alerts**
- Alert threshold: 80% of budgeted amount
- Email: your email
- Create budget

**You'll get an email when you hit $40 of $50 budget**

---

#### Cost Explorer - See What You're Spending

**Console Method:**
1. Go to "Cost Explorer" in Billing
2. Click "Launch Cost Explorer"
3. View: "Cost and Usage"
4. Group by: "Service"
5. Filter: Last 7 days

**See exactly**: EC2 costs, S3 costs, data transfer costs

---

#### 💻 CLI Sidebar: Create a budget

> **Note**: This is one case where the Console method above is genuinely easier — the CLI requires an inline JSON blob. Use this only if you need to script budget creation across multiple accounts.

*Use CloudShell. Replace the email address.*

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws budgets create-budget \
    --account-id $ACCOUNT_ID \
    --budget '{"BudgetName":"research-monthly-budget","BudgetLimit":{"Amount":"50","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}' \
    --notifications-with-subscribers '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"your.email@colorado.edu"}]}]'
```

---

#### Check Your AWS Credits (Console Method)

**Many researchers have AWS credits but don't know it!**

**Step 1: Navigate to Credits**
1. Click on your account name (top right) → "Billing and Cost Management"
2. In left sidebar, click "Credits"
3. View your credits:
   - **Active credits**: Available now
   - **Expiration date**: When they expire
   - **Applied to date**: How much you've used

**Common Credit Sources**:
- AWS Research Credits Program (apply at aws.amazon.com/research-credits)
- AWS Educate (for students/faculty)
- Conference/event promotions

**Pro Tip**: Credits are applied automatically to your bill each month!

---

#### AWS Global Data Egress Waiver (GDEW)

**What is it?**
- Downloading data from AWS normally costs $0.09/GB
- The GDEW provides a **credit toward data egress costs** for eligible academic institutions
- The credit is capped at a percentage of CU's institutional AWS spending (not individual accounts)
- For researchers who download significant data, this can represent meaningful savings

**For CU researchers**: The GDEW is already applied through CU Boulder's AWS agreement — there is nothing you need to do individually.

💡 **If you download significant data volumes, the GDEW credit applies automatically. Contact CU Boulder Research Computing if you have questions about your account.**

---

### Part B: Transfer Data to S3 (15 min)

#### Upload from your laptop to S3

**Console** (drag and drop for small files):
1. S3 → your bucket → **"Upload"** → drag files → **"Upload"**

**For real research data volumes**: the CLI is much more practical.

#### 💻 CLI Sidebar: Upload, sync, and access data

*Use CloudShell, or your local terminal on macOS/Linux. `$BUCKET_NAME` from Lab 1.*

```bash
# Upload a single file
aws s3 cp large-dataset.tar.gz s3://$BUCKET_NAME/datasets/

# Upload an entire directory (with progress)
aws s3 sync /path/to/research/data s3://$BUCKET_NAME/data/ --progress

# Large files (>5GB): CLI does multipart automatically
aws s3 cp 50GB-genome-data.tar.gz s3://$BUCKET_NAME/genomics/
```

**For datasets >10TB**: rclone with `--transfers 16` handles most research-scale transfers. For very large or recurring transfers, contact your institution's research computing team — campus HPC often has Globus endpoints or dedicated transfer nodes for exactly this.

---

#### Run an analysis and get results back

> **Before starting**: Two things to check after the break:
> 1. **Instance Connect tab** — if you closed it, reconnect: EC2 → your instance → Connect → EC2 Instance Connect
> 2. **`$BUCKET_NAME` in CloudShell** — CloudShell sessions time out. If your variable is gone, re-set it:
>    ```bash
>    BUCKET_NAME="rcws-yourname-0302"  # same name you used in Lab 1 — replace 0302 with today's date
>    ```

This is the complete research workflow.

**Activate miniforge and install numpy** (miniforge was installed during Lab 1):

```bash
source $HOME/miniforge3/bin/activate
mamba install -y numpy    # ~30 seconds
```

> 💡 **If you use conda on your laptop**, this is exactly the same workflow — `source activate`, `mamba install`. The cloud instance is just a more powerful version of your local machine, with S3 instead of a local drive.
>
> **If you come from campus HPC**, this replaces `module load python/3.x` — you own the environment and can install anything without waiting for sysadmin.

**Pull your data from S3, run analysis, push results back:**

```bash
# Pull your test data down from S3
# (works because ec2-workshop-role was attached during instance launch in Lab 1)
aws s3 cp s3://$BUCKET_NAME/test-data.txt ./

# Run analysis — replace this with your real script
python3 -c "
import numpy as np

# Read input data from S3
with open('test-data.txt') as f:
    print(f'Input: {f.read().strip()}')

# Simulating: 100 samples x 50 measurements (e.g., gene expression, metabolite levels)
np.random.seed(42)
data = np.random.exponential(scale=10.0, size=(100, 50))
np.savetxt('results.csv',
    np.column_stack([data.mean(axis=0), data.std(axis=0)]),
    delimiter=',', header='mean,std', comments='')
print(f'Done: {data.shape[0]} samples, {data.shape[1]} features')
print(f'Mean range: {data.mean(axis=0).min():.2f} - {data.mean(axis=0).max():.2f}')
"

# Push results to S3
aws s3 cp results.csv s3://$BUCKET_NAME/results/results.csv
echo "Results in S3."
```

**Retrieve results** — from CloudShell or your laptop terminal:

```bash
aws s3 cp s3://$BUCKET_NAME/results/results.csv ./
```

*That's the complete loop: launch instance → pull data from S3 → run analysis → push results to S3 → retrieve anywhere. In real workflows you'd bake your software stack into a custom AMI or user-data script so the conda install happens automatically at launch.*

---

### Part C: Clean Up (10 min)

**IMPORTANT**: Always terminate instances when done!

#### EC2: Tag-Based Cleanup

**Console**:
1. EC2 → Instances → click the search bar → type `Workshop`
2. A dropdown appears showing Workshop tag values — click **"Workshop = All values"**
3. Select all → **Instance state** → **Terminate (delete) instance**

![Instances filtered by Workshop tag with all selected for termination](SCREENSHOTS/06-tag-filter-cleanup.png)

#### S3: Manual Cleanup

1. S3 → click your bucket → **Empty** (confirms deletion) → **Empty**
2. Back to bucket list → select bucket → **Delete** → type bucket name → **Delete bucket**

---

#### 💻 CLI Sidebar: Terminate by tag (CloudShell)

*This is the fastest way to clean up everything at once.*

```bash
# See what you're about to terminate
aws ec2 describe-instances \
    --filters "Name=tag:Workshop,Values=cu-boulder-2026" \
    --query 'Reservations[].Instances[].[InstanceId,Tags[?Key==`Name`].Value|[0],State.Name]' \
    --output table

# Terminate all workshop instances
aws ec2 terminate-instances --instance-ids $(
    aws ec2 describe-instances \
        --filters "Name=tag:Workshop,Values=cu-boulder-2026" \
                  "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text
) && echo "All workshop instances terminated!"
```

**S3 cleanup** (replace `yourname` with what you used in Lab 1):
```bash
BUCKET_NAME="rcws-yourname-0302"  # replace 0302 with today's date
aws s3 rm s3://$BUCKET_NAME/ --recursive
aws s3 rb s3://$BUCKET_NAME
echo "S3 cleanup complete!"
```

💡 **Why this works**: Every resource you created has the tag `Workshop=cu-boulder-2026`. Typing `Workshop` in the search bar lets the console find all instances with that tag key — no need to know the exact value.

---

## Wrap-Up & Resources (15 minutes)

### What You Learned Today

✅ Lab 0 pre-flight: region, VPC, security group, IAM role — before anything else
✅ Launch EC2 instances with the right settings (IAM role, public IP, tags)
✅ Connect via EC2 Instance Connect — no SSH keys
✅ Install miniforge and run an analysis on the instance
✅ Store research data in S3, retrieve results anywhere
✅ Set up budget alerts to prevent surprise bills
✅ Know about Spot instances and why they need checkpointing first
✅ Clean up all resources with tag-based termination
✅ Know about spore.host for faster daily workflows (see SPOREHOST_TEASER.md)

---

### Cost Estimation for Your Research

**Example Monthly Research Budget**:
- 2 m6a.xlarge instances × 40 hours/month = $13.84
- 100GB S3 storage = $2.30
- 1TB data transfer in = $0 (free)
- 10GB data transfer out = $0.90
- **Total: ~$17/month**

**Example GPU Training**:
- 1 g5.xlarge (A10G GPU) × 20 hours/month = $20.12
- 500GB S3 storage = $11.50
- **Total: ~$32/month**

---

### Next Steps

1. **Try it with your data**: Start small — one instance, a dataset you know well
2. **Apply for AWS Research Credits**: Free credits for researchers — 10-minute application at aws.amazon.com/research-credits
3. **GDEW is already applied**: A credit toward data egress costs is applied automatically through CU's AWS agreement — no action needed
4. **Workshop 2 — spore.host for Production**: Job arrays, data staging, Spot with checkpointing. See **SPOREHOST_TEASER.md** to preview what's coming.

---

### Resources

**AWS for Research**:
- AWS Research Credits: https://aws.amazon.com/research-credits/
- AWS Pricing Calculator: https://calculator.aws/

**spore.host**:
- Quick start: See **SPOREHOST_TEASER.md** (distributed with this workshop)
- GitHub: https://github.com/scttfrdmn/mycelium

**CU Boulder**:
- Research Computing: https://www.colorado.edu/rc/

---

## Bonus: spore.host — A Better Way (post-workshop, for those staying)

> **Hard stop at 2 hours. This section is for participants who want to stay a few extra minutes.**
>
> **See SPOREHOST_TEASER.md for the full reference and Workshop 2 preview.**

You've just experienced the gap between learning and daily use:
- **Console**: Easy to start, but not repeatable
- **CLI**: Repeatable, but verbose

spore.host (two tools: `truffle` + `spawn`) closes that gap.

**Quick taste**:
```bash
# Install
curl -L https://github.com/scttfrdmn/mycelium/releases/latest/download/mycelium-$(uname -s)-$(uname -m).tar.gz | tar xz
export PATH=$PATH:$PWD/mycelium/bin

# Search by plain English — no AWS account needed!
truffle find h100              # Finds p5.48xlarge (H100 GPU)
truffle find "large amd"       # Find large AMD instances

# Launch interactively (just press Enter 4 times through the defaults)
spawn

# See everything running across all regions
spawn list

# Find cheapest Spot + launch in one line
truffle spot "m7i.*" --sort-by-price | spawn --spot --ttl 8h
```

> "Console for learning. CLI for scripts. **spore.host for real research work.**"

📄 **See SPOREHOST_TEASER.md** for: installation, all commands, real research examples (genomics, GPU, parallel jobs), and a preview of Workshop 2 (spore.host for Production).
