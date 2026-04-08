#!/usr/bin/env bash
# Run integration tests against a real AWS account.
# Requires valid AWS credentials in the environment.
#
# Usage:
#   ./tests/run_integration_tests.sh
#
# Optional environment variables:
#   IT_TAG_KEY        EC2 tag key to filter test instances (default: Name)
#   IT_TAG_VALUE      EC2 tag value pattern (default: ectools-test-*)
#   IT_INSTANCE_TYPE  Instance type for launch tests (default: t3.micro)
#   IT_PROJECT        Project tag value (default: ectools-integration-test)
#   IT_SSH_KEY        Path to SSH private key for ecConnect tests
#   IT_SSH_USER       SSH username (default: ec2-user)
#   SKIP_LAUNCH_TESTS Set to 1 to skip tests that launch instances (default: 1)
#   SKIP_CONNECT_TESTS Set to 1 to skip tests that require a running instance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if ! command -v bats &>/dev/null; then
  echo "bats-core is required. Install with: brew install bats-core  OR  apt install bats"
  exit 1
fi

if ! aws sts get-caller-identity --output text &>/dev/null; then
  echo "ERROR: No valid AWS credentials found."
  echo "Configure via 'aws configure', 'aws sso login', or set AWS_PROFILE."
  exit 1
fi

echo "Running ecTools integration tests..."
echo "Account: $(aws sts get-caller-identity --query Account --output text)"
echo "Region:  $(aws configure get region 2>/dev/null || echo "${AWS_DEFAULT_REGION:-unknown}")"
echo "Profile: ${AWS_PROFILE:-default}"
echo ""
echo "SKIP_LAUNCH_TESTS=${SKIP_LAUNCH_TESTS:-1}  (set to 0 to enable instance launch tests)"
echo ""

bats --tap "$SCRIPT_DIR"/integration_*.bats
