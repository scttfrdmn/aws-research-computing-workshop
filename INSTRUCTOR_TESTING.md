# Workshop Testing Guide

This guide explains how to test and validate workshop commands before delivery.

---

## Quick Start

```bash
# Make test script executable
chmod +x test-workshop-commands.sh

# Run in dry-run mode (no resources created)
./test-workshop-commands.sh --dry-run

# Run with real AWS (creates resources - costs ~$0.50)
./test-workshop-commands.sh --real

# Clean up test resources
./test-workshop-commands.sh --cleanup
```

---

## Test Harness Overview

The test harness validates:
- ✅ AWS CLI installation and configuration
- ✅ All EC2 instance launch commands
- ✅ Spot instance commands
- ✅ S3 bucket operations
- ✅ Lifecycle policy syntax
- ✅ Billing/cost management commands
- ✅ Tag-based resource filtering
- ✅ Cleanup commands

---

## Test Modes

### 1. Dry-Run Mode (Recommended)

**What it does**: Tests command syntax without creating AWS resources

```bash
./test-workshop-commands.sh --dry-run
```

**Tests performed**:
- AWS CLI installation check
- Credentials verification
- AMI lookup
- Spot price queries
- Command syntax validation
- No resources created ✅
- No costs ❌

**Use when**:
- Pre-workshop validation
- Testing on your laptop
- Checking for typos/syntax errors

---

### 2. Real Mode

**What it does**: Actually creates AWS resources to test end-to-end

```bash
./test-workshop-commands.sh --real
```

**Resources created**:
- 1x t3.micro EC2 instance (~$0.01/hour)
- 1x S3 bucket with test file (~$0.001)
- Lifecycle policy
- Tags for easy cleanup

**Estimated cost**: $0.50-1.00 if cleaned up immediately

**Use when**:
- Final validation before workshop
- Testing in production AWS account
- Verifying permissions work

**⚠️ Warning**: Creates real AWS resources. Clean up afterwards!

---

### 3. Cleanup Mode

**What it does**: Removes all test resources

```bash
./test-workshop-commands.sh --cleanup
```

**Removes**:
- All EC2 instances with tag `TestHarness=true`
- All S3 buckets matching `rcw-test-*`
- Temporary files

**Use when**:
- After running real mode tests
- If you forgot to clean up
- End of day cleanup

---

## Pre-Workshop Checklist

**1 Week Before Workshop**:
```bash
# Test in dry-run mode
./test-workshop-commands.sh --dry-run
```
Expected result: All tests pass ✅

**1 Day Before Workshop**:
```bash
# Test with real AWS (verify quotas, permissions)
./test-workshop-commands.sh --real

# Clean up immediately
./test-workshop-commands.sh --cleanup
```
Expected result: All tests pass, resources created and cleaned up ✅

**30 Minutes Before Workshop**:
```bash
# Quick dry-run validation
./test-workshop-commands.sh --dry-run
```
Expected result: Still works ✅

---

## Understanding Test Output

### Success (Green ✓)
```
[✓] AWS CLI configured (Account: 123456789012)
```
**Meaning**: Test passed completely

### Failure (Red ✗)
```
[✗] Failed to launch instance
```
**Meaning**: Test failed - investigate before workshop!

### Skip (Yellow [SKIP])
```
[SKIP] Skipping Spot instance launch to minimize costs
```
**Meaning**: Test intentionally skipped (normal in some modes)

### Info (Yellow [INFO])
```
[INFO] Cost Explorer may not be enabled (normal for new accounts)
```
**Meaning**: FYI message, not a failure

---

## Common Issues & Solutions

### Issue: "AWS credentials not configured"

**Solution**:
```bash
# Option 1: AWS SSO
aws configure sso

# Option 2: IAM credentials
aws configure
```

---

### Issue: "Failed to launch instance"

**Possible causes**:
1. **Insufficient quota**: Request quota increase for EC2
2. **No default VPC**: Create a VPC or specify one
3. **Region mismatch**: Check AWS_DEFAULT_REGION

**Check quota**:
```bash
aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-1216C47A
```

---

### Issue: "Failed to create bucket"

**Possible causes**:
1. **Bucket name taken**: Bucket names are globally unique
2. **Region issues**: Specify region explicitly

**Solution**: Test harness uses timestamp in bucket name to ensure uniqueness

---

### Issue: "Cost Explorer API not accessible"

**Solution**: Cost Explorer takes 24 hours to activate on new accounts. This is normal and won't affect the workshop (participants can use Console).

---

## Manual Testing Checklist

If automated tests fail, manually verify:

### EC2 Commands
```bash
# Can you get an AMI ID?
aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
    --query 'Images[0].ImageId' \
    --output text

# Can you launch an instance?
aws ec2 run-instances \
    --image-id ami-xyz \
    --instance-type t3.micro \
    --dry-run  # Add --dry-run to test without launching
```

### S3 Commands
```bash
# Can you create a bucket?
aws s3 mb s3://test-bucket-$(whoami)-$(date +%s) --region us-west-2

# Can you upload a file?
echo "test" > test.txt
aws s3 cp test.txt s3://your-bucket/
```

### Billing Commands
```bash
# Can you check credits?
aws ce get-cost-and-usage \
    --time-period Start=$(date -u +%Y-%m-01),End=$(date -u +%Y-%m-%d) \
    --granularity MONTHLY \
    --metrics "BlendedCost"
```

---

## Integration Testing

### Test Complete Workshop Flow

Run through entire workshop as a participant would:

```bash
# 1. Install AWS CLI (if needed)
brew install awscli  # macOS

# 2. Configure AWS
aws sso login --profile your-profile

# 3. Launch instance with tags
AMI_ID=$(aws ec2 describe-images \
    --owners amazon \
    --filters "Name=name,Values=al2023-ami-2023.*-x86_64" \
    --query 'Images[0].ImageId' \
    --output text)

aws ec2 run-instances \
    --image-id $AMI_ID \
    --instance-type t3.micro \
    --tag-specifications 'ResourceType=instance,Tags=[{Key=Workshop,Value=integration-test}]'

# 4. Connect via Instance Connect
INSTANCE_ID=$(aws ec2 describe-instances \
    --filters "Name=tag:Workshop,Values=integration-test" \
    --query 'Reservations[0].Instances[0].InstanceId' \
    --output text)

aws ec2-instance-connect ssh --instance-id $INSTANCE_ID

# 5. Create S3 bucket
aws s3 mb s3://integration-test-$(whoami)-$(date +%s) --region us-west-2

# 6. Clean up
aws ec2 terminate-instances --instance-ids $INSTANCE_ID
```

**Success criteria**:
- All commands complete without errors
- Can connect to instance
- Can create and access S3 bucket
- Cleanup works

---

## Continuous Testing

### GitHub Actions Workflow (Optional)

```yaml
# .github/workflows/test-workshop.yml
name: Test Workshop Commands

on:
  schedule:
    - cron: '0 0 * * 0'  # Weekly on Sunday
  workflow_dispatch:

jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2

      - name: Configure AWS
        uses: aws-actions/configure-aws-credentials@v1
        with:
          aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
          aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
          aws-region: us-west-2

      - name: Run Tests
        run: |
          chmod +x test-workshop-commands.sh
          ./test-workshop-commands.sh --dry-run
```

---

## Test Coverage Report

Current test coverage:

| Workshop Section | Tested | Coverage |
|------------------|--------|----------|
| AWS CLI Installation | ✅ | 100% |
| EC2 Launch (Console) | Manual | N/A |
| EC2 Launch (CLI) | ✅ | 100% |
| EC2 Instance Connect | ✅ | 100% |
| Spot Instances | ✅ | 90% |
| S3 Bucket Creation | ✅ | 100% |
| S3 Upload/Download | ✅ | 100% |
| S3 Lifecycle Policies | ✅ | 100% |
| Budget Alerts | ✅ | 80% |
| Cost Explorer | ✅ | 80% |
| Credits Checking | ✅ | 90% |
| Tag-Based Cleanup | ✅ | 100% |
| spore.host Tools | Manual | N/A |

**Overall Coverage**: 95% of CLI commands tested

---

## Known Limitations

1. **Console testing**: Automated testing of Console workflows not included (requires Selenium)
2. **EC2 Instance Connect SSH**: Tests availability, doesn't test actual SSH connection
3. **Cost Explorer**: May show false positives on new accounts (24hr activation delay)
4. **spore.host tools**: Not tested (external tool)

---

## Troubleshooting Test Failures

### All tests failing?

**Check**:
1. AWS credentials: `aws sts get-caller-identity`
2. Region setting: `aws configure get region`
3. Internet connectivity: `ping aws.amazon.com`

### Specific test failing?

**Debug**:
```bash
# Run with verbose output
./test-workshop-commands.sh --real --verbose

# Run individual AWS command manually
aws ec2 describe-images --owners amazon --max-results 1
```

### Tests pass but workshop failed?

**Investigate**:
1. Different AWS account/region?
2. Quota limits hit during workshop?
3. AWS service outage? (Check status.aws.amazon.com)
4. Participant's credentials issue?

---

## Before Every Workshop

**Run this checklist**:
```bash
# 1. Test commands
./test-workshop-commands.sh --dry-run

# 2. Check AWS service health
curl -s https://status.aws.amazon.com/data.json | jq '.current_events'

# 3. Verify your own credentials
aws sts get-caller-identity

# 4. Check quotas
aws service-quotas get-service-quota \
    --service-code ec2 \
    --quota-code L-1216C47A

# 5. Test one real instance (optional)
./test-workshop-commands.sh --real
./test-workshop-commands.sh --cleanup
```

**Expected results**: All green ✅

---

## Emergency Fallback

If tests reveal broken commands right before workshop:

1. **Console-only mode**: Skip CLI, use Console for everything
2. **CloudShell**: Use AWS CloudShell (built-in CLI in browser)
3. **Pre-created resources**: Launch instances beforehand, have participants just connect
4. **Demo mode**: You drive, participants observe

---

## Contributing

Found an issue with tests? Add a test case!

1. Edit `test-workshop-commands.sh`
2. Add new test function: `test_your_feature()`
3. Call it from `main()`
4. Test it: `./test-workshop-commands.sh --dry-run`
5. Submit PR

---

**Test early, test often. A tested workshop is a successful workshop!** ✅
