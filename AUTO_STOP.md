# Auto-Stop: Idle Instance Shutdown

A cron job that automatically stops your EC2 instance when it has been idle — no active logins, no CPU load, no network traffic — for a configurable number of minutes.

This is the practical answer to: *"you're renting hardware, not owning it — shut it down when you're not using it."* Forgetting to stop a running instance overnight or over a weekend is the most common source of unexpected AWS charges. This script removes the human error.

> **What "stop" means here**: for EBS-backed instances (the kind you launch in this workshop), stopping the OS causes AWS to stop the instance — it is not terminated. Your data, conda environments, and home directory are preserved. You can restart it from the EC2 Console anytime.

---

## How It Works

A script runs every minute via cron. Each run:

1. Checks for **logged-in users** (`who`)
2. Checks **CPU load** (1-minute average from `/proc/loadavg`)
3. Checks **network activity** (bytes delta on the primary interface since last run)

If any activity is detected, a timestamp file is updated and the script exits.

If **no activity is detected** and the timestamp file is older than the configured threshold, the instance is stopped via `shutdown`.

---

## Prerequisites

- An EC2 instance launched with an EBS root volume (the default — all instances in this workshop qualify)
- No extra IAM permissions needed — `shutdown` is an OS command, not an AWS API call

---

## Setup

### Step 1: Create the script

Connect to your instance via EC2 Instance Connect, then:

```bash
sudo tee /usr/local/bin/auto-stop.sh > /dev/null << 'EOF'
#!/bin/bash
# auto-stop.sh
# Stops the EC2 instance after IDLE_THRESHOLD_MINUTES of inactivity.
# Inactivity = no logged-in users, CPU load below threshold, network below threshold.
#
# Runs as root via cron. Logs to /var/log/auto-stop.log.

# ── Configuration ─────────────────────────────────────────────────────────────
IDLE_THRESHOLD_MINUTES=15   # stop after this many idle minutes
CPU_THRESHOLD="0.10"        # 1-min load average; 0.10 = ~10% of one core
NET_THRESHOLD=51200          # bytes per minute considered idle (~50 KB/min)

# ── State files ───────────────────────────────────────────────────────────────
LAST_ACTIVE_FILE=/tmp/.autostop-last-active
NET_STATS_FILE=/tmp/.autostop-net-stats

# ── Helpers ───────────────────────────────────────────────────────────────────
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

is_active() {
    # 1. Logged-in users
    if [ "$(who | wc -l)" -gt 0 ]; then
        log "Active: user(s) logged in: $(who | awk '{print $1}' | sort -u | tr '\n' ' ')"
        return 0
    fi

    # 2. CPU load
    cpu_load=$(awk '{print $1}' /proc/loadavg)
    if awk "BEGIN { exit !($cpu_load > $CPU_THRESHOLD) }"; then
        log "Active: CPU load ${cpu_load} > ${CPU_THRESHOLD}"
        return 0
    fi

    # 3. Network activity (delta since last run)
    iface=$(ip route get 1.1.1.1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' \
        | head -1)

    if [ -n "$iface" ]; then
        # /proc/net/dev columns: iface: rx_bytes ... tx_bytes ...
        read -r rx tx < <(awk -v iface="${iface}:" \
            '$1==iface {print $2, $10}' /proc/net/dev)
        current=$(( rx + tx ))

        if [ -f "$NET_STATS_FILE" ]; then
            prev=$(cat "$NET_STATS_FILE")
            delta=$(( current - prev ))
            if [ "$delta" -gt "$NET_THRESHOLD" ]; then
                log "Active: network delta ${delta} bytes > ${NET_THRESHOLD}"
                echo "$current" > "$NET_STATS_FILE"
                return 0
            fi
        fi

        echo "$current" > "$NET_STATS_FILE"
    fi

    return 1  # idle
}

# ── Main ──────────────────────────────────────────────────────────────────────
if is_active; then
    date +%s > "$LAST_ACTIVE_FILE"
    exit 0
fi

# No activity detected — check how long we've been idle
if [ ! -f "$LAST_ACTIVE_FILE" ]; then
    log "No last-active file found, initialising."
    date +%s > "$LAST_ACTIVE_FILE"
    exit 0
fi

last_active=$(cat "$LAST_ACTIVE_FILE")
now=$(date +%s)
idle_minutes=$(( (now - last_active) / 60 ))

log "Idle for ${idle_minutes}/${IDLE_THRESHOLD_MINUTES} minutes."

if [ "$idle_minutes" -ge "$IDLE_THRESHOLD_MINUTES" ]; then
    log "Threshold reached — stopping instance."
    shutdown -h now "auto-stop: idle for ${idle_minutes} minutes"
fi
EOF

sudo chmod +x /usr/local/bin/auto-stop.sh
```

### Step 2: Create the log file

```bash
sudo touch /var/log/auto-stop.log
sudo chmod 644 /var/log/auto-stop.log
```

### Step 3: Install the cron job

```bash
# Add to root's crontab — runs every minute
echo "* * * * * root /usr/local/bin/auto-stop.sh >> /var/log/auto-stop.log 2>&1" \
    | sudo tee /etc/cron.d/auto-stop

sudo chmod 644 /etc/cron.d/auto-stop
```

### Step 4: Verify it's running

Wait 2 minutes, then check the log:

```bash
sudo tail -20 /var/log/auto-stop.log
```

You should see lines like:

```
2026-03-04 14:23:01 Idle for 1/15 minutes.
2026-03-04 14:24:01 Idle for 2/15 minutes.
```

If you log in via a second session while watching, you'll see:

```
2026-03-04 14:25:01 Active: user(s) logged in: ec2-user
```

And the idle counter resets.

---

## Tuning

Edit `/usr/local/bin/auto-stop.sh` and adjust the three values at the top:

| Variable | Default | Meaning |
|---|---|---|
| `IDLE_THRESHOLD_MINUTES` | `15` | Minutes of inactivity before stopping |
| `CPU_THRESHOLD` | `0.10` | 1-min load average above this = active |
| `NET_THRESHOLD` | `51200` | Bytes/minute above this = active (~50 KB/min) |

After editing, the new values take effect on the next cron run — no restart needed.

**Suggested values by use case**:

| Situation | `IDLE_THRESHOLD_MINUTES` | `CPU_THRESHOLD` | `NET_THRESHOLD` |
|---|---|---|---|
| Interactive / workshop | 15 | 0.10 | 51200 |
| Long-running batch job | 60 | 0.50 | 102400 |
| Overnight job with S3 writes | 30 | 0.25 | 204800 |

For batch jobs that run unattended: raise `CPU_THRESHOLD` and `NET_THRESHOLD` so the script doesn't stop the instance mid-job, but still catches it when the job is truly done.

---

## Disabling

To turn off auto-stop without removing it:

```bash
sudo rm /etc/cron.d/auto-stop
```

To re-enable:

```bash
echo "* * * * * root /usr/local/bin/auto-stop.sh >> /var/log/auto-stop.log 2>&1" \
    | sudo tee /etc/cron.d/auto-stop
sudo chmod 644 /etc/cron.d/auto-stop
```

To remove it entirely:

```bash
sudo rm /etc/cron.d/auto-stop /usr/local/bin/auto-stop.sh /var/log/auto-stop.log
```

---

## Adding to the Launch Template user-data

To have every instance you launch install auto-stop automatically, append the following to the user-data script in your Launch Template (Lab 1, Step 9 in CURRICULUM_LT.md):

```bash
# ── Auto-stop (add after the ec2-user conda section) ──────────────────────────
cat > /usr/local/bin/auto-stop.sh << 'AUTOSTOP'
#!/bin/bash
IDLE_THRESHOLD_MINUTES=15
CPU_THRESHOLD="0.10"
NET_THRESHOLD=51200
LAST_ACTIVE_FILE=/tmp/.autostop-last-active
NET_STATS_FILE=/tmp/.autostop-net-stats

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*"; }

is_active() {
    [ "$(who | wc -l)" -gt 0 ] && { log "Active: user(s) logged in"; return 0; }
    cpu_load=$(awk '{print $1}' /proc/loadavg)
    awk "BEGIN { exit !($cpu_load > $CPU_THRESHOLD) }" && {
        log "Active: CPU load ${cpu_load}"; return 0; }
    iface=$(ip route get 1.1.1.1 2>/dev/null \
        | awk '{for(i=1;i<=NF;i++) if($i=="dev") print $(i+1)}' | head -1)
    if [ -n "$iface" ]; then
        read -r rx tx < <(awk -v iface="${iface}:" '$1==iface {print $2, $10}' /proc/net/dev)
        current=$(( rx + tx ))
        if [ -f "$NET_STATS_FILE" ]; then
            delta=$(( current - $(cat "$NET_STATS_FILE") ))
            [ "$delta" -gt "$NET_THRESHOLD" ] && {
                log "Active: network delta ${delta} bytes"; echo "$current" > "$NET_STATS_FILE"; return 0; }
        fi
        echo "$current" > "$NET_STATS_FILE"
    fi
    return 1
}

if is_active; then date +%s > "$LAST_ACTIVE_FILE"; exit 0; fi
[ ! -f "$LAST_ACTIVE_FILE" ] && { date +%s > "$LAST_ACTIVE_FILE"; exit 0; }
idle_minutes=$(( ($(date +%s) - $(cat "$LAST_ACTIVE_FILE")) / 60 ))
log "Idle for ${idle_minutes}/${IDLE_THRESHOLD_MINUTES} minutes."
[ "$idle_minutes" -ge "$IDLE_THRESHOLD_MINUTES" ] && {
    log "Stopping instance."; shutdown -h now "auto-stop: idle ${idle_minutes}m"; }
AUTOSTOP

chmod +x /usr/local/bin/auto-stop.sh
touch /var/log/auto-stop.log
chmod 644 /var/log/auto-stop.log
echo "* * * * * root /usr/local/bin/auto-stop.sh >> /var/log/auto-stop.log 2>&1" \
    > /etc/cron.d/auto-stop
chmod 644 /etc/cron.d/auto-stop
echo "=== Auto-stop installed ===" >> /var/log/user-data.log
```

With this in user-data, every instance launched from the template will auto-stop after 15 minutes of inactivity. Adjust `IDLE_THRESHOLD_MINUTES` at the top of the script after first launch if needed.

---

## Notes

- **Restart after auto-stop**: EC2 Console → select the stopped instance → **Instance state** → **Start instance**. Your data is intact.
- **This does not prevent termination**: if you run the tag-based cleanup from CURRICULUM.md, it will terminate the instance regardless. Auto-stop only guards against forgetting to stop a running instance.
- **Log rotation**: `/var/log/auto-stop.log` grows at roughly 1 line/minute. At that rate it takes years to become large, but you can truncate it anytime with `sudo truncate -s 0 /var/log/auto-stop.log`.
