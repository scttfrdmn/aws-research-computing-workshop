# AWS Console Quick Reference

**For Workshop Participants** - Where to find everything in the AWS Console

---

## Getting Started

**Login**: https://console.aws.amazon.com

**Search Bar** (Top center): Type service name (EC2, S3, etc.) - fastest way to navigate!

**Keyboard Shortcuts**:
- `G` then `E` → Go to EC2
- `G` then `S` → Go to S3
- `?` → Show all shortcuts

---

## EC2 (Compute)

### How to Get There
1. Search bar: Type "EC2" OR
2. Services menu → Compute → EC2

### Key Screens

**Instances Dashboard** (EC2 → Instances)
```
┌─────────────────────────────────────────────┐
│ [Launch Instance]  [Actions ▼]  [Connect]  │
├─────────────────────────────────────────────┤
│ Filters: Name | Type | State | Tag         │
├─────────────────────────────────────────────┤
│ Instance ID | Name | Instance State | Type │
│ i-abc123   | research-01 | Running   | m6a.│
└─────────────────────────────────────────────┘
```
**What to look for**:
- Green "Running" = instance is up
- Public IPv4 address = how to connect
- Tags = your Workshop tag for cleanup

---

**Launch Instance Wizard**
```
┌─────────────────────────────────────────────┐
│ Step 1: Name and tags                       │
│   Name: [research-compute-01            ]   │
│   [Add new tag]                     │
│   Workshop=cu-boulder-2026, Owner=your-name │
├─────────────────────────────────────────────┤
│ Step 2: Application and OS Images (AMI)    │
│   ○ Amazon Linux 2023  [Free tier]         │
├─────────────────────────────────────────────┤
│ Step 3: Instance type                       │
│   ○ m6a.xlarge (4 vCPU, 16 GiB)            │
├─────────────────────────────────────────────┤
│ Step 4: Key pair (login)                   │
│   [Proceed without a key pair]             │
├─────────────────────────────────────────────┤
│ Step 5: Network settings → Edit            │
│   Security group: workshop-sg              │
│ ⚠️ Auto-assign public IP: Enable ← SET THIS│
│   ☑ Allow SSH traffic from: 0.0.0.0/0     │
├─────────────────────────────────────────────┤
│ Step 6: Configure storage                  │
│   8 GiB gp3                                │
├─────────────────────────────────────────────┤
│ Advanced details (scroll to bottom, expand)│
│ ⚠️ IAM instance profile: ec2-workshop-role │
├─────────────────────────────────────────────┤
│                      [Launch instance]      │
└─────────────────────────────────────────────┘
```

**Critical settings** — don't skip these:
- ✅ **Name and tags → Add new tag**: `Workshop=cu-boulder-2026`, `Owner=your-name`
- ✅ **Network settings → Auto-assign public IP = Enable** (if left on default, Instance Connect fails silently)
- ✅ **Advanced details → IAM instance profile = `ec2-workshop-role`** (required for S3 access)
- ✅ Allow SSH (port 22, Anywhere-IPv4) in `workshop-sg`

---

**Connect to Instance**
```
┌─────────────────────────────────────────────┐
│ Connect to instance: i-abc123              │
├─────────────────────────────────────────────┤
│ Tabs: [EC2 Instance Connect] [Session...] │
├─────────────────────────────────────────────┤
│ Connection method: EC2 Instance Connect    │
│ User name: ec2-user                        │
│                                             │
│               [Connect]                     │
└─────────────────────────────────────────────┘
```

**How to connect**:
1. Select instance → Click "Connect" button (top right)
2. Choose "EC2 Instance Connect" tab
3. Click "Connect" → Browser terminal opens!

---

## S3 (Storage)

### How to Get There
1. Search bar: Type "S3" OR
2. Services menu → Storage → S3

### Key Screens

**Buckets List**
```
┌─────────────────────────────────────────────┐
│ [Create bucket]                    [⚙️]     │
├─────────────────────────────────────────────┤
│ Search buckets: [                        ] │
├─────────────────────────────────────────────┤
│ Bucket name              | Region    | Access  │
│ rcws-yourname-0302       | us-west-2 | Private │
└─────────────────────────────────────────────┘
```

---

**Create Bucket**
```
┌─────────────────────────────────────────────┐
│ Bucket name: [must-be-globally-unique    ] │
│ Region: [us-west-2 ▼]                      │
├─────────────────────────────────────────────┤
│ Object Ownership: ACLs disabled (rec)      │
├─────────────────────────────────────────────┤
│ Block Public Access settings:              │
│ ☑ Block all public access ✅ (keep this!) │
├─────────────────────────────────────────────┤
│ Bucket Versioning: Disabled                │
│ Tags: Workshop = cu-boulder-2026           │
├─────────────────────────────────────────────┤
│                      [Create bucket]        │
└─────────────────────────────────────────────┘
```

**Critical**:
- Bucket name must be unique across ALL of AWS
- Keep "Block all public access" checked (security!)
- Add Workshop tag for easy cleanup

---

**Lifecycle Rules** (Cost savings!)
```
Path: S3 → Select bucket → Management tab → Create lifecycle rule

┌─────────────────────────────────────────────┐
│ Rule name: [transition-to-glacier        ] │
│ Rule scope: ○ Apply to all objects        │
├─────────────────────────────────────────────┤
│ Lifecycle rule actions:                    │
│ ☑ Transition current versions of objects  │
│   - After 30 days: Glacier Instant         │
│   - After 90 days: Glacier Flexible        │
├─────────────────────────────────────────────┤
│                  [Create rule]              │
└─────────────────────────────────────────────┘
```

**Why?** Saves 80-95% on storage costs for old data!

---

## Billing & Cost Management

### How to Get There
1. Click account name (top right) → "Billing and Cost Management" OR
2. Search bar: Type "Billing"

### Key Screens

**Credits** (Check your free money!)
```
Path: Billing → Credits (left sidebar)

┌─────────────────────────────────────────────┐
│ AWS Credits                                 │
├─────────────────────────────────────────────┤
│ Active Credits                              │
│                                             │
│ $1,000 AWS Research Credits                │
│ Expires: Dec 31, 2025                      │
│ Applied to date: $127.43                   │
│                                             │
│ Remaining: $872.57                         │
└─────────────────────────────────────────────┘
```

---

**Budgets** (Prevent surprise bills!)
```
Path: Billing → Budgets → Create budget

┌─────────────────────────────────────────────┐
│ Budget type: ○ Cost budget                 │
│ Period: Monthly                            │
│ Budget amount: $50                         │
├─────────────────────────────────────────────┤
│ Alert threshold: 80% of budgeted amount    │
│ Email recipients: your@email.edu           │
├─────────────────────────────────────────────┤
│                  [Create budget]            │
└─────────────────────────────────────────────┘
```

**What happens**: You get email when you hit $40 of your $50 budget

---

**Cost Explorer** (See what you're spending)
```
Path: Billing → Cost Explorer

┌─────────────────────────────────────────────┐
│ [Launch Cost Explorer]                     │
├─────────────────────────────────────────────┤
│ Date range: [Last 7 days ▼]               │
│ Group by: [Service ▼]                      │
├─────────────────────────────────────────────┤
│ [Bar chart showing costs by service]       │
│                                             │
│ EC2: $12.50                                │
│ S3:  $2.30                                 │
│ Data Transfer: $1.20                       │
└─────────────────────────────────────────────┘
```

---

## Tag-Based Cleanup (IMPORTANT!)

### Find Resources by Tag
```
EC2 → Instances → Add filter

┌─────────────────────────────────────────────┐
│ Filter: [Tag: Workshop           ▼]       │
│ Value:  [cu-boulder-2026          ]       │
├─────────────────────────────────────────────┤
│ Matching instances:                        │
│ ☑ i-abc123  research-compute-01            │
│ ☑ i-def456  research-compute-02            │
│ ☑ i-ghi789  research-spot-01               │
└─────────────────────────────────────────────┘

[Select all] → [Actions ▼] → [Terminate instance]
```

**This is why we tag everything!** One filter finds all workshop resources.

---

## Quick Tips

### Navigation Speed
✅ **DO**: Use search bar (fastest!)
❌ **DON'T**: Click through Services menu (slow)

### Cost Control
✅ **DO**: Tag everything with Workshop tag
✅ **DO**: Set up budget alerts immediately
✅ **DO**: Terminate instances when done
❌ **DON'T**: Leave instances running overnight

### Security
✅ **DO**: Use IAM roles (not long-lived keys)
✅ **DO**: Use AWS SSO login
✅ **DO**: Block public S3 access (unless needed)
❌ **DON'T**: Share your AWS credentials

### Finding Help
- In Console: Click "?" icon (top right) for help
- AWS Documentation: docs.aws.amazon.com
- Your research computing team!

---

## Common Console Locations

| What | Where |
|------|-------|
| Launch instances | EC2 → Instances → Launch Instance |
| Connect to instance | EC2 → Instances → Select → Connect |
| View running costs | Billing → Cost Explorer |
| Check credits | Billing → Credits |
| Create budget alert | Billing → Budgets → Create |
| Create S3 bucket | S3 → Create bucket |
| Add lifecycle policy | S3 → Select bucket → Management → Create rule |
| Filter by tags | Any service → Add filter → Tag:Workshop |
| Terminate resources | Select → Actions → Terminate |

---

## Keyboard Shortcuts (Power Users)

| Shortcut | Action |
|----------|--------|
| `G` + `E` | Go to EC2 |
| `G` + `S` | Go to S3 |
| `/` | Focus search bar |
| `?` | Show all shortcuts |

---

## When Console Fails You...

**Console is great for learning, but for real work**:
- Use AWS CLI (scriptable)
- Use spore.host (simple + scriptable)
- See QUICK_REFERENCE.md for CLI commands

**Remember**: Console = Learning. CLI/Tools = Production.

---

**Print this page and keep it handy during the workshop!** 📄
