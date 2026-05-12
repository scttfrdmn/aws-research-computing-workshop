# Workshop 1 Redux: The Fast Path

**The same skills — without the pre-flight.**

**Format**: Self-study
**Duration**: 45–60 minutes
**Prerequisite**: Workshop 1 (or equivalent — you know what EC2, S3, IAM, and security groups are)

---

> This workshop does everything Workshop 1 did.
> It just does it faster.
>
> If you skipped Workshop 1, you can still follow along — you just won't feel how much faster this is.

---

## What Changed

| Task | Workshop 1 | Workshop 1 Redux |
|------|------------|-----------------|
| Pre-flight | 5 steps, ~10 min | One install command |
| Launch instance | 9-step Console wizard | `spawn` (4 Enter presses) |
| Connect | EC2 → Instances → Connect → tab → button | `spawn connect research-01` |
| See cost right now | Billing → Cost Explorer | `spawn list` |
| Auto-terminate | Not available | `--ttl 8h` at launch |
| Cleanup | Tag filter → select all → Terminate | `spawn stop research-01` |

**What doesn't change**: S3 bucket creation and budget alerts are still AWS-native. Two things out of the whole workshop. Everything about compute is simpler.

---

## Lab 0 Redux: Install Tools (5 minutes)

**Workshop 1 Lab 0**: Set region → verify VPC → create security group → verify CLI auth → create IAM role. Five steps, ~10 minutes, before a single instance launches.

**Workshop 1 Redux Lab 0**:

```bash
# Install (macOS or Linux — run in your local terminal)
brew install spore-host/tap/truffle
brew install spore-host/tap/spawn

# Verify
truffle --version
spawn --version
```

**Windows**: install via [Scoop](https://scoop.sh): `scoop bucket add spore-host https://github.com/spore-host/scoop-bucket && scoop install truffle spawn`. Or download the Windows binaries from the [latest release](https://github.com/spore-host/spore-host/releases/latest) and add them to your PATH.

That's it. No VPC check. No security group. No IAM role to pre-create. `spawn` handles all of that at launch time.

> **Prerequisite**: `spawn` calls AWS APIs, so you need AWS credentials configured locally. If you haven't done this, run `aws configure` (or set up AWS SSO) before the verify step. If you completed Workshop 1 and used CloudShell, you need to configure credentials on your local machine now — CloudShell credentials don't carry over.

✅ **Lab 0 complete when**: `truffle --version` and `spawn --version` both respond.

> 💡 Installing via `brew`/`scoop` puts both tools on your `PATH` automatically — no manual PATH editing needed.

---

## Lab 1A Redux: Launch and Connect (5 minutes)

**Workshop 1**: 9-step Console wizard, two settings buried under "Advanced details," wait for "running" state, navigate to Instances, click Connect, find the right tab, click Connect again.

**Workshop 1 Redux**:

```bash
spawn
```

```
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

Connect:

```bash
spawn connect research-01
```

A terminal opens. You're in.

> **Notice what didn't happen**: no VPC selection, no security group, no IAM role dropdown, no public IP checkbox, no tag entry. `spawn` handled all of it. The cost estimate appeared before you launched. And you now have an auto-terminate timer — this instance cannot be accidentally left running overnight.

**While you're here — start this now** (same as Workshop 1):
```bash
curl -sL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o miniforge.sh
bash miniforge.sh -b -p $HOME/miniforge3 && echo "Miniforge ready."
```
~60 seconds. Move to S3 setup while it runs.

---

## Lab 1B Redux: S3 Setup (12 minutes)

**S3 doesn't change.** `spawn` manages compute. You manage S3 directly — with the Console or AWS CLI, exactly as in Workshop 1.

**Console**:
1. Search `S3` → **Create bucket**
2. **Bucket name**: `rcws-yourname-0302` (replace with your name and today's date)
3. **Region**: us-west-2
4. **Block Public Access**: leave checked ✅
5. **Create bucket** → upload a test file

**CLI** (CloudShell or local terminal):
```bash
BUCKET_NAME="rcws-yourname-0302"   # replace with your name and today's date
aws s3 mb s3://$BUCKET_NAME --region us-west-2
echo "Research data test" > test-data.txt
aws s3 cp test-data.txt s3://$BUCKET_NAME/
```

> This is intentional. S3 is AWS's persistent object store — it outlives any compute tool you use. You'll interact with it the same way whether you launched your instance with `spawn`, the Console, or a script.

---

## Lab 2A Redux: Cost Management (15 minutes)

**What `spawn` adds**:

```bash
spawn list
```
```
NAME         ID         TYPE        REGION     STATE    COST/HR  TTL    TOTAL
research-01  i-0abc123  m6a.xlarge  us-west-2  running  $0.17    6h     $0.34

Total: $0.17/hour
```

`spawn list` shows what's running across all regions, what it costs per hour, and how long until auto-termination — every time you check in. No navigating. Run it at the start and end of every session.

**What stays the same**:

Budget alerts and AWS Credits are still in the AWS Billing Console — same steps as Workshop 1.

- **Budget alert**: Billing → Budgets → Create budget → $50/month → 80% threshold → email
- **Credits**: Account menu → Billing → Credits → check balance and expiration dates
- **GDEW**: Applied automatically if your institution has a GDEW agreement with AWS — nothing to do per-user. Ask your research computing team if unsure.

> **The habit**: `spawn list` every time you sit down. It shows you what's running, what it costs, and whether a TTL is about to expire. In Workshop 1 you had to navigate to Cost Explorer to get this. Now it's one command.

---

## Lab 2B Redux: Data Transfer and Analysis (15 minutes)

> **Before starting**: Reconnect if needed (`spawn connect research-01`) and confirm `$BUCKET_NAME` is set:
> ```bash
> BUCKET_NAME="rcws-yourname-0302"  # same name as Lab 1B — replace 0302 with today's date
> ```

The analysis loop is identical to Workshop 1. `spawn` launched the instance with your AWS credentials context, so S3 access works the same way.

```bash
source $HOME/miniforge3/bin/activate
mamba install -y numpy    # ~30 seconds

# Pull from S3
aws s3 cp s3://$BUCKET_NAME/test-data.txt ./

# Run analysis
python3 -c "
import numpy as np
with open('test-data.txt') as f:
    print(f'Input: {f.read().strip()}')
np.random.seed(42)
data = np.random.exponential(scale=10.0, size=(100, 50))
np.savetxt('results.csv',
    np.column_stack([data.mean(axis=0), data.std(axis=0)]),
    delimiter=',', header='mean,std', comments='')
print(f'Done: {data.shape[0]} samples, {data.shape[1]} features')
"

# Push results back to S3
aws s3 cp results.csv s3://$BUCKET_NAME/results/results.csv
echo "Results in S3."
```

Retrieve from anywhere (CloudShell, laptop, another instance):
```bash
aws s3 cp s3://$BUCKET_NAME/results/results.csv ./
```

Same loop. Same commands. The instance you're on was launched in 60 seconds with no pre-flight.

---

## Lab 2C Redux: Cleanup (5 minutes)

**Workshop 1**: EC2 → filter by Workshop tag → select all → **Instance state** → **Terminate (delete) instance**. Then separately empty and delete S3 bucket.

**Workshop 1 Redux**:

```bash
# Stop instance (keeps EBS data, zero compute charge)
spawn stop research-01

# Or terminate immediately (instance and EBS gone)
spawn terminate research-01

# Verify nothing is still running
spawn list
```

**S3 cleanup** (same as Workshop 1 — `spawn` doesn't manage S3):
```bash
aws s3 rm s3://$BUCKET_NAME/ --recursive
aws s3 rb s3://$BUCKET_NAME
echo "S3 cleanup complete!"
```

> The TTL you set at launch is your real safety net. If you walked away and forgot, the instance would have terminated itself. Manual cleanup is still good practice — but it's no longer your only line of defense.

---

## What You Can Do Now

You've run the same workshop twice. The next step is your actual research data.

**This week**:
1. Launch with your real dataset: `spawn --instance-type m6a.xlarge --ttl 4h`
2. `spawn list` at the start and end of every session
3. When done: `spawn stop research-01` or let TTL handle it

**When you're ready for more**:

| Feature | How | Notes |
|---------|-----|-------|
| **Spot instances** | `spawn --spot --ttl 8h` | 50-90% savings — requires checkpointing to S3 first |
| **Bigger instance** | `spawn --instance-type m6a.4xlarge` | Scale up for larger workloads |
| **Find the right instance** | `truffle find "32 core amd"` | Plain-English search, no AWS account needed |
| **Parallel jobs** | `spawn launch --count 10 --job-array-name my-analysis` | Workshop 2 |
| **Data staging** | `spawn stage upload dataset.tar.gz` | 99% transfer savings — Workshop 2 |

---

## Full Side-by-Side

| Task | Workshop 1 | Workshop 1 Redux |
|------|------------|-----------------|
| Pre-flight | 5 steps, ~10 min | Install tools, ~2 min |
| Launch instance | 9-step Console wizard | `spawn` (4 Enter presses) |
| Connect | 5 clicks through Console UI | `spawn connect research-01` |
| Check what's running | EC2 → Instances | `spawn list` |
| See current cost | Billing → Cost Explorer | `spawn list` |
| Auto-terminate | Manual only | `--ttl 8h` at launch |
| Create S3 bucket | Console or CLI | Console or CLI (unchanged) |
| Upload/download data | `aws s3 cp` / `sync` | `aws s3 cp` / `sync` (unchanged) |
| Budget alerts | Billing → Budgets | Billing → Budgets (unchanged) |
| Check AWS credits | Billing → Credits | Billing → Credits (unchanged) |
| Cleanup compute | Tag filter → Terminate | `spawn stop` or TTL |
| Cleanup S3 | `aws s3 rm` + `rb` | `aws s3 rm` + `rb` (unchanged) |

---

## Resources

- **Workshop 1**: CURRICULUM.md — fundamentals, Console-first
- **spore.host quick start**: SPOREHOST_TEASER.md
- **spore.host GitHub**: https://github.com/spore-host/spore-host
- **Workshop 2**: Parallel computing with job arrays — workshop2/
- **Your institution's research computing team**: for HPC questions, AWS account setup, and GDEW status

---

**Version**: 1.0 | **Last Updated**: May 2026
