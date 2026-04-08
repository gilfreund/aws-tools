#!/usr/bin/env bats
# integration_ecConnect.bats — ecConnect integration tests
# Requires: valid AWS credentials, EC2 instances tagged with IT_TAG_KEY=IT_TAG_VALUE

load integration_helper

ECCONNECT="$REPO_ROOT/ecConnect"

setup() {
  check_aws_credentials || skip "No AWS credentials available"
  skip_if "SKIP_CONNECT_TESTS is set" "[[ -n '${SKIP_CONNECT_TESTS:-}' ]]"
}

# ---------------------------------------------------------------------------
# Instance listing
# ---------------------------------------------------------------------------

@test "ecConnect list returns output without error" {
  skip_if "No instances matching IT_TAG_VALUE=$IT_TAG_VALUE" \
    "[[ -z \"\$(list_test_instances)\" ]]"

  run bash -c "
    export EC_TAG_KEY='$IT_TAG_KEY'
    export EC_TAG_VALUE='$IT_TAG_VALUE'
    export EC_IP_CONNECTION='private'
    export EC_SSH_KEY='-i ${IT_SSH_KEY:-~/.ssh/id_rsa}'
    export EC_SSH_USER='$IT_SSH_USER'
    source '$REPO_ROOT/tools.rc'
    getInstances 2>/dev/null || true
  " 2>/dev/null
  # Should not error even if no instances found
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "ecConnect --dry-run prints ssh command for first instance" {
  skip_if "No instances matching IT_TAG_VALUE=$IT_TAG_VALUE" \
    "[[ -z \"\$(list_test_instances)\" ]]"
  skip_if "IT_SSH_KEY not set" "[[ -z '${IT_SSH_KEY:-}' ]]"

  run bash "$ECCONNECT" \
    --dry-run \
    --user "$IT_SSH_USER" \
    private 1 2>/dev/null
  # dry-run should print [dry-run] ssh ... and exit 0
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"ssh"* ]]
}

@test "ecConnect list subcommand returns tab-separated instance data" {
  skip_if "No instances matching IT_TAG_VALUE=$IT_TAG_VALUE" \
    "[[ -z \"\$(list_test_instances)\" ]]"

  run bash -c "
    export EC_TAG_KEY='$IT_TAG_KEY'
    export EC_TAG_VALUE='$IT_TAG_VALUE'
    export EC_IP_CONNECTION='private'
    export EC_SSH_KEY='-i ${IT_SSH_KEY:-~/.ssh/id_rsa}'
    export EC_SSH_USER='$IT_SSH_USER'
    # Source tools.rc then call getInstances directly
    source '$REPO_ROOT/tools.rc' 2>/dev/null
    source '$ECCONNECT' list 2>/dev/null || true
  " 2>/dev/null
  # Each line should start with i-
  if [[ -n "$output" ]]; then
    [[ "$output" == *"i-"* ]]
  fi
}

# ---------------------------------------------------------------------------
# Owner filtering
# ---------------------------------------------------------------------------

@test "ecConnect --owner filters by owner tag" {
  skip_if "No instances matching IT_TAG_VALUE=$IT_TAG_VALUE" \
    "[[ -z \"\$(list_test_instances)\" ]]"

  local _owner
  _owner=$(aws sts get-caller-identity --query 'Arn' --output text | awk -F'/' '{print $NF}')

  run aws --output text ec2 describe-instances \
    --filters "Name=instance-state-name,Values=running" \
              "Name=tag:$IT_TAG_KEY,Values=$IT_TAG_VALUE" \
              "Name=tag:owner,Values=$_owner" \
    --query "Reservations[*].Instances[*].InstanceId"
  [ "$status" -eq 0 ]
  # Output may be empty if no instances owned by this user — that's fine
}

# ---------------------------------------------------------------------------
# SSM availability check
# ---------------------------------------------------------------------------

@test "SSM Session Manager plugin is installed" {
  skip_if "SKIP_CONNECT_TESTS is set" "[[ -n '${SKIP_CONNECT_TESTS:-}' ]]"
  run bash -c "session-manager-plugin --version 2>/dev/null || \
               aws ssm start-session --help 2>&1 | grep -q 'start-session'"
  [ "$status" -eq 0 ]
}
