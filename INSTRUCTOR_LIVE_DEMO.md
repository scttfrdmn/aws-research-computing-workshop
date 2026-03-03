# Live Demo Guide: CU Boulder AWS Workshop

**For the instructor.** What to show on the projector at each step, what to highlight, and what participants should be watching for.

**Setup**: Share your screen showing the AWS Console. Use browser zoom 100%, light mode. Have CloudShell open in a separate browser tab.

---

## Before the Workshop Starts

**Have open and ready**:
- AWS Console logged in, region set to **US West (Oregon)**
- CloudShell tab ready (`>_` icon clicked, shell initialized)
- QUICK_REFERENCE.md open in another tab (for CLI sidebars)

---

## Lab 0: Pre-Flight Check

### Show: Region selector (top-right corner)
- **Highlight**: The region dropdown — participants often miss this
- Click it, show the list, select **US West (Oregon) us-west-2**
- Say: "Everything you create today lives in this region. If something seems missing later, check this first."

---

### Show: VPC Dashboard
- Search `VPC` in top bar → VPC Dashboard
- **Highlight**: "Default VPC: Yes" in the summary
- Say: "We need this to exist. If it says No, raise your hand."

---

### Show: Security Group creation via search bar
- Type `Security Groups` in the top search bar
- **Highlight**: The `EC2 > Security Groups` result — *not* the VPC result
- Click through to Create security group
- Name: `workshop-sg`, add inbound SSH rule, Anywhere-IPv4
- **Highlight**: The source dropdown — show the difference between "My IP" and "Anywhere"
- Say: "For a real project, use My IP. For today's workshop, Anywhere is fine."

---

### Show: CloudShell auth check
- Switch to CloudShell tab
- Run: `aws sts get-caller-identity`
- **Highlight**: The Account and UserId fields in the response
- Say: "This tells you you're authenticated. If you get an error here, raise your hand."

---

### Show: IAM Role creation
- Search `IAM` → Roles → Create role
- Trusted entity: AWS service → EC2
- **Highlight**: The trusted entity selection — "This tells AWS that EC2 instances are allowed to use this role"
- Search and select `AmazonS3FullAccess`
- Role name: `ec2-workshop-role`
- Say: "We're creating this now so it's available as a dropdown when we launch our instance. Otherwise you'd have to leave the launch wizard mid-way."

---

## Lab 1, Part A: Launch EC2

### Show: EC2 Dashboard → Launch Instance
- EC2 → click **Launch Instance** (orange button, top right)
- Name field: type `research-compute-01`
- **Highlight**: The "Add additional tags" link below the name — say "We'll come back to this"

---

### Show: AMI selection
- **Highlight**: Amazon Linux 2023 already selected
- Say: "This is the AWS-maintained Linux. It comes with the AWS CLI pre-installed — that's what makes Instance Connect work."

---

### Show: Instance type
- **Highlight**: The current default type shown
- Change to `m6a.xlarge`
- **Highlight**: The 4 vCPU / 16 GB specs that appear
- Say: "t3.micro is for web servers. m6a is what you'd actually use for research workloads — 4 cores, 16 GB, $0.17/hr."

---

### Show: Key pair section
- **Highlight**: "Proceed without a key pair" option
- Say: "We're not using key pairs today. We'll connect through the browser instead. This is the modern approach — no key file to manage, no chmod 400."

---

### Show: Network settings
- Click Edit in Network settings
- Security group: select existing → `workshop-sg`
- **Highlight**: Auto-assign public IP dropdown — change to **Enable**
- Say: "This one trips people up. If this is left on 'Use subnet setting' and the subnet default is off, Instance Connect fails silently. We set it explicitly."

---

### Show: Advanced details (UX callout)
- Scroll to the very bottom of the page
- **Highlight**: "Advanced details" accordion — collapsed by default
- Expand it
- Say: "AWS named this 'Advanced details' but two things we need are here. The name implies optional. They're not optional for us."
- IAM instance profile → select `ec2-workshop-role`
- Resource tags: Key `Workshop` / Value `cu-boulder-2025`, Key `Owner` / Value your name
- Say: "The tag is how we do cleanup at the end. One filter, select all, terminate."

---

### Show: Launch and wait
- Click **Launch instance**
- Navigate to Instances list
- **Highlight**: The State column cycling through Pending → Running
- Show the public IP once it appears
- Say: "60 seconds. This is what no queue wait looks like."

---

### Show: Instance Connect
- Select instance → Connect → **EC2 Instance Connect** tab → Connect
- **Highlight**: The browser terminal that opens
- Run: `uname -a`, `nproc`, `free -h`
- Say: "You're now on a 4-core, 16 GB machine. These commands show you the hardware. Leave this tab open — if you close it you'll need to reconnect."

---

### Show: miniforge install (kickoff)
```bash
curl -sL https://github.com/conda-forge/miniforge/releases/latest/download/Miniforge3-Linux-x86_64.sh -o miniforge.sh
bash miniforge.sh -b -p $HOME/miniforge3 && echo "Miniforge ready."
```
- Say: "We're starting this now because it takes about 60 seconds. We'll come back to it."
- While it runs, switch to S3 setup

---

## Lab 1, Part B: S3

### Show: Create bucket
- Search `S3` → Create bucket
- **Highlight**: The globally unique naming requirement
- Name: `rcws-demo-0302` (with today's date)
- Region: us-west-2
- **Highlight**: Block Public Access — leave all checked
- Say: "Bucket names are global. If you try 'my-bucket' it's already taken. Use your name and today's date."

---

### Show: Upload a file
- Click into the bucket → Upload → Add files → pick any small file
- **Highlight**: The upload progress bar
- Say: "That's it. S3 is a key-value store — path + file = object. No directories, no permissions to set, no quota to worry about."

---

## Break (0:50)

Tell participants:
1. **Leave the Instance Connect tab open** — you'll need it in Lab 2
2. CloudShell session may time out — you'll re-set `$BUCKET_NAME` at the start of Lab 2

---

## Lab 2 Start: Reconnect Check

### Show on projector:
- Your Instance Connect tab — still open
- If closed, reconnect: EC2 → select instance → Connect → EC2 Instance Connect
- Switch to CloudShell, re-set variable:
```bash
BUCKET_NAME="rcws-demo-0302"
```

---

## Lab 2, Part A: Cost Management

### Show: AWS Credits
- Account menu (top right) → Billing → Credits
- **Highlight**: Any active credit balances and expiration dates
- Say: "A lot of researchers have credits and don't know it. Check this before you do any significant work. Research Credits program — 10-minute application, up to $100k."

---

### Show: Create Budget
- Billing → Budgets → Create budget
- Type: Cost budget, $50/month, 80% threshold, email notification
- **Highlight**: The email field
- Say: "This is your safety net. You'll get an email at $40. Budget alerts take 24 hours to trigger so don't rely on this alone — but it catches forgotten instances."

---

### Show: GDEW
- Navigate to: `aws.amazon.com/government-education/research-and-technical-computing/data-egress-waiver/`
- **Highlight**: The "FREE data transfer out" headline
- Say: "Normally data transfer out of AWS costs $0.09/GB. Through CU's AWS agreement, GDEW provides a credit toward those costs — nothing you need to do individually. It's a credit toward egress costs, not free egress, but for researchers downloading significant data it makes a real difference. The credit is shared across CU's institutional AWS spending, not a per-account balance."

---

### Show: Cost Explorer
- Billing → Cost Explorer → Launch Cost Explorer
- Group by: Service
- **Highlight**: The bar chart showing EC2, S3, data transfer as separate bars
- Say: "This is how you investigate a surprise bill. Each service broken out."

---

## Lab 2, Part B: Data Transfer + Analysis

### Show: Upload to S3 (Console)
- S3 → your bucket → Upload → drag a file
- Say: "Small files, drag and drop is fine."

---

### Show: Complete analysis loop (Instance Connect terminal)
```bash
source $HOME/miniforge3/bin/activate
mamba install -y numpy
aws s3 cp s3://$BUCKET_NAME/test-data.txt ./
python3 -c "
import numpy as np
np.random.seed(42)
data = np.random.exponential(scale=10.0, size=(100, 50))
np.savetxt('results.csv',
    np.column_stack([data.mean(axis=0), data.std(axis=0)]),
    delimiter=',', header='mean,std', comments='')
print(f'Done: {data.shape[0]} samples, {data.shape[1]} features')
"
aws s3 cp results.csv s3://$BUCKET_NAME/results/results.csv
```
- **Highlight**: Each stage — pull, compute, push
- Say: "This is the loop you'll repeat for real work. Pull your data from S3, run your analysis, push results back. The instance can then be terminated without losing anything."

Then switch to CloudShell:
```bash
aws s3 cp s3://$BUCKET_NAME/results/results.csv ./
head results.csv
```
- **Highlight**: The result appearing in a completely separate environment
- Say: "The results are in S3. I can retrieve them from CloudShell, from my laptop, from another instance — the compute and the data are decoupled."

---

## Lab 2, Part C: Cleanup

### Show: Tag-based EC2 cleanup
- EC2 → Instances → Filter: Tag → Workshop = cu-boulder-2025
- **Highlight**: The filter reducing the list to only workshop instances
- Select all → Actions → Terminate instance
- Say: "This is why we tagged everything. One filter, select all, done. A team of 20 researchers could clean up in 30 seconds."

---

### Show: S3 cleanup
- S3 → your bucket → Empty → confirm
- Then Delete bucket
- Say: "S3 requires two steps — empty then delete. You can't delete a non-empty bucket."

---

## Wrap-Up

### Show: Cost optimizer table (from AGENDA.md or on whiteboard)

Key points to hit:
- Spot instances: 50-90% savings, but requires checkpointing first
- S3 lifecycle policies: move old data to Glacier (80-95% savings, 5 min to set up)
- AWS Research Credits: apply if you haven't
- GDEW: credit toward egress costs, already applied through CU's agreement, nothing to do
- Tag-based cleanup: the habit that prevents forgotten resources

---

## 2:00+ Bonus: Spore.host (for those staying)

Only show if participants are staying voluntarily after hard stop.

### Show: CloudShell
```bash
curl -L https://github.com/scttfrdmn/mycelium/releases/latest/download/mycelium-Linux-x86_64.tar.gz | tar xz
export PATH=$PATH:$PWD/mycelium/bin
truffle find "large amd"
```
- **Highlight**: Natural language search working without AWS credentials
- Say: "Lab 0 was 5 steps before we launched anything. That overhead exists every time. `spawn` eliminates it."

```bash
spawn
```
- Press Enter through all defaults
- **Highlight**: Instance launching in ~60 seconds with no pre-flight

---

## General Screen-Sharing Tips

- **Zoom to 125%** in the AWS Console for readability on a projector
- **Collapse the left sidebar** — more space for the main content area
- **Use the top search bar** to navigate — faster than the sidebar and participants can see what you're typing
- **Pause after each highlight** — give participants 10-15 seconds to find the same element
- **Call out wrong paths** — "You might see X here instead of Y if you're in a different region"

---

**Workshop Version**: 2.0 | **Last Updated**: March 2026
