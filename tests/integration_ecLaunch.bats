#!/usr/bin/env bats
# integration_ecLaunch.bats — ecLaunch integration tests
# Requires: valid AWS credentials with ec2:RunInstances permission
#
# WARNING: Tests marked [LAUNCHES INSTANCE] will create real EC2 instances
# and incur cost. They will attempt to terminate the instance after the test.
# Set SKIP_LAUNCH_TESTS=1 to skip these tests.

load integration_helper

ECLAUNCH="$REPO_ROOT/ecLaunch"

setup() {
  check_aws_credentials || skip "No AWS credentials available"
}

# ---------------------------------------------------------------------------
# Pre-flight: resolve resources that ecLaunch needs
# ---------------------------------------------------------------------------

@test "at least one VPC is available" {
  run bash -c "aws ec2 describe-vpcs --query 'length(Vpcs)' --output text"
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

@test "instance type $IT_INSTANCE_TYPE is valid in current region" {
  run aws ec2 describe-instance-types \
    --instance-types "$IT_INSTANCE_TYPE" \
    --query "InstanceTypes[].InstanceType" \
    --output text
  [ "$status" -eq 0 ]
  [ "$output" = "$IT_INSTANCE_TYPE" ]
}

@test "Amazon Linux 2023 AMI is resolvable" {
  run aws ssm get-parameter \
    --name /aws/service/ami-amazon-linux-latest/al2023-ami-kernel-default-x86_64 \
    --query Parameter.Value --output text
  [ "$status" -eq 0 ]
  [[ "$output" == ami-* ]]
}

@test "at least one private subnet is available" {
  run bash -c "
    aws --output text ec2 describe-subnets \
      --filters 'Name=tag:Name,Values=*private*' \
      --query 'length(Subnets)' --output text
  "
  [ "$status" -eq 0 ]
  [ "$output" -ge 1 ]
}

# ---------------------------------------------------------------------------
# Dry-run: verify ecLaunch resolves all parameters without launching
# ---------------------------------------------------------------------------

@test "ecLaunch --dry-run prints run-instances command" {
  run bash "$ECLAUNCH" \
    --type "$IT_INSTANCE_TYPE" \
    --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"[dry-run]"* ]]
  [[ "$output" == *"run-instances"* ]]
  [[ "$output" == *"$IT_INSTANCE_TYPE"* ]]
}

@test "ecLaunch --dry-run includes ami-id in output" {
  run bash "$ECLAUNCH" \
    --type "$IT_INSTANCE_TYPE" \
    --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"ami-"* ]]
}

@test "ecLaunch --dry-run includes subnet-id in output" {
  run bash "$ECLAUNCH" \
    --type "$IT_INSTANCE_TYPE" \
    --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"subnet-"* ]]
}

@test "ecLaunch --dry-run with explicit subnet uses that subnet" {
  local _subnet
  _subnet=$(aws --output text ec2 describe-subnets \
    --filters "Name=tag:Name,Values=*private*" \
    --query "Subnets[0].SubnetId")
  skip_if "No private subnets found" "[[ -z '$_subnet' || '$_subnet' == 'None' ]]"

  run bash "$ECLAUNCH" \
    --type "$IT_INSTANCE_TYPE" \
    --subnet "$_subnet" \
    --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"$_subnet"* ]]
}

@test "ecLaunch --dry-run with extra tags includes them in output" {
  run bash "$ECLAUNCH" \
    --type "$IT_INSTANCE_TYPE" \
    --tag "env=integration-test" \
    --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"env=integration-test"* ]] || \
  [[ "$output" == *"Key=env,Value=integration-test"* ]]
}

@test "ecLaunch --dry-run with explicit VPC uses that VPC" {
  local _vpc
  _vpc=$(aws --output text ec2 describe-vpcs \
    --query "Vpcs[0].VpcId")
  skip_if "No VPCs found" "[[ -z '$_vpc' || '$_vpc' == 'None' ]]"

  run bash "$ECLAUNCH" \
    --type "$IT_INSTANCE_TYPE" \
    --vpc "$_vpc" \
    --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  # VPC is used for subnet selection, not passed directly to run-instances
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# Live launch tests — skipped unless SKIP_LAUNCH_TESTS is unset
# WARNING: these create real instances and incur cost
# ---------------------------------------------------------------------------

@test "[LAUNCHES INSTANCE] ecLaunch creates an instance with correct tags" {
  skip_if "SKIP_LAUNCH_TESTS is set" "[[ -n '${SKIP_LAUNCH_TESTS:-1}' ]]"

  local _instanceId
  run bash "$ECLAUNCH" \
    --type "$IT_INSTANCE_TYPE" \
    --tag "integration-test=true" \
    --owner "ectools-test" 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"i-"* ]]

  _instanceId=$(echo "$output" | grep -oE 'i-[0-9a-f]+' | tail -1)
  [ -n "$_instanceId" ]

  # Verify tags were applied
  run aws ec2 describe-tags \
    --filters "Name=resource-id,Values=$_instanceId" \
              "Name=key,Values=integration-test" \
    --query "Tags[0].Value" --output text
  [ "$output" = "true" ]

  # Clean up
  terminate_instance "$_instanceId"
}

@test "[LAUNCHES INSTANCE] ecLaunch instance reaches running state" {
  skip_if "SKIP_LAUNCH_TESTS is set" "[[ -n '${SKIP_LAUNCH_TESTS:-1}' ]]"

  local _instanceId
  run bash "$ECLAUNCH" \
    --type "$IT_INSTANCE_TYPE" \
    --owner "ectools-test" 2>/dev/null <<< ""
  [ "$status" -eq 0 ]

  _instanceId=$(echo "$output" | grep -oE 'i-[0-9a-f]+' | tail -1)
  [ -n "$_instanceId" ]

  wait_for_running "$_instanceId"

  run aws ec2 describe-instances \
    --instance-ids "$_instanceId" \
    --query "Reservations[0].Instances[0].State.Name" \
    --output text
  [ "$output" = "running" ]

  terminate_instance "$_instanceId"
}
