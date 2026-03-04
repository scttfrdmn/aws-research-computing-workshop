# Introduction to AWS for Research Computing: From Campus HPC to Cloud

**Workshop for**: University of Colorado Boulder
**Duration**: 2 hours (hard stop) + optional 15-min bonus
**Last updated**: March 2026

---

## Workshop Materials

### For Participants

- **AGENDA.md** — Schedule and overview (start here)
- **CURRICULUM.md** — Complete lab guide with all steps and commands
- **CURRICULUM_LT.md** — Launch Template variant: automated instance setup via user-data
- **AUTO_STOP.md** — Cron script that stops an idle instance automatically (no logins, no CPU/network load)
- **QUICK_REFERENCE.md** — CLI command cheat sheet (printable)
- **CONSOLE_QUICK_REFERENCE.md** — Where to find things in the AWS Console
- **REMOTE_ACCESS_AND_TRANSFER.md** — SSH connection, Jupyter port forwarding, rclone, Cyberduck, WinSCP, VS Code Remote
- **SPOREHOST_TEASER.md** — spore.host quick start (post-workshop bonus)
- **WORKSHOP1_REDUX.md** — Workshop 1 Redux: The Fast Path (self-study, 45–60 minutes, does everything Workshop 1 did using spore.host)

### For Instructors

- **INSTRUCTOR_NOTES.md** — Teaching guide, timing, troubleshooting
- **INSTRUCTOR_LIVE_DEMO.md** — What to show on the projector at each step

### Workshop 2

- **workshop2/** — spore.host for Production Research Computing (separate workshop, requires Workshop 1 or equivalent)

---

## Philosophy

AWS is not a replacement for campus HPC — it's an augmentation. This workshop helps researchers recognize when cloud is the right tool: quota exhausted, GPU queue backed up, collaborators outside the university, a deadline that can't wait for the scheduler, or hardware your campus simply doesn't have (latest GPUs, terabytes of RAM, ARM processors, FPGAs, quantum devices). For everything else, keep using your campus allocation.

## Learning Objectives

Participants will:

1. Run a Lab 0 pre-flight check (region, VPC, security group, IAM role) before launching anything
2. Launch an EC2 instance (m6a.xlarge) using the Console — no SSH keys required
3. Connect via EC2 Instance Connect (browser terminal) and install a Python environment
4. Create an S3 bucket, upload data, run an analysis, and push results back to S3
5. Set up budget alerts and understand AWS Research Credits and GDEW
6. Clean up all resources using tag-based filtering

---

## Schedule

```
0:00-0:08  Introduction & motivation
0:08-0:18  Lab 0: Pre-flight check (region, VPC, security group, IAM role)
0:18-0:50  Lab 1: Launch EC2, connect, install miniforge, create S3 bucket
0:50-1:00  Break
1:00-1:45  Lab 2: Cost management, data transfer, analysis loop, cleanup
1:45-2:00  Wrap-up & resources
2:00+      Bonus: spore.host demo (optional, for those staying)
```

---

## Prerequisites

### Participants

- AWS account — create one at https://portal.aws.amazon.com/billing/signup
- A laptop with a modern web browser (Chrome, Firefox, Safari)
- Basic command line familiarity helpful but not required

No SSH client or local AWS CLI installation needed — the workshop uses EC2 Instance Connect (browser terminal) and AWS CloudShell.

### Instructors

- AWS account with EC2/S3/IAM/Budgets permissions
- Ability to share screen
- Test run: launch an m6a.xlarge instance in us-west-2 the day before to verify no quota issues

---

## Key Design Decisions

**Console is the primary path.** CLI commands are shown as optional sidebars in collapsible sections, run via AWS CloudShell (no local install needed).

**Lab 0 pre-flight.** Region, VPC, security group, and IAM role are set up before any instance launches. This eliminates the most common "nothing is working" problems.

**No SSH key pairs.** Participants connect via EC2 Instance Connect (browser-based terminal). This removes the key permission / chmod 400 failure class entirely.

**m6a.xlarge as workshop default.** 4 vCPU, 16 GB RAM, ~$0.17/hr. Representative of actual research workloads.

**Spot is mentioned, not done.** Using Spot safely requires checkpointing workflows. The workshop explains why, rather than teaching the flag alone.

---

## Pre-Workshop Checklist

**1 week before**:
- [ ] Send participant email with AWS account creation link
- [ ] Include workshop date, location, and "bring a laptop with a browser"

**Day before**:
- [ ] Launch and terminate a test m6a.xlarge in us-west-2 (verify quota)
- [ ] Print QUICK_REFERENCE.md and CONSOLE_QUICK_REFERENCE.md (1 per participant)
- [ ] Download spore.host binaries to USB drive (backup if WiFi fails)

**30 minutes before**:
- [ ] Test AV / screen sharing
- [ ] Write WiFi password on whiteboard
- [ ] Open AWS Console in browser, set region to us-west-2
- [ ] Open CloudShell: click `>_` in nav bar (bottom panel) — optionally expand to separate tab with ⤢ icon

---

## Quick Troubleshooting

| Problem | Solution |
|---------|----------|
| Instance Connect fails | Check Auto-assign public IP is set to Enable (not "Disable") |
| "No default VPC" | Have participant raise hand — create a default VPC via VPC console |
| Bucket name taken | Add name + today's date: `rcws-yourname-0302` |
| Quota exceeded | Use a smaller instance type temporarily; request increase takes 24h |
| CloudShell `$BUCKET_NAME` gone | Normal — sessions time out; re-set the variable |

---

## Post-Workshop Follow-Up

**Same day**: Share workshop materials, remind participants to check AWS credits (GDEW is already applied through CU's agreement — nothing to do).

**This week**: Office hours (optional). Share AWS Research Credits application link.

**This month**: Check in — did anyone use it with real data? Gather feedback for next run.

---

## Resources

- AWS Cloud Credit for Research: https://aws.amazon.com/government-education/research-and-technical-computing/cloud-credit-for-research/
- GDEW Information: https://aws.amazon.com/government-education/research-and-technical-computing/ (see GDEW section)
- CU Boulder Research Computing: https://www.colorado.edu/rc/
- spore.host GitHub: https://github.com/scttfrdmn/mycelium

---

## License

Copyright 2026 Scott Friedman.
Licensed under [CC BY-SA 4.0](https://creativecommons.org/licenses/by-sa/4.0/) — free to use, adapt, and redistribute with attribution; derivatives must carry the same license.

---

**Version**: 2.0 | **Prepared for**: CU Boulder Research Computing Team
