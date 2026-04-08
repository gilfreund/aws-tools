# integration_helper.bash — shared setup for integration tests
# These tests require a real AWS account with valid credentials.
# Set the following environment variables before running:
#
#   IT_TAG_KEY        EC2 tag key to filter test instances (default: Name)
#   IT_TAG_VALUE      EC2 tag value pattern for test instances (default: ectools-test-*)
#   IT_INSTANCE_TYPE  Instance type to use for launch tests (default: t3.micro)
#   IT_PROJECT        Project tag value (default: ectools-integration-test)
#   IT_SSH_KEY        Path to SSH private key for ecConnect tests
#   IT_SSH_USER       SSH username (default: ec2-user)
#   IT_REGION         AWS region to use (default: from AWS config)
#
# Run with:
#   bats tests/integration_*.bats
#
# Skip individual tests by setting:
#   SKIP_LAUNCH_TESTS=1   skip tests that launch instances (incur cost)
#   SKIP_CONNECT_TESTS=1  skip tests that require a running instance

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

# Do NOT prepend mocks — use the real aws CLI
export IT_TAG_KEY="${IT_TAG_KEY:-Name}"
export IT_TAG_VALUE="${IT_TAG_VALUE:-ectools-test-*}"
export IT_INSTANCE_TYPE="${IT_INSTANCE_TYPE:-t3.micro}"
export IT_PROJECT="${IT_PROJECT:-ectools-integration-test}"
export IT_SSH_USER="${IT_SSH_USER:-ec2-user}"

# Verify AWS credentials are available before any test runs
check_aws_credentials() {
  if ! aws sts get-caller-identity --output text &>/dev/null; then
    echo "ERROR: No valid AWS credentials. Configure via 'aws configure' or set AWS_PROFILE."
    return 1
  fi
}

# Skip a test with a clear message if a condition is not met
skip_if() {
  local reason="$1"
  local condition="$2"
  if eval "$condition"; then
    skip "$reason"
  fi
}

# Get the account ID from the current credentials
get_account_id() {
  aws sts get-caller-identity --query Account --output text 2>/dev/null
}

# Get the current region
get_region() {
  aws configure get region 2>/dev/null || echo "${AWS_DEFAULT_REGION:-us-east-1}"
}

# List running instances matching IT_TAG_KEY/IT_TAG_VALUE
list_test_instances() {
  aws --output text ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
              "Name=tag:$IT_TAG_KEY,Values=$IT_TAG_VALUE" \
    --query "Reservations[*].Instances[*].[InstanceId,InstanceType,PrivateIpAddress,Tags[?Key=='Name']|[0].Value]"
}

# Terminate an instance by ID and wait for it to stop
terminate_instance() {
  local instanceId="$1"
  echo "Terminating $instanceId..."
  aws ec2 terminate-instances --instance-ids "$instanceId" --output text &>/dev/null
  aws ec2 wait instance-terminated --instance-ids "$instanceId"
  echo "Terminated $instanceId"
}

# Wait for an instance to reach running state
wait_for_running() {
  local instanceId="$1"
  aws ec2 wait instance-running --instance-ids "$instanceId"
}
