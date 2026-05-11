# Introduction to AWS for Research Computing: Launch Template Edition

**Duration**: 2 hours
**Target Audience**: Researchers new to cloud computing, transitioning from on-premises HPC systems
**Prerequisites**: No prior cloud experience required
**Variant**: This version uses a Launch Template to automate instance configuration, so you spend less time on setup and more time on research workflows. The [standard version (CURRICULUM.md)](CURRICULUM.md) walks through every setting by hand — worth doing once to understand what's happening.

---

## Workshop Overview

See [CURRICULUM.md — Workshop Overview](CURRICULUM.md#workshop-overview) for the full motivation, AWS primer, augmentation framing, and cost comparison. Everything there applies here. The difference is in how you launch an instance.

**The short version**: instead of configuring 8 settings every time you launch, you configure them once in a Launch Template. Future launches — including every time you repeat this workshop — take about 30 seconds.

---

### Workshop Structure (2 hours)

```
0:00 - 0:08  Introduction
0:08 - 0:20  Lab 0: Pre-flight check (one-time account setup)
0:20 - 0:40  Lab 1: Create the Launch Template (one-time)
0:40 - 0:50  Lab 2: Launch from Template & Connect
0:50 - 1:00  Lab 3: S3 for Research Data
1:00 - 1:10  Break
1:10 - 1:25  Lab 4: Cost Management
1:25 - 2:00  Lab 5: Analysis — Pull, Run, Push
2:00+        Bonus: spore.host teaser
```

---

## Introduction & Motivation (8 minutes)

See [CURRICULUM.md — Introduction & Motivation](CURRICULUM.md#introduction--motivation-8-minutes).

---

## Lab 0: Pre-flight Check (12 minutes)

> **This lab is one-time setup.** Once your account has a default VPC, a workshop security group, and an IAM role, you never need to repeat these steps — not for future workshops, not for your own research. Do it once, move on.

### Step 1: Set your region (30 seconds)

Look at the top-right corner of the AWS Console. You'll see a region name like "N. Virginia" or "Ohio."

**Change it to: `US West (Oregon) — us-west-2`**

Click the region name → select "US West (Oregon)."

⚠️ Everything in this workshop assumes us-west-2. AMI IDs, pricing, and resources are region-specific. If your region is wrong, nothing will match.

---

### Step 2: Verify your default VPC exists (1 minute)

**Console**: Type "VPC" in the search bar → VPC Dashboard → click on the VPC ID → in the Details panel, confirm "Default VPC" shows "Yes".

**CloudShell** (click `>_` in the bottom bar):
```bash
aws ec2 describe-vpcs --filters "Name=isDefault,Values=true" \
    --query 'Vpcs[0].VpcId' --output text
```
Should return something like `vpc-0abc1234`. If it returns `None`, tell your instructor.

> **If no default VPC**: VPC Console → "Actions" → "Create default VPC." Takes 30 seconds.

---

### Step 3: Create a workshop security group (2 minutes)

**Console**:
1. Type `Security Groups` in the top search bar → click **EC2 > Security Groups**
2. Click **Create security group**
3. **Name**: `workshop-sg`
4. **Description**: `Workshop: allow SSH`
5. **VPC**: select the default VPC
6. **Inbound rules** → Add rule: Type **SSH**, Source **Anywhere-IPv4** (0.0.0.0/0)
7. Click **Create security group**

> **Note**: "Anywhere-IPv4" is acceptable for a workshop. In production, restrict to the EC2 Instance Connect prefix list.

---

### Step 4: Verify AWS CLI authentication (30 seconds)

Open **CloudShell** and run:

```bash
aws sts get-caller-identity
```

You should see your account ID, user ARN, and user ID.

---

### Step 5: Create the IAM role for EC2 (2 minutes)

This role lets your instance access S3. Create it once — the Launch Template will reference it.

1. Type `IAM` in the search bar → **IAM**
2. Left menu: **Roles** → **Create role**
3. Trusted entity: **AWS service** → Use case: **EC2** → **Next**
4. Search `AmazonS3FullAccess`, check the box → **Next**
5. Role name: `ec2-workshop-role` → **Create role**

---

✅ **Pre-flight complete.** Right region, working VPC, security group, CLI access, IAM role. You'll never need to do this again for this account.

---

## Lab 1: Create the Launch Template (20 minutes)

> **This lab is also one-time.** The Launch Template stores your preferred configuration — AMI, instance type, storage, IAM role, security group, and the user-data script that installs your software at boot. Every future launch takes 30 seconds.

A Launch Template stores a named configuration. Launch from it and every setting is pre-filled — you only add a name, tags, and enable the public IP. The user-data section at the end of this lab also installs an auto-stop script (see **AUTO_STOP.md**) so instances shut themselves down after a configurable idle period.

### Step 1: Navigate to Launch Templates

EC2 → left sidebar: **Launch Templates** → **Create launch template**

---

### Step 2: Template name and description

- **Launch template name**: `workshop-research-template`
- **Template version description**: `Baseline: AL2023, m6a.xlarge, miniforge, research env`
- **Auto Scaling guidance**: leave unchecked

---

### Step 3: AMI

Under **Application and OS Images**:
- Click **Quick Start** → select **Amazon Linux**
- Choose **Amazon Linux 2023 AMI** (64-bit x86)

---

### Step 4: Instance type

- **Instance type**: `m6a.xlarge` (4 vCPUs, 16 GB RAM, ~$0.173/hr)

---

### Step 5: Key pair

- Select **"Don't include in launch template"** — we connect via EC2 Instance Connect, no key file needed.

---

### Step 6: Network settings

- **Firewall (security groups)**: Select existing security group → choose **`workshop-sg`**

> **Public IP**: You'll set this at launch time (not in the template), because it depends on which subnet the instance lands in.

---

### Step 7: Storage

- Leave the default: **8 GiB gp3**

---

### Step 8: Advanced details → IAM instance profile

Scroll to the bottom of the page → expand **"Advanced details"**

- **IAM instance profile**: select **`ec2-workshop-role`**

---

### Step 9: Advanced details → User data

Still in **"Advanced details"**, scroll down to the **User data** text box. Paste the script below.

This is the heart of the Launch Template approach. User data runs automatically as root the first time an instance boots. By the time you connect, the software is already installed.

```bash
#!/bin/bash
# Log everything — check with: sudo cat /var/log/user-data.log
exec > /var/log/user-data.log 2>&1
set -e

echo "=== Starting user-data: $(date) ==="

# Install miniforge and create a research environment as ec2-user
su -l ec2-user << 'EOF'
  set -e

  # Download and install miniforge
  curl -sL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
      -o /tmp/miniforge.sh
  bash /tmp/miniforge.sh -b -p $HOME/miniforge3

  # Initialize conda in the user's shell
  $HOME/miniforge3/bin/conda init bash

  # Create a named research environment with common packages
  $HOME/miniforge3/bin/mamba create -y -n research \
      numpy pandas matplotlib scipy s3fs

  echo "=== Research environment ready: $(date) ===" >> $HOME/cloud-init-done.txt
EOF

echo "=== User-data complete: $(date) ==="
```

> **What this does**:
> - Installs miniforge to `/home/ec2-user/miniforge3`
> - Initializes conda so it's available in every future shell session
> - Creates a conda environment named `research` with numpy, pandas, matplotlib, and scipy pre-installed
> - Logs progress to `/var/log/user-data.log` (readable with `sudo cat /var/log/user-data.log`)
> - Writes a marker file when done: `~/cloud-init-done.txt`

> 💡 **AMI alternative**: Once you've launched from this template and the environment is fully built, you can save the running instance as a custom AMI. Future launches from that AMI boot with everything pre-installed — no cloud-init wait at all. There's a small storage cost (~$0.05/GB/month for the snapshot, ~$0.40/month for an 8 GB volume). See the optional sidebar in Lab 2 for the full walkthrough.

---

### Step 10: Create the template

Click **"Create launch template"**

✅ Template created. You'll use this for every launch going forward.

---

#### 💻 CLI Sidebar: Create the Launch Template

*Use CloudShell. This creates the same template as the console steps above.*

```bash
# Get the current Amazon Linux 2023 AMI
AMI_ID=$(aws ssm get-parameters \
    --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --region us-west-2 \
    --query 'Parameters[0].Value' --output text)

# Get your security group ID
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=workshop-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)

# User data (base64-encoded for the CLI)
USER_DATA=$(base64 -w 0 << 'EOF'
#!/bin/bash
exec > /var/log/user-data.log 2>&1
set -e
echo "=== Starting user-data: $(date) ==="
su -l ec2-user << 'INNER'
  set -e
  curl -sL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh \
      -o /tmp/miniforge.sh
  bash /tmp/miniforge.sh -b -p $HOME/miniforge3
  $HOME/miniforge3/bin/conda init bash
  $HOME/miniforge3/bin/mamba create -y -n research numpy pandas matplotlib scipy s3fs
  echo "=== Research environment ready: $(date) ===" >> $HOME/cloud-init-done.txt
INNER
echo "=== User-data complete: $(date) ==="
EOF
)

aws ec2 create-launch-template \
    --launch-template-name workshop-research-template \
    --version-description "Baseline: AL2023, m6a.xlarge, miniforge, research env" \
    --launch-template-data "{
        \"ImageId\": \"$AMI_ID\",
        \"InstanceType\": \"m6a.xlarge\",
        \"SecurityGroupIds\": [\"$SG_ID\"],
        \"IamInstanceProfile\": {\"Name\": \"ec2-workshop-role\"},
        \"UserData\": \"$USER_DATA\"
    }"
```

---

## Lab 2: Launch from Template & Connect (10 minutes)

### Launch the instance

1. EC2 → **Launch Templates** → select **`workshop-research-template`**
2. **Actions** → **Launch instance from template**
3. Under **Source template version**: leave as default (version 1)
4. **Name and tags**:
   - Key `Name` / Value `research-compute-01`
   - Click **"Add tag"** (applies to instance and volumes)
     - Key `Workshop` / Value `rcworkshop-2026`
     - Key `Owner` / Value `your-name`
5. **Network settings**: expand → **Auto-assign public IP** → set to **"Enable"**
   - This is the one setting not stored in the template because it depends on subnet. Always set it explicitly — Instance Connect requires a public IP.
6. **Number of instances**: 1
7. Click **"Launch instance"**

---

### Connect

1. EC2 → Instances → wait for your instance to show **"Running"** (~60 seconds)
2. Check the box next to your instance → **"Connect"**
3. Click **EC2 Instance Connect** tab → **"Connect"**

A browser terminal opens. You're in.

---

### Wait for user-data to finish

Your instance is running, but the user-data script is still executing in the background — installing miniforge and building the research environment. This is the same work you did by hand in the standard workshop; here it's happening automatically while you continue.

```bash
# Watch cloud-init finish (exits automatically when done, usually 3-5 minutes)
cloud-init status --wait
```

When it returns `status: done`, your environment is ready.

```bash
# Verify
cat ~/cloud-init-done.txt
# Should show: === Research environment ready: <timestamp> ===
```

> **If you've done the standard workshop before**: remember waiting for `bash miniforge.sh` to finish, then `mamba install`? Same wait — it just happened without you watching it.

> 💡 **If cloud-init shows an error**, check the log: `sudo cat /var/log/user-data.log` — it captures every line of the user-data script.

---

### Optional: Save this instance as an AMI for instant future launches

> **Skip this if you're short on time.** Come back to it after the workshop. The payoff: next time you launch, your environment is ready in 60 seconds with no cloud-init wait.

The instance you just booted is in a clean, known-good state: Amazon Linux 2023 + miniforge + the `research` conda environment. That's worth preserving. An AMI (Amazon Machine Image) is a snapshot of that state — launch from it and you get this exact environment instantly, every time.

**Cost**: ~$0.05/GB/month for the snapshot. An 8 GB root volume costs about **$0.40/month**. Delete the AMI and snapshot when you no longer need them (instructions below).

#### Create the AMI

**Console**:
1. EC2 → Instances → select your running instance
2. **Actions** → **Image and templates** → **Create image**
3. **Image name**: `workshop-research-ami-YYYYMMDD` (use today's date — you'll thank yourself later if you make multiple versions)
4. **Image description**: `AL2023 + miniforge + research env (numpy, pandas, matplotlib, scipy)`
5. **No reboot**: leave **unchecked**
   - Unchecked = AWS reboots the instance briefly before snapshotting. Slower (~2 min extra) but guarantees a consistent filesystem. Checked = faster but a small risk of capturing mid-write state. For a workshop, either is fine — leave unchecked for good habits.
6. Click **"Create image"**

EC2 → AMIs (left sidebar) → your AMI will show status `pending` for ~3 minutes, then `available`.

Note the **AMI ID** (format: `ami-0abc1234def56789`) — you'll use it in the next step.

#### 💻 CLI Sidebar: Create the AMI

```bash
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=research-compute-01" \
              "Name=instance-state-name,Values=running" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text)

AMI_ID=$(aws ec2 create-image \
    --instance-id $INSTANCE_ID \
    --name "workshop-research-ami-$(date +%Y%m%d)" \
    --description "AL2023 + miniforge + research env" \
    --query 'ImageId' --output text)

echo "AMI ID: $AMI_ID  (save this)"

# Wait for it to be available (~3 minutes)
aws ec2 wait image-available --image-ids $AMI_ID
echo "AMI ready."
```

---

#### Update the Launch Template to use your AMI

The Launch Template currently points at the public Amazon Linux 2023 AMI and runs user-data at every boot. Now that you have a custom AMI, create a new template version that uses it instead — no user-data needed.

**Console**:
1. EC2 → Launch Templates → select **`workshop-research-template`**
2. **Actions** → **Modify template (Create new version)**
3. **Source template version**: 1 (copies existing settings)
4. **Template version description**: `Custom AMI — no user-data wait`
5. Under **Application and OS Images**: click **"My AMIs"** → select your `workshop-research-ami-YYYYMMDD`
6. Scroll to **Advanced details** → clear the entire **User data** field (select all, delete)
7. Click **"Create template version"**
8. **Actions** → **Set default version** → select your new version → **Set as default version**

From now on, launching from this template skips the cloud-init wait entirely.

#### 💻 CLI Sidebar: Create new template version

```bash
SG_ID=$(aws ec2 describe-security-groups \
    --filters "Name=group-name,Values=workshop-sg" \
    --query 'SecurityGroups[0].GroupId' --output text)

TEMPLATE_ID=$(aws ec2 describe-launch-templates \
    --filters "Name=launch-template-name,Values=workshop-research-template" \
    --query 'LaunchTemplates[0].LaunchTemplateId' --output text)

# Create new version with custom AMI and no user-data
NEW_VERSION=$(aws ec2 create-launch-template-version \
    --launch-template-id $TEMPLATE_ID \
    --source-version 1 \
    --version-description "Custom AMI — no user-data wait" \
    --launch-template-data "{
        \"ImageId\": \"$AMI_ID\",
        \"UserData\": \"\"
    }" \
    --query 'LaunchTemplateVersion.VersionNumber' --output text)

# Set as default
aws ec2 modify-launch-template \
    --launch-template-id $TEMPLATE_ID \
    --default-version $NEW_VERSION

echo "Template updated. New default version: $NEW_VERSION"
```

---

#### Launch from your AMI

Same process as Lab 2 — EC2 → Launch Templates → `workshop-research-template` → Launch instance from template. The difference: your instance is fully ready as soon as Instance Connect opens. No `cloud-init status --wait` needed.

```bash
# Verify immediately after connecting — no wait required
conda activate research
python -c "import numpy, pandas; print('Ready instantly.')"
```

---

#### 💻 CLI Sidebar: Launch from template

```bash
# Get your template ID
TEMPLATE_ID=$(aws ec2 describe-launch-templates \
    --filters "Name=launch-template-name,Values=workshop-research-template" \
    --query 'LaunchTemplates[0].LaunchTemplateId' --output text)

# Get the default subnet (for public IP assignment)
SUBNET_ID=$(aws ec2 describe-subnets \
    --filters "Name=defaultForAz,Values=true" \
    --query 'Subnets[0].SubnetId' --output text)

# Launch
aws ec2 run-instances \
    --launch-template LaunchTemplateId=$TEMPLATE_ID,Version=1 \
    --subnet-id $SUBNET_ID \
    --associate-public-ip-address \
    --tag-specifications \
        'ResourceType=instance,Tags=[{Key=Name,Value=research-compute-01},{Key=Workshop,Value=rcworkshop-2026},{Key=Owner,Value=your-name}]' \
    --count 1

# Wait for running state
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Name,Values=research-compute-01" \
              "Name=instance-state-name,Values=pending,running" \
    --query 'Reservations[0].Instances[0].InstanceId' --output text)

aws ec2 wait instance-running --instance-ids $INSTANCE_ID
echo "Instance running: $INSTANCE_ID"

# Connect
aws ec2-instance-connect ssh --instance-id $INSTANCE_ID
```

---

## Lab 3: S3 for Research Data (12 minutes)

### Create a bucket

1. Search for "S3" → click **S3**
2. Click **"Create bucket"**
3. **Bucket name**: `rcws-yourname-0302` (replace `0302` with today's date)
4. **Region**: us-west-2
5. **Block Public Access**: leave all checked
6. Click **"Create bucket"**

### Upload a test file

1. Click on your bucket name
2. Click **"Upload"** → drag a file or click "Add files" → **"Upload"**

> 💡 S3 can automatically move old data to cheaper storage (Glacier) — 80-95% savings. See **QUICK_REFERENCE.md** for lifecycle policy commands when you're ready.

---

#### 💻 CLI Sidebar: Create bucket and upload

```bash
BUCKET_NAME="rcws-yourname-0302"  # replace 0302 with today's date
aws s3 mb s3://$BUCKET_NAME --region us-west-2

echo "Research data test" > test-data.txt
aws s3 cp test-data.txt s3://$BUCKET_NAME/
```

---

## Break (10 minutes)

---

## Lab 4: Cost Management (15 minutes)

### Set up a budget alert

> A forgotten instance running over a weekend costs ~$10 (m6a.xlarge × ~60 hours). This 5-minute setup is your safety net.

1. Search "Budgets" in Console → **Budgets** → **Create budget**
2. **Budget type**: Cost budget / **Period**: Monthly
3. **Budget amount**: $50
4. **Budget name**: `research-monthly-budget`
5. Alert threshold: 80% → add your email → **Create budget**

---

### Check your AWS credits

1. Click your account name (top right) → **Billing and Cost Management**
2. Left sidebar → **Credits**
3. View active credits, expiration dates, and usage

**Common credit sources**: AWS Cloud Credit for Research, AWS Educate, conference promotions.

---

### AWS Global Data Egress Waiver (GDEW)

Downloading data from AWS normally costs $0.09/GB. If your institution has a GDEW agreement with AWS, a credit toward egress costs is applied automatically — no action needed. Check with your research computing team if you're not sure whether GDEW covers your account.

---

#### 💻 CLI Sidebar: Create a budget

```bash
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)

aws budgets create-budget \
    --account-id $ACCOUNT_ID \
    --budget '{"BudgetName":"research-monthly-budget","BudgetLimit":{"Amount":"50","Unit":"USD"},"TimeUnit":"MONTHLY","BudgetType":"COST"}' \
    --notifications-with-subscribers '[{"Notification":{"NotificationType":"ACTUAL","ComparisonOperator":"GREATER_THAN","Threshold":80,"ThresholdType":"PERCENTAGE"},"Subscribers":[{"SubscriptionType":"EMAIL","Address":"your.email@example.com"}]}]'
```

---

## Lab 5: Analysis — Pull, Run, Push (35 minutes)

### Before starting

Two things to check after the break:

1. **Instance Connect tab** — if you closed it, reconnect: EC2 → your instance → Connect → EC2 Instance Connect
2. **`$BUCKET_NAME` in CloudShell** — CloudShell sessions time out. Re-set if needed:
   ```bash
   BUCKET_NAME="rcws-yourname-0302"  # same name you used in Lab 3
   ```

---

### Activate your environment

Because the Launch Template's user-data ran `conda init bash`, conda is already configured in your shell. Activate the pre-built environment:

```bash
conda activate research
python -c "import numpy, pandas, matplotlib; print('Ready.')"
```

> **Compare to the standard workshop**: at this point in CURRICULUM.md, you'd be running `bash miniforge.sh` and `mamba install numpy` right now — about 2 minutes of waiting. The Launch Template did that for you at boot.
>
> **If you come from campus HPC**: this is what a pre-loaded module feels like, except you defined it yourself and can change it anytime.

---

### Pull data, run analysis, push results

```bash
# Set your bucket (if not already set from the Instance Connect session)
BUCKET_NAME="rcws-yourname-0302"  # replace 0302 with today's date

# Pull your test data from S3
# (works because ec2-workshop-role was attached via the Launch Template)
aws s3 cp s3://$BUCKET_NAME/test-data.txt ./

# Run analysis
python3 -c "
import numpy as np

with open('test-data.txt') as f:
    print(f'Input: {f.read().strip()}')

# Simulating: 100 samples x 50 measurements
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

---

#### 🐍 Alternative: Read and Write S3 Directly from Python

The pattern above uses the AWS CLI to move files in and out of S3, then works on local copies. In many research workflows — especially notebooks and pipelines — it's cleaner to have Python talk to S3 directly, with no intermediate files.

`s3fs` is already installed in the `research` environment (it was included in the Launch Template's user-data). Two options:

**Option 1: pandas + s3fs** (recommended — feels like local files)

`s3fs` teaches pandas to understand `s3://` paths. No extra install needed:

```python
import numpy as np
import pandas as pd

BUCKET = "rcws-yourname-0302"   # replace with your bucket name

# Simulating: 100 samples x 50 measurements
np.random.seed(42)
data = np.random.exponential(scale=10.0, size=(100, 50))
results = pd.DataFrame({
    "mean": data.mean(axis=0),
    "std":  data.std(axis=0),
})

# Write directly to S3 — no local copy, no aws s3 cp
results.to_csv(f"s3://{BUCKET}/results/results.csv", index=False)
print(f"Results written to s3://{BUCKET}/results/results.csv")

# Reading back is the same:
# df = pd.read_csv(f"s3://{BUCKET}/results/results.csv")
```

> 💡 This pattern works identically in a Jupyter notebook running on your instance — just use `s3://` paths anywhere pandas accepts a filename. No CLI required.

---

**Option 2: boto3** (no extra dependency — boto3 is pre-installed on Amazon Linux)

Use this when you need fine-grained control (streaming large objects, presigned URLs, multipart uploads):

```python
import boto3
import io
import numpy as np

BUCKET = "rcws-yourname-0302"

s3 = boto3.client("s3")

# Read an object from S3 into memory
obj = s3.get_object(Bucket=BUCKET, Key="test-data.txt")
content = obj["Body"].read().decode("utf-8")
print(f"Input: {content.strip()}")

# Run analysis
np.random.seed(42)
data = np.random.exponential(scale=10.0, size=(100, 50))

# Write results directly to S3 — no temp file
buf = io.BytesIO()
np.savetxt(buf,
    np.column_stack([data.mean(axis=0), data.std(axis=0)]),
    delimiter=",", header="mean,std", comments="")
s3.put_object(Bucket=BUCKET, Key="results/results-boto3.csv", Body=buf.getvalue())
print(f"Results written to s3://{BUCKET}/results/results-boto3.csv")
```

> **boto3 vs s3fs**: boto3 is more explicit and needs no extra install. s3fs is more ergonomic for data science workflows where you want pandas/numpy to "just work" with S3 paths. Use whichever fits how you write code.

---

### Upload your own data to S3

**Console** (drag and drop for small files):
S3 → your bucket → **"Upload"** → drag files → **"Upload"**

#### 💻 CLI Sidebar: Upload, sync, and access data

```bash
# Upload a single file
aws s3 cp large-dataset.tar.gz s3://$BUCKET_NAME/datasets/

# Upload an entire directory
aws s3 sync /path/to/research/data s3://$BUCKET_NAME/data/ --progress

# Large files (>5GB): CLI does multipart automatically
aws s3 cp 50GB-genome-data.tar.gz s3://$BUCKET_NAME/genomics/
```

**For datasets >10TB**: rclone with `--transfers 16` handles most research-scale transfers. For very large or recurring transfers, contact your institution's research computing team — campus HPC often has Globus endpoints for exactly this.

---

### Spot instances: the same research, at 70% off

See [CURRICULUM.md — Know About Spot Instances](CURRICULUM.md#-know-about-spot-instances-2-minutes). The Launch Template makes Spot even easier — you already have your configuration saved. At launch time, just check "Spot instance" under Advanced details.

---

## Clean Up

Terminate instances when you're done with them. Stopped instances still charge for storage; terminated instances charge nothing.

### EC2: Tag-based cleanup

**Console**:
1. EC2 → Instances → click the search bar → type `Workshop`
2. Dropdown appears → click **"Workshop ="** → click **"All values"**
3. Select all → **Instance state** → **Terminate (delete) instance**

> The Launch Template has no cost — keep it. Instance launch takes ~60 seconds to reach running state, plus a few minutes for cloud-init on first use (none if using a custom AMI).

### AMI & Snapshot: Optional cleanup

If you created a custom AMI in Lab 2, it has an associated EBS snapshot costing ~$0.40/month. Delete both when you no longer need them — **order matters**: deregister the AMI first, then delete the snapshot.

**Console**:
1. EC2 → **AMIs** (left sidebar, under "Images") → select your `workshop-research-ami-*` → **Actions** → **Deregister AMI** → confirm
2. EC2 → **Snapshots** (left sidebar, under "Elastic Block Store") → find the snapshot with a description matching your AMI name and the same timestamp → select it → **Actions** → **Delete snapshot** → confirm

> ⚠️ If you delete the snapshot before deregistering the AMI, the delete will fail — the AMI holds a reference to it.

#### 💻 CLI Sidebar: Deregister AMI and delete snapshot

```bash
# $AMI_ID from when you created it — or look it up:
AMI_ID=$(aws ec2 describe-images --owners self \
    --filters "Name=name,Values=workshop-research-ami-*" \
    --query 'Images[0].ImageId' --output text)

# Get the snapshot ID before deregistering (you'll need it)
SNAPSHOT_ID=$(aws ec2 describe-images --image-ids $AMI_ID \
    --query 'Images[0].BlockDeviceMappings[0].Ebs.SnapshotId' --output text)

# Deregister the AMI first
aws ec2 deregister-image --image-id $AMI_ID
echo "AMI deregistered: $AMI_ID"

# Then delete the snapshot
aws ec2 delete-snapshot --snapshot-id $SNAPSHOT_ID
echo "Snapshot deleted: $SNAPSHOT_ID"
```

### S3: Manual cleanup

1. S3 → select your bucket → **Empty** → type `permanently delete` → **Empty**
2. Select bucket → **Delete** → type the bucket name → **Delete bucket**

---

#### 💻 CLI Sidebar: Terminate by tag

```bash
# Terminate all workshop instances
aws ec2 terminate-instances --instance-ids $(
    aws ec2 describe-instances \
        --filters "Name=tag:Workshop,Values=rcworkshop-2026" \
                  "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text
) && echo "All workshop instances terminated!"

# S3 cleanup
BUCKET_NAME="rcws-yourname-0302"
aws s3 rm s3://$BUCKET_NAME/ --recursive
aws s3 rb s3://$BUCKET_NAME
echo "S3 cleanup complete!"
```

---

## Wrap-Up & Resources (15 minutes)

### What You Learned Today

✅ Lab 0 pre-flight: region, VPC, security group, IAM role — one-time setup
✅ Build a Launch Template with user-data to automate instance configuration
✅ Launch a fully configured instance in ~30 seconds
✅ Wait for cloud-init and verify the environment is ready
✅ (Optional) Save a custom AMI to eliminate the cloud-init wait for all future launches
✅ Store research data in S3, retrieve results anywhere
✅ Set up budget alerts to prevent surprise bills
✅ Understand Spot instances and the 70% savings available
✅ Clean up all resources with tag-based termination

### The workflow going forward

**Without a custom AMI** (first time, or after user-data changes):
1. EC2 → Launch Templates → `workshop-research-template` → Launch instance from template
2. Name it, add tags, enable public IP → Launch
3. `cloud-init status --wait` → `conda activate research` → work
4. Stop when done. Terminate when finished for good.

**With a custom AMI** (after completing the optional Lab 2 sidebar):
1. EC2 → Launch Templates → `workshop-research-template` → Launch instance from template
2. Name it, add tags, enable public IP → Launch
3. Connect → `conda activate research` → work immediately (no wait)
4. Stop when done. Terminate when finished for good.

---

### Cost Estimation for Your Research

**AWS bills by the second** (60-second minimum):

| Instance | Per hour | Per minute | Per second |
|---|---|---|---|
| m6a.xlarge (workshop instance) | $0.173 | $0.0029 | $0.000048 |
| g5.xlarge (GPU) | $1.006 | $0.0168 | $0.000279 |
| m6a.xlarge Spot | ~$0.052 | ~$0.0009 | ~$0.000014 |

**Example: CPU compute, moderate use**
- 2 × m6a.xlarge × 40 hrs/month = $13.84 ($0.173/hr × 2 × 40)
- 100 GB S3 storage = $2.30 ($0.023/GB)
- 1 TB data transfer in = $0 (inbound is free)
- 10 GB data transfer out = $0.90 ($0.09/GB)
- **Total: $17.04/month**

**Example: GPU training, moderate use**
- 1 × g5.xlarge × 20 hrs/month = $20.12 ($1.006/hr × 20)
- 500 GB S3 storage = $11.50 ($0.023/GB)
- **Total: $31.62/month**

---

### Next Steps

1. **Customize the user-data script** for your stack: add your packages to the `mamba create` line, or add `pip install` steps
2. **Save a custom AMI** once you've built the environment you want — eliminates the cloud-init wait for future launches (see optional sidebar in Lab 2). Remember to clean up the snapshot (~$0.40/month) when done.
3. **Apply for AWS Cloud Credit for Research**: free credits, 10-minute application at aws.amazon.com/government-education/research-and-technical-computing/cloud-credit-for-research/
4. **Workshop 2 — spore.host for Production**: job arrays, data staging, Spot with checkpointing. See **SPOREHOST_TEASER.md**.

---

### Resources

**AWS for Research**:
- AWS Cloud Credit for Research: https://aws.amazon.com/government-education/research-and-technical-computing/cloud-credit-for-research/
- AWS Pricing Calculator: https://calculator.aws/

**spore.host**:
- Quick start: See **SPOREHOST_TEASER.md**
- GitHub: https://github.com/scttfrdmn/mycelium

**Your institution**:
- Research Computing team — your local source for HPC questions, AWS account setup, and GDEW status

---

## Bonus: spore.host — A Better Way (post-workshop, for those staying)

> **Hard stop at 2 hours. This section is for participants who want to stay a few extra minutes.**
>
> **See SPOREHOST_TEASER.md for the full reference and Workshop 2 preview.**

You've now seen three levels of AWS workflow:
- **Console**: Explicit, manual every time (CURRICULUM.md)
- **Launch Template**: One-time configuration, reusable launches (this document)
- **spore.host**: Single command, configuration handled for you

```bash
# Install
curl -L https://github.com/scttfrdmn/mycelium/releases/latest/download/mycelium-$(uname -s)-$(uname -m).tar.gz | tar xz
export PATH=$PATH:$PWD/mycelium/bin

# Find instances by plain English
truffle find h100              # Finds p5.48xlarge (H100 GPU)
truffle find "large amd"

# Launch interactively
spawn

# Find cheapest Spot + launch in one line
truffle spot "m7i.*" --sort-by-price | spawn --spot --ttl 8h
```

> "Console for learning. Launch Templates for repeatable setups. spore.host for daily research work."

📄 **See SPOREHOST_TEASER.md** for: installation, all commands, real research examples, and a preview of Workshop 2.
