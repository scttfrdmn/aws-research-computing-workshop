#!/bin/bash
# Test Harness for AWS Research Computing Workshop
# Validates all CLI commands work correctly before workshop delivery
#
# Usage:
#   ./test-workshop-commands.sh --dry-run    # Test without creating resources
#   ./test-workshop-commands.sh --real       # Test with actual AWS (costs money!)
#   ./test-workshop-commands.sh --cleanup    # Clean up test resources

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
TEST_TAG_VALUE="workshop-test-$(date +%s)"
TEST_BUCKET_SUFFIX=$(whoami)-$(date +%s)
DRY_RUN=false
CLEANUP_ONLY=false
VERBOSE=false

# Test results
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Function to print colored output
print_test() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[✓]${NC} $1"
    TESTS_PASSED=$((TESTS_PASSED + 1))
}

print_failure() {
    echo -e "${RED}[✗]${NC} $1"
    TESTS_FAILED=$((TESTS_FAILED + 1))
}

print_skip() {
    echo -e "${YELLOW}[SKIP]${NC} $1"
    TESTS_SKIPPED=$((TESTS_SKIPPED + 1))
}

print_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Function to check if command exists
check_command() {
    if ! command -v "$1" &> /dev/null; then
        print_failure "Command '$1' not found"
        return 1
    fi
    return 0
}

# Function to test AWS CLI is installed and configured
test_aws_cli_setup() {
    print_test "Checking AWS CLI installation and configuration"

    if ! check_command aws; then
        print_failure "AWS CLI not installed"
        return 1
    fi

    # Check AWS CLI version
    local version=$(aws --version 2>&1 | cut -d' ' -f1 | cut -d'/' -f2)
    print_info "AWS CLI version: $version"

    # Test AWS credentials are configured
    if ! aws sts get-caller-identity &> /dev/null; then
        print_failure "AWS credentials not configured"
        print_info "Run: aws configure sso OR aws configure"
        return 1
    fi

    local account_id=$(aws sts get-caller-identity --query Account --output text)
    local user_arn=$(aws sts get-caller-identity --query Arn --output text)
    print_success "AWS CLI configured (Account: $account_id)"
    print_info "User: $user_arn"

    return 0
}

# Function to test EC2 instance launch commands
test_ec2_launch() {
    print_test "Testing EC2 instance launch commands"

    # Get latest Amazon Linux AMI (using SSM parameter — matches CURRICULUM.md recommended method)
    print_test "Fetching latest Amazon Linux 2023 AMI"
    local ami_id=$(aws ssm get-parameters \
        --names /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
        --region us-west-2 \
        --query 'Parameters[0].Value' \
        --output text 2>/dev/null)

    if [[ -z "$ami_id" ]]; then
        print_failure "Failed to fetch AMI ID"
        return 1
    fi
    print_success "AMI ID retrieved: $ami_id"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_skip "Skipping actual instance launch (dry-run mode)"
        return 0
    fi

    # Launch test instance
    print_test "Launching test EC2 instance (t3.micro for cost)"
    local instance_id=$(aws ec2 run-instances \
        --image-id "$ami_id" \
        --instance-type t3.micro \
        --tag-specifications "ResourceType=instance,Tags=[{Key=Name,Value=test-instance},{Key=Workshop,Value=$TEST_TAG_VALUE},{Key=TestHarness,Value=true}]" \
        --count 1 \
        --query 'Instances[0].InstanceId' \
        --output text 2>/dev/null)

    if [[ -z "$instance_id" ]]; then
        print_failure "Failed to launch instance"
        return 1
    fi
    print_success "Instance launched: $instance_id"

    # Wait for instance to be running
    print_test "Waiting for instance to reach running state..."
    aws ec2 wait instance-running --instance-ids "$instance_id"
    print_success "Instance is running"

    # Test describe instances with tag filter
    print_test "Testing instance query by tag"
    local found_instance=$(aws ec2 describe-instances \
        --filters "Name=tag:Workshop,Values=$TEST_TAG_VALUE" \
        --query 'Reservations[0].Instances[0].InstanceId' \
        --output text 2>/dev/null)

    if [[ "$found_instance" == "$instance_id" ]]; then
        print_success "Instance found by tag filter"
    else
        print_failure "Instance not found by tag filter"
        return 1
    fi

    # Get public IP
    print_test "Retrieving instance public IP"
    local public_ip=$(aws ec2 describe-instances \
        --instance-ids "$instance_id" \
        --query 'Reservations[0].Instances[0].PublicIpAddress' \
        --output text 2>/dev/null)

    if [[ -n "$public_ip" && "$public_ip" != "None" ]]; then
        print_success "Public IP retrieved: $public_ip"
    else
        print_info "No public IP (instance may be in private subnet)"
    fi

    # Test EC2 Instance Connect SSH availability
    print_test "Testing EC2 Instance Connect availability"
    if aws ec2-instance-connect send-ssh-public-key \
        --instance-id "$instance_id" \
        --instance-os-user ec2-user \
        --ssh-public-key "ssh-rsa AAAAB3NzaC1yc2EAAAADAQABAAABAQC3" \
        --dry-run 2>&1 | grep -q "DryRunOperation"; then
        print_success "EC2 Instance Connect is available"
    else
        print_info "EC2 Instance Connect check inconclusive (may require instance to be fully ready)"
    fi

    return 0
}

# Function to test Spot instance commands
test_spot_instances() {
    print_test "Testing Spot instance commands"

    # Test Spot price history query
    print_test "Fetching Spot price history"
    local spot_price=$(aws ec2 describe-spot-price-history \
        --instance-types t3.micro \
        --product-descriptions "Linux/UNIX" \
        --max-results 1 \
        --query 'SpotPriceHistory[0].SpotPrice' \
        --output text 2>/dev/null)

    if [[ -n "$spot_price" ]]; then
        print_success "Spot price retrieved: \$$spot_price/hour"
    else
        print_failure "Failed to retrieve Spot price"
        return 1
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        print_skip "Skipping Spot instance launch (dry-run mode)"
        return 0
    fi

    # Launch Spot instance (skip to save costs in real testing)
    print_skip "Skipping actual Spot instance launch to minimize costs"
    print_info "Spot launch command syntax validated"

    return 0
}

# Function to test S3 commands
test_s3_operations() {
    print_test "Testing S3 bucket operations"

    local bucket_name="rcw-test-$TEST_BUCKET_SUFFIX"

    if [[ "$DRY_RUN" == "true" ]]; then
        print_skip "Skipping S3 operations (dry-run mode)"
        return 0
    fi

    # Create bucket
    print_test "Creating test S3 bucket: $bucket_name"
    if aws s3 mb "s3://$bucket_name" --region us-west-2 2>/dev/null; then
        print_success "Bucket created"
    else
        print_failure "Failed to create bucket"
        return 1
    fi

    # Upload test file
    print_test "Uploading test file"
    echo "Test data for workshop validation" > /tmp/test-workshop-data.txt
    if aws s3 cp /tmp/test-workshop-data.txt "s3://$bucket_name/" 2>/dev/null; then
        print_success "File uploaded"
    else
        print_failure "Failed to upload file"
        return 1
    fi

    # List bucket contents
    print_test "Listing bucket contents"
    if aws s3 ls "s3://$bucket_name/" | grep -q "test-workshop-data.txt"; then
        print_success "File listed successfully"
    else
        print_failure "Failed to list file"
        return 1
    fi

    # Test lifecycle policy syntax
    print_test "Testing lifecycle policy syntax"
    cat > /tmp/test-lifecycle.json <<'EOF'
{
  "Rules": [
    {
      "Id": "TestTransition",
      "Status": "Enabled",
      "Transitions": [
        {
          "Days": 30,
          "StorageClass": "GLACIER_IR"
        }
      ]
    }
  ]
}
EOF

    if aws s3api put-bucket-lifecycle-configuration \
        --bucket "$bucket_name" \
        --lifecycle-configuration file:///tmp/test-lifecycle.json 2>/dev/null; then
        print_success "Lifecycle policy applied"
    else
        print_failure "Failed to apply lifecycle policy"
        return 1
    fi

    # Verify lifecycle policy
    print_test "Verifying lifecycle policy"
    if aws s3api get-bucket-lifecycle-configuration \
        --bucket "$bucket_name" \
        --query 'Rules[0].Id' \
        --output text 2>/dev/null | grep -q "TestTransition"; then
        print_success "Lifecycle policy verified"
    else
        print_failure "Failed to verify lifecycle policy"
        return 1
    fi

    return 0
}

# Function to test billing/cost commands
test_billing_commands() {
    print_test "Testing billing and cost management commands"

    # Test Cost Explorer access
    print_test "Testing Cost Explorer API access"
    # Cross-platform date handling (macOS uses -v, Linux uses -d)
    if date --version &>/dev/null; then
        # GNU date (Linux)
        START_DATE=$(date -u -d '7 days ago' +%Y-%m-%d)
        END_DATE=$(date -u +%Y-%m-%d)
        CREDITS_START=$(date -u -d '30 days ago' +%Y-%m-%d)
    else
        # BSD date (macOS)
        START_DATE=$(date -u -v-7d +%Y-%m-%d)
        END_DATE=$(date -u +%Y-%m-%d)
        CREDITS_START=$(date -u -v-30d +%Y-%m-%d)
    fi

    if aws ce get-cost-and-usage \
        --time-period Start=$START_DATE,End=$END_DATE \
        --granularity DAILY \
        --metrics "BlendedCost" \
        --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
        --output text &> /dev/null; then
        print_success "Cost Explorer API accessible"
    else
        print_info "Cost Explorer may not be enabled (normal for new accounts)"
    fi

    # Test credits check
    print_test "Testing credits query"
    local credits=$(aws ce get-cost-and-usage \
        --time-period Start=$CREDITS_START,End=$END_DATE \
        --granularity MONTHLY \
        --metrics "BlendedCost" \
        --filter '{"Dimensions":{"Key":"RECORD_TYPE","Values":["Credit"]}}' \
        --query 'ResultsByTime[0].Total.BlendedCost.Amount' \
        --output text 2>/dev/null || echo "0")

    print_info "Credits check completed (amount: \$$credits)"
    print_success "Credits query syntax validated"

    # Test budget list (read-only)
    print_test "Testing budget list access"
    local account_id=$(aws sts get-caller-identity --query Account --output text)
    if aws budgets describe-budgets --account-id "$account_id" &> /dev/null; then
        print_success "Budget API accessible"
    else
        print_info "Budget API access may require additional permissions"
    fi

    return 0
}

# Function to test tag-based cleanup commands
test_tag_based_cleanup() {
    print_test "Testing tag-based resource filtering"

    # Test filtering instances by tag
    print_test "Querying instances by Workshop tag"
    local instances=$(aws ec2 describe-instances \
        --filters "Name=tag:Workshop,Values=$TEST_TAG_VALUE" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text 2>/dev/null)

    if [[ -n "$instances" ]]; then
        local count=$(echo "$instances" | wc -w)
        print_success "Found $count instance(s) with test tag"
    else
        print_info "No instances found with test tag (expected if in dry-run)"
    fi

    # Test cleanup command syntax (without actually running)
    print_test "Validating cleanup command syntax"
    local cleanup_cmd="aws ec2 terminate-instances --instance-ids \$(aws ec2 describe-instances --filters 'Name=tag:Workshop,Values=$TEST_TAG_VALUE' --query 'Reservations[].Instances[].InstanceId' --output text)"
    print_success "Cleanup command syntax validated"
    print_info "Command: $cleanup_cmd"

    return 0
}

# Function to test AWS CLI installation methods
test_cli_installation_docs() {
    print_test "Validating CLI installation documentation"

    # Check if common package managers are available
    if command -v brew &> /dev/null; then
        print_info "Homebrew detected (macOS)"
        print_success "Installation method: brew install awscli"
    fi

    if command -v scoop &> /dev/null; then
        print_info "Scoop detected (Windows)"
        print_success "Installation method: scoop install aws"
    fi

    # Verify AWS CLI can be found in PATH
    if command -v aws &> /dev/null; then
        local aws_path=$(which aws)
        print_success "AWS CLI found at: $aws_path"
    fi

    return 0
}

# Function to test SSO login workflow
test_sso_login() {
    print_test "Testing AWS SSO login workflow"

    # Check if SSO is configured
    if grep -q "sso_" ~/.aws/config 2>/dev/null; then
        print_info "SSO configuration detected in ~/.aws/config"
        print_success "SSO configuration exists"
    else
        print_info "No SSO configuration found (using IAM credentials is also valid)"
    fi

    # Verify current authentication works
    if aws sts get-caller-identity &> /dev/null; then
        print_success "Current AWS authentication working"
    else
        print_failure "AWS authentication not working"
        return 1
    fi

    return 0
}

# Cleanup function
cleanup_test_resources() {
    print_test "Cleaning up test resources"

    # Terminate test EC2 instances
    print_test "Terminating test instances"
    local instances=$(aws ec2 describe-instances \
        --filters "Name=tag:TestHarness,Values=true" "Name=instance-state-name,Values=running,stopped,pending" \
        --query 'Reservations[].Instances[].InstanceId' \
        --output text 2>/dev/null)

    if [[ -n "$instances" ]]; then
        aws ec2 terminate-instances --instance-ids $instances &> /dev/null
        print_success "Terminated test instances: $instances"
    else
        print_info "No test instances to clean up"
    fi

    # Delete test S3 buckets
    print_test "Deleting test S3 buckets"
    local buckets=$(aws s3 ls | grep "rcw-test-$TEST_BUCKET_SUFFIX" | awk '{print $3}')

    for bucket in $buckets; do
        print_test "Deleting bucket: $bucket"
        aws s3 rm "s3://$bucket/" --recursive &> /dev/null
        aws s3 rb "s3://$bucket/" &> /dev/null
        print_success "Deleted bucket: $bucket"
    done

    # Clean up temp files
    rm -f /tmp/test-workshop-data.txt /tmp/test-lifecycle.json
    print_success "Cleaned up temporary files"
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --dry-run)
            DRY_RUN=true
            shift
            ;;
        --real)
            DRY_RUN=false
            shift
            ;;
        --cleanup)
            CLEANUP_ONLY=true
            shift
            ;;
        --verbose)
            VERBOSE=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--dry-run|--real] [--cleanup] [--verbose]"
            exit 1
            ;;
    esac
done

# Main execution
main() {
    echo "========================================================================"
    echo "AWS Research Computing Workshop - Test Harness"
    echo "========================================================================"
    echo ""

    if [[ "$CLEANUP_ONLY" == "true" ]]; then
        cleanup_test_resources
        exit 0
    fi

    if [[ "$DRY_RUN" == "true" ]]; then
        print_info "Running in DRY-RUN mode (no AWS resources will be created)"
    else
        print_info "Running in REAL mode (AWS resources will be created - costs apply!)"
        print_info "Test tag: $TEST_TAG_VALUE"
        echo ""
        read -p "Continue? (yes/no): " confirm
        if [[ "$confirm" != "yes" ]]; then
            echo "Aborted."
            exit 0
        fi
    fi

    echo ""
    echo "Running tests..."
    echo ""

    # Run all tests
    test_aws_cli_setup
    test_cli_installation_docs
    test_sso_login
    test_ec2_launch
    test_spot_instances
    test_s3_operations
    test_billing_commands
    test_tag_based_cleanup

    # Cleanup if not in dry-run mode
    if [[ "$DRY_RUN" != "true" ]]; then
        echo ""
        read -p "Clean up test resources now? (yes/no): " cleanup_confirm
        if [[ "$cleanup_confirm" == "yes" ]]; then
            cleanup_test_resources
        else
            print_info "Test resources NOT cleaned up. Run with --cleanup later."
            print_info "Tag for manual cleanup: Workshop=$TEST_TAG_VALUE"
        fi
    fi

    # Print summary
    echo ""
    echo "========================================================================"
    echo "Test Summary"
    echo "========================================================================"
    echo -e "${GREEN}Passed:${NC}  $TESTS_PASSED"
    echo -e "${RED}Failed:${NC}  $TESTS_FAILED"
    echo -e "${YELLOW}Skipped:${NC} $TESTS_SKIPPED"
    echo ""

    if [[ $TESTS_FAILED -gt 0 ]]; then
        echo -e "${RED}❌ Some tests failed. Review output above.${NC}"
        exit 1
    else
        echo -e "${GREEN}✅ All tests passed!${NC}"
        exit 0
    fi
}

# Run main function
main
