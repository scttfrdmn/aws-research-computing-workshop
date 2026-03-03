# Instructor Notes: CU Boulder AWS Workshop

## Pre-Workshop Setup (30 minutes before)

### 1. AWS Account Setup
- [ ] Ensure all participants have AWS accounts
- [ ] Verify IAM users have appropriate permissions (EC2, S3, Budgets)
- [ ] Test account access: `aws sts get-caller-identity`

### 2. Test Environment
- [ ] Launch a test EC2 instance to verify no quota issues
- [ ] Create a test S3 bucket
- [ ] Verify AWS CLI works: `aws ec2 describe-instances`

### 3. Participant Preparation
- [ ] Send pre-workshop email with AWS account setup instructions
- [ ] Confirm they only need a modern web browser — no local software installation needed

---

## Workshop Flow & Timing

### Segment 1: Introduction (0:00-0:08) - 8 min
**Goal**: Set context and expectations

**Key Points**:
- This is hands-on, not lecture
- Focus on practical skills for research
- Show cost comparisons early (address fear of bills)
- Emphasize: "You'll launch an instance in the first 30 minutes"

**Common Questions**:
- "Will this cost me money?" → Yes, but <$5 for workshop, teach cleanup
- "Do I need to know Linux?" → Basic comfort helpful, but we'll guide you
- "Can I use Windows?" → Yes, everything works on Windows

---

### Segment 1.5: Lab 0 Pre-flight (0:08-0:18) - 10 min

Walk through the 5 steps in CURRICULUM.md Lab 0:
1. Set region to US West (Oregon)
2. Verify default VPC exists
3. Create `workshop-sg` security group (SSH, Anywhere-IPv4)
4. Verify CloudShell auth (`aws sts get-caller-identity`)
5. Create `ec2-workshop-role` IAM role (EC2 trusted entity, AmazonS3FullAccess)

Point out: "Five steps before anything launches. This overhead exists every time — it's what spore.host eliminates."

---

### Segment 2: Hands-On Lab 1 (0:18-0:50) - 32 min

#### Part A: EC2 Launch (20 min)

**Timing Breakdown**:
- Console walkthrough: 13 min (walk through each screen on projector)
- Stop/restart overview: 3 min
- Spot awareness: 2 min
- CLI sidebar: show code briefly at the end — it's optional, skip if running behind

**Teaching Approach**:
1. **Console first** (show on projector)
   - Walk through each screen
   - Pause at key decisions (instance type, security)
   - Highlight: "This is what happens under the hood"

2. **CLI sidebar** (optional — walk through if time allows, skip if running behind)
   - Point to commands in shared doc; don't wait for everyone to run them
   - Common issue: CloudShell session timed out — just re-open it

**Checkpoints**:
- [ ] Everyone's instance is "running" (green in console)
- [ ] Everyone is connected via EC2 Instance Connect (browser terminal open)
- [ ] If stuck >5 min, move them to next section, help after

**Common Issues**:
- **"Create a key pair or proceed without a key pair" dialog appears at launch**: Normal — participant skipped the key pair dropdown. Tell them to click "Proceed without key pair" in the dialog, then "Launch instance"
- **Participant landed on "SSM Session Manager" tab** (shows DHMC/SSM errors): Wrong tab — click "EC2 Instance Connect" (first tab on the left)
- **IAM role shows "–" in the Connect page header**: ec2-workshop-role wasn't attached at launch — stop instance → Actions → Security → Modify IAM role → attach ec2-workshop-role → start instance
- **Instance Connect fails**: Auto-assign public IP was left on "Disable" — stop instance, can't fix after launch; terminate and relaunch with IP set to Enable
- **Instance Connect button greyed out**: Instance not fully running yet — wait 30 more seconds
- **"No default VPC"**: VPC Console → Actions → Create default VPC (30 seconds)
- **Quota exceeded**: Use m6a.large (2 vCPU, 8 GB) as fallback — still research-appropriate

---

#### Part B: S3 Setup (12 min)

**Timing Breakdown**:
- Create bucket (Console): 5 min
- Upload file: 3 min
- CLI commands + set $BUCKET_NAME variable: 4 min

**Teaching Approach**:
1. Show bucket creation on console first
2. Emphasize: **Bucket names are globally unique** — use name + date
3. CLI commands as alternative; make sure everyone has $BUCKET_NAME set for Lab 2

**Checkpoints**:
- [ ] Everyone has a bucket created
- [ ] At least one file uploaded
- [ ] Everyone has $BUCKET_NAME set in CloudShell

**Common Issues**:
- **Bucket name taken**: Add `-yourname` or timestamp
- **Access denied**: Check bucket permissions
- **Upload fails**: Check file size, use multipart for >5GB

---

### Break (0:50-1:00) - 10 min

**During Break**:
- Check on anyone who had issues in Lab 1
- Verify everyone is caught up
- Prepare for Lab 2

---

### Segment 3: Hands-On Lab 2 (1:00-1:45) - 45 min

#### Part A: Cost Management (15 min)

**Focus**: Prevent surprise bills

**Demonstrate**:
1. How to set up budget alerts
2. How to check current costs
3. Real example: "Here's what today's lab costs: $0.42"

**Checkpoints**:
- [ ] Everyone has a budget alert configured
- [ ] Everyone can view Cost Explorer

---

#### Part B: Data Transfer (15 min)

**Practical Scenarios**:
- Upload dataset from laptop to S3
- Download S3 data to EC2 instance
- Sync directory (aws s3 sync)

**Key Command**:
```bash
aws s3 sync /local/data/ s3://bucket/data/ --progress
```

---

#### Part C: Cleanup (10 min)

**CRITICAL SECTION - Don't Skip**

**Emphasize**:
- "If you don't terminate, you're charged ~$0.17/hour"
- "S3 charges for storage even when not using"
- "Budget alerts take 24 hours to trigger"

**Walk Through**:
1. Terminate ALL instances (show console)
2. Delete S3 buckets (show CLI)
3. Verify: `aws ec2 describe-instances --filters "Name=instance-state-name,Values=running"`

**Provide Cleanup Script**:
```bash
# cleanup.sh
aws ec2 terminate-instances --instance-ids $(aws ec2 describe-instances \
    --filters "Name=tag:Workshop,Values=cu-boulder-2026" "Name=instance-state-name,Values=running,stopped" \
    --query 'Reservations[].Instances[].InstanceId' --output text) && echo "All workshop instances terminated!"
```

---

### Segment 4: Wrap-Up (1:45-2:00) - 15 min

**Quick Recap**:
- What did you learn?
- What will you try first?
- Any lingering questions?

**Resources to share**:
- Workshop materials: CURRICULUM.md, QUICK_REFERENCE.md, SPOREHOST_TEASER.md, WORKSHOP1_REDUX.md
- AWS Research Credits application link
- CU Boulder Research Computing: https://www.colorado.edu/rc/

---

### Post-Workshop Bonus: spore.host (2:00+, voluntary)

> Hard stop at 2:00. Only demo this if participants choose to stay.

**Positioning**: "You just did five setup steps before launching anything. spore.host eliminates that overhead."

**Live Demo** (see INSTRUCTOR_LIVE_DEMO.md for full script):
1. Show `truffle find` — natural language search, no AWS credentials needed
2. Show `spawn` wizard — press Enter through defaults, instance in 60 seconds
3. Show the contrast: Lab 0 was 5 steps; `spawn` is one command

**Key Message**: Console for learning, CLI for scripts, spore.host for daily research work.

**Don't**:
- Spend time on installation details (point to SPOREHOST_TEASER.md)
- Make it seem like a replacement — it's a complement

---

## Troubleshooting Guide

### Issue: "EC2 Instance Connect fails / button is greyed out"

**Checklist**:
1. Is instance in "running" state? (not pending or stopped)
2. Was Auto-assign public IP set to **Enable** at launch? (most common cause)
3. Is `workshop-sg` attached with SSH (port 22) inbound rule?
4. Is region set to us-west-2?

**If public IP was not enabled at launch** (silent failure — no useful error):
- The instance must be terminated and relaunched — this can't be fixed after launch
- Relaunch with Network settings → Auto-assign public IP → **Enable**

**Quick check**:
```bash
# Verify instance has a public IP
aws ec2 describe-instances --instance-ids i-xxx \
    --query 'Reservations[0].Instances[0].PublicIpAddress' --output text
# If output is "None", the instance has no public IP — relaunch needed
```

---

### Issue: "Bucket name already exists"

**Solution**:
```bash
# Add name + today's date (workshop naming convention)
BUCKET_NAME="rcws-$(whoami)-$(date +%m%d)"
aws s3 mb s3://$BUCKET_NAME
```

---

### Issue: "You have exceeded your quota"

**Solution**:
```bash
# Check current quota
aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-1216C47A  # Running On-Demand instances

# Use truffle to check
truffle quotas --family Standard
```

**Workaround**:
- Use smaller instance type (m6a.large instead of m6a.xlarge — still research-appropriate)
- Request quota increase (takes 24 hours)

---

## Tips for Success

### Pacing
- **Move fast in intro** (10 min max) - people want hands-on
- **Slow down in Lab 1** - first EC2 launch is critical
- **Speed up in Lab 2** - they're comfortable now
- **End on time** - respect their schedule

### Engagement
- **Walk around during labs** - help strugglers early
- **Use checkpoints** - "Raise hand when you see X"
- **Share your screen** - show console as you explain
- **Pair programming** - encourage neighbors to help each other

### Recovery
- **Falling behind?** Skip CLI sidebars entirely, Console path only
- **Ahead of schedule?** Dive deeper into Cost Explorer, or start the spore.host bonus early
- **Total disaster?** Have pre-launched instances as backup

---

## Post-Workshop Follow-Up

### Day 1 After
- [ ] Email workshop materials (CURRICULUM.md, QUICK_REFERENCE.md, SPOREHOST_TEASER.md, WORKSHOP1_REDUX.md)
- [ ] Share AWS Research Credits link
- [ ] Send survey for feedback

### Week 1 After
- [ ] Office hours (optional)
- [ ] Share "next steps" resources
- [ ] Check in with participants who want to try it with real data — schedule office hours if interest is high

### Month 1 After
- [ ] Check if anyone applied for Research Credits
- [ ] Share success stories
- [ ] Plan advanced workshop (if interest)

---

## Backup Plans

### If WiFi fails
- Have USB drives with:
  - spore.host binaries
  - Workshop materials (PDF or printed)
  - Pre-configured AWS profiles

### If AWS is down
- Have slides prepared showing:
  - Recorded demo videos
  - Screenshots of each step
  - Theory content (how EC2 works, pricing models)

### If you're sick
- Have backup instructor
- Record session for self-paced learning
- Provide detailed written guide (this curriculum)

---

## Materials Checklist

### Before Workshop
- [ ] Printed handout with key commands
- [ ] USB drive with installers (backup)
- [ ] Projector tested
- [ ] Microphone tested (if large room)
- [ ] Whiteboard markers

### During Workshop
- [ ] Laptop with AWS account
- [ ] Extra power strips
- [ ] Name tags (optional)
- [ ] Sign-in sheet for follow-up

### After Workshop
- [ ] Collect feedback
- [ ] Note improvements for next time
- [ ] Archive materials

---

## Success Metrics

**Workshop is successful if**:
- 80%+ launch an EC2 instance successfully
- 70%+ create an S3 bucket
- 60%+ set up cost alerts
- 50%+ can explain when to use cloud vs campus HPC
- 30%+ will try it with real research data

**Red flags**:
- <50% complete Lab 1 → Too fast or too complex
- Many drop out after break → Lab 1 was frustrating
- No questions → Content too basic or too advanced

---

## Version History

- v2.0 (2026-01-29): CU Boulder workshop — Instance Connect (no SSH), Console-first, pre-flight Lab 0
