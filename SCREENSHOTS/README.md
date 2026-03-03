# Workshop Screenshots

Six targeted screenshots for the moments where text descriptions alone aren't enough.
Capture these during a test run. Drop the files here with the names below.

**Capture settings**:
- Browser zoom: 100%
- AWS Console: light mode
- Region: us-west-2 (Oregon) set before capturing
- Hide account ID / email if visible (blur or crop)
- macOS: `Cmd+Shift+4` to select area
- Windows: `Win+Shift+S`

---

## 01-security-group-search.png

**What**: The top search bar showing results after typing "Security Groups"

**How to get there**: From any page, click the search bar at the very top of the AWS Console and type `Security Groups` — do not press Enter yet

**What to show**: The dropdown results with two entries visible:
- `EC2 > Security Groups` (this one)
- `VPC > Security Groups` (not this one)

**Annotate**: Red arrow or box on `EC2 > Security Groups`. Small label: "Use this one"

**Used in**: Lab 0, Step 3

---

## 02-advanced-details-collapsed.png

**What**: The EC2 launch wizard with "Advanced details" visible but collapsed at the bottom of the page

**How to get there**: EC2 → Launch Instance → scroll to the very bottom of the page

**What to show**: The "Advanced details" section header with the expand chevron, in its collapsed/closed state. Show enough of the page above it to convey "this is at the bottom"

**Annotate**: Red arrow pointing at the accordion header. Label: "Expand this — don't skip it"

**Used in**: Lab 1, Step 7 (UX warning)

---

## 03-advanced-details-expanded.png

**What**: Advanced details expanded, showing IAM instance profile set to `ec2-workshop-role` and the resource tags filled in

**How to get there**: Same page as above, after clicking to expand. Scroll within the expanded section until both IAM instance profile and resource tags are visible

**What to show**:
- "IAM instance profile" field showing `ec2-workshop-role` selected
- Resource tags with Key `Workshop` / Value `cu-boulder-2026` and Key `Owner` / Value (anything)

**Annotate**: Red boxes around both the IAM profile dropdown and the tags rows

**Used in**: Lab 1, Steps 7a and 7b

---

## 04-public-ip-enable.png

**What**: The Network settings section of the EC2 launch wizard with Auto-assign public IP set to "Enable"

**How to get there**: EC2 → Launch Instance → Network settings → click "Edit" → find "Auto-assign public IP"

**What to show**: The dropdown clearly showing "Enable" selected (not "Disable")

**Annotate**: Red box around the dropdown. Label: "Must be Enable"

**Used in**: Lab 1, Step 6

---

## 05-instance-connect-tab.png

**What**: The Connect dialog for an EC2 instance, with the "EC2 Instance Connect" tab selected

**How to get there**: EC2 → Instances → check the box next to a running instance → click "Connect" (action bar above the list) → the Connect dialog opens with multiple tabs

**What to show**: All four tabs visible — "EC2 Instance Connect" (selected/active), "Session Manager", "EC2 serial console", "SSH client" — with EC2 Instance Connect tab highlighted

**Annotate**: Red box or underline on the "EC2 Instance Connect" tab. Label: "Use this tab"

**Used in**: Lab 1, Step 9

---

## 06-tag-filter-cleanup.png

**What**: The EC2 Instances list filtered by the Workshop tag, showing only workshop instances selected

**How to get there**: EC2 → Instances → click the search bar → type `Workshop` → dropdown appears → click **"Workshop = All values"** → all workshop instances appear → select all checkboxes

**What to show**: The filtered list with:
- The active filter chip visible at the top: "Workshop = cu-boulder-2026 ×"
- One or more instances checked (checkbox column)
- **Instance state** button visible in the action bar (used for Terminate)

**Annotate**: Red box on the filter badge. Label: "This is why we tagged everything"

**Used in**: Lab 2, Part C (Cleanup)

---

## Optional: 07-cloudshell-icon.png

Low priority — only capture if time allows.

**What**: The top navigation bar of the AWS Console with the CloudShell icon (`>_`) highlighted

**Annotate**: Red arrow pointing at the `>_` icon. Label: "CloudShell — browser terminal, no install needed"

**Used in**: Lab 0, Step 4 and throughout CLI sidebars

---

## Maintenance Note

AWS updates their Console UI regularly. Before each workshop delivery, spot-check these five moments against the current UI. If the layout has shifted, recapture.

Screenshots that need the most frequent attention: `02` and `03` (Advanced details layout changes often) and `05` (Connect dialog has been redesigned before).
