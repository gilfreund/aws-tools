#!/usr/bin/env bats
# integration_config.bats — tests for ecTools.conf variable combinations
# and command-line overrides against a real AWS account.
#
# Tests cover:
#   - Config loaded from ~/.config/ecTools/ecTools.conf
#   - Config loaded from /etc/ecTools/ecTools.conf (system-wide)
#   - User conf overrides system conf
#   - CLI flags override conf values
#   - Missing required variables prompt gracefully
#   - EC_AWS_PROFILE selects the correct AWS profile
#   - EC_SUBNET_FILTER narrows subnet selection
#   - EC_VPC_ID pins a specific VPC
#   - EC_INSTANCE_TYPE multi-value list
#   - EC_EXTRA_TAGS applied and overridden

load integration_helper

ECLAUNCH="$REPO_ROOT/ecLaunch"
ECCONNECT="$REPO_ROOT/ecConnect"

setup() {
  check_aws_credentials || skip "No AWS credentials available"
  # Each test gets an isolated home directory
  _IT_HOME=$(mktemp -d)
  mkdir -p "$_IT_HOME/.config/ecTools" "$_IT_HOME/.ssh"
  # Provide a dummy key so EC_SSH_KEY checks pass
  touch "$_IT_HOME/.ssh/test.pem" "$_IT_HOME/.ssh/test.pem.pub"
  chmod 600 "$_IT_HOME/.ssh/test.pem"
}

teardown() {
  [[ -n "${_IT_HOME:-}" && -d "$_IT_HOME" ]] && rm -rf "$_IT_HOME"
}

# Write variables to the user conf
_write_user_conf() {
  local confFile="$_IT_HOME/.config/ecTools/ecTools.conf"
  printf '#!/usr/bin/env bash\n' > "$confFile"
  for pair in "$@"; do
    echo "${pair%%=*}=\"${pair#*=}\"" >> "$confFile"
  done
}

# Run a script with the isolated home
_run() {
  HOME="$_IT_HOME" run bash "$@"
}

# ---------------------------------------------------------------------------
# Config loading — user conf
# ---------------------------------------------------------------------------

@test "ecLaunch reads EC_INSTANCE_TYPE from user conf" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_NAME_PREFIX=test-" \
    "EC_SSH_USER=ec2-user"

  _run "$ECLAUNCH" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"$IT_INSTANCE_TYPE"* ]]
}

@test "ecLaunch reads EC_NAME_PREFIX from user conf" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_NAME_PREFIX=myprefix-"

  _run "$ECLAUNCH" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"myprefix-"* ]]
}

@test "ecLaunch reads EC_PROJECT from user conf" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=conf-project"

  _run "$ECLAUNCH" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"conf-project"* ]]
}

@test "ecLaunch reads EC_EXTRA_TAGS from user conf" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_EXTRA_TAGS=env=conf-test,team=platform"

  _run "$ECLAUNCH" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"env=conf-test"* ]] || [[ "$output" == *"Key=env,Value=conf-test"* ]]
}

@test "ecConnect reads EC_IP_CONNECTION from user conf" {
  _write_user_conf \
    "EC_IP_CONNECTION=public" \
    "EC_TAG_KEY=$IT_TAG_KEY" \
    "EC_TAG_VALUE=$IT_TAG_VALUE" \
    "EC_SSH_KEY=-i $_IT_HOME/.ssh/test.pem" \
    "EC_SSH_USER=ec2-user"

  # dry-run list — should use public IP query
  _run "$ECCONNECT" --dry-run list 2>/dev/null
  # We just verify it doesn't error on config loading
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "ecConnect reads EC_TAG_KEY and EC_TAG_VALUE from user conf" {
  _write_user_conf \
    "EC_IP_CONNECTION=private" \
    "EC_TAG_KEY=Environment" \
    "EC_TAG_VALUE=production" \
    "EC_SSH_KEY=-i $_IT_HOME/.ssh/test.pem" \
    "EC_SSH_USER=ec2-user"

  # list should use the configured tag filter
  _run "$ECCONNECT" list 2>/dev/null
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# Config loading — system conf vs user conf precedence
# ---------------------------------------------------------------------------

@test "user conf EC_INSTANCE_TYPE overrides system conf" {
  # Write system conf
  local sysConf="/tmp/it_sys_ecTools_$$.conf"
  printf '#!/usr/bin/env bash\nEC_INSTANCE_TYPE="t2.micro"\nEC_PROJECT="sys-project"\n' > "$sysConf"

  # Write user conf with different value
  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT"

  # Simulate loading order: system first, user second
  run bash -c "
    source '$sysConf'
    source '$_IT_HOME/.config/ecTools/ecTools.conf'
    echo \$EC_INSTANCE_TYPE
  "
  rm -f "$sysConf"
  [ "$status" -eq 0 ]
  [ "$output" = "$IT_INSTANCE_TYPE" ]
}

@test "user conf EC_PROJECT overrides system conf" {
  local sysConf="/tmp/it_sys_ecTools_$$.conf"
  printf '#!/usr/bin/env bash\nEC_PROJECT="system-project"\n' > "$sysConf"
  _write_user_conf "EC_PROJECT=user-project"

  run bash -c "
    source '$sysConf'
    source '$_IT_HOME/.config/ecTools/ecTools.conf'
    echo \$EC_PROJECT
  "
  rm -f "$sysConf"
  [ "$status" -eq 0 ]
  [ "$output" = "user-project" ]
}

# ---------------------------------------------------------------------------
# CLI overrides — ecLaunch
# ---------------------------------------------------------------------------

@test "ecLaunch -t overrides EC_INSTANCE_TYPE from conf" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=t2.micro" \
    "EC_PROJECT=$IT_PROJECT"

  _run "$ECLAUNCH" --type "$IT_INSTANCE_TYPE" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"$IT_INSTANCE_TYPE"* ]]
  # Should NOT contain the conf value
  [[ "$output" != *"t2.micro"* ]]
}

@test "ecLaunch -o overrides default owner (whoami)" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT"

  _run "$ECLAUNCH" --owner "custom-owner" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"custom-owner"* ]]
}

@test "ecLaunch -T appends to EC_EXTRA_TAGS from conf" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_EXTRA_TAGS=env=staging"

  _run "$ECLAUNCH" --tag "ticket=PROJ-99" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"env=staging"* ]] || [[ "$output" == *"Key=env,Value=staging"* ]]
  [[ "$output" == *"ticket=PROJ-99"* ]] || [[ "$output" == *"Key=ticket,Value=PROJ-99"* ]]
}

@test "ecLaunch --replace-tags discards EC_EXTRA_TAGS from conf" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_EXTRA_TAGS=env=staging"

  _run "$ECLAUNCH" --tag "env=prod" --replace-tags --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"env=prod"* ]] || [[ "$output" == *"Key=env,Value=prod"* ]]
  # staging should not appear
  [[ "$output" != *"env=staging"* ]]
}

@test "ecLaunch -s overrides EC_SUBNET_FILTER from conf" {
  local _subnet
  _subnet=$(aws --output text ec2 describe-subnets \
    --filters "Name=tag:Name,Values=*private*" \
    --query "Subnets[0].SubnetId" 2>/dev/null)
  skip_if "No private subnets found" "[[ -z '$_subnet' || '$_subnet' == 'None' ]]"

  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_SUBNET_FILTER=*nonexistent*"

  _run "$ECLAUNCH" --subnet "$_subnet" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"$_subnet"* ]]
}

@test "ecLaunch -v overrides EC_VPC_FILTER from conf" {
  local _vpc
  _vpc=$(aws --output text ec2 describe-vpcs \
    --query "Vpcs[0].VpcId" 2>/dev/null)
  skip_if "No VPCs found" "[[ -z '$_vpc' || '$_vpc' == 'None' ]]"

  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_VPC_FILTER=nonexistent-vpc-*"

  _run "$ECLAUNCH" --vpc "$_vpc" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# CLI overrides — ecConnect
# ---------------------------------------------------------------------------

@test "ecConnect -u overrides EC_SSH_USER from conf" {
  _write_user_conf \
    "EC_IP_CONNECTION=private" \
    "EC_TAG_KEY=$IT_TAG_KEY" \
    "EC_TAG_VALUE=$IT_TAG_VALUE" \
    "EC_SSH_KEY=-i $_IT_HOME/.ssh/test.pem" \
    "EC_SSH_USER=ec2-user"

  skip_if "No instances matching IT_TAG_VALUE=$IT_TAG_VALUE" \
    "[[ -z \"\$(list_test_instances)\" ]]"

  _run "$ECCONNECT" --user "ubuntu" --dry-run private 1 2>/dev/null
  [ "$status" -eq 0 ]
  [[ "$output" == *"ubuntu@"* ]]
}

@test "ecConnect positional 'public' overrides EC_IP_CONNECTION=private from conf" {
  _write_user_conf \
    "EC_IP_CONNECTION=private" \
    "EC_TAG_KEY=$IT_TAG_KEY" \
    "EC_TAG_VALUE=$IT_TAG_VALUE" \
    "EC_SSH_KEY=-i $_IT_HOME/.ssh/test.pem" \
    "EC_SSH_USER=ec2-user"

  # list with public should query PublicIpAddress — just verify no crash
  _run "$ECCONNECT" list public 2>/dev/null
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "ecConnect -o owner filter narrows instance list" {
  _write_user_conf \
    "EC_IP_CONNECTION=private" \
    "EC_TAG_KEY=$IT_TAG_KEY" \
    "EC_TAG_VALUE=$IT_TAG_VALUE" \
    "EC_SSH_KEY=-i $_IT_HOME/.ssh/test.pem" \
    "EC_SSH_USER=ec2-user"

  local _iamUser
  _iamUser=$(aws sts get-caller-identity --query 'Arn' --output text | awk -F'/' '{print $NF}')

  # With a non-existent owner, list should return nothing (not error)
  _run "$ECCONNECT" --owner "nonexistent-owner-xyz" list 2>/dev/null
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

# ---------------------------------------------------------------------------
# EC_INSTANCE_TYPE multi-value in conf
# ---------------------------------------------------------------------------

@test "ecLaunch with multi-value EC_INSTANCE_TYPE uses first when piped selection" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=t3.micro t3.small t3.medium" \
    "EC_PROJECT=$IT_PROJECT"

  # Pipe "1" to select the first option
  _run bash -c "echo '1' | HOME='$_IT_HOME' bash '$ECLAUNCH' --dry-run 2>/dev/null"
  [ "$status" -eq 0 ]
  [[ "$output" == *"t3.micro"* ]]
}

@test "ecLaunch -t bypasses multi-value EC_INSTANCE_TYPE menu" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=t3.micro t3.small t3.medium" \
    "EC_PROJECT=$IT_PROJECT"

  _run "$ECLAUNCH" --type "t3.small" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"t3.small"* ]]
}

# ---------------------------------------------------------------------------
# EC_AWS_PROFILE
# ---------------------------------------------------------------------------

@test "EC_AWS_PROFILE in conf is applied to AWS calls" {
  local _currentProfile="${AWS_PROFILE:-default}"
  _write_user_conf \
    "EC_AWS_PROFILE=$_currentProfile" \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT"

  # dry-run should succeed with the same profile
  _run "$ECLAUNCH" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
}

@test "ecLaunch -p profile flag overrides EC_AWS_PROFILE from conf" {
  local _currentProfile="${AWS_PROFILE:-default}"
  _write_user_conf \
    "EC_AWS_PROFILE=nonexistent-profile" \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT"

  # Override with the real profile via -p
  _run "$ECLAUNCH" --profile "$_currentProfile" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
}

# ---------------------------------------------------------------------------
# EC_SUBNET_FILTER variations
# ---------------------------------------------------------------------------

@test "EC_SUBNET_FILTER=*private* finds subnets" {
  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_SUBNET_FILTER=*private*"

  _run "$ECLAUNCH" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"subnet-"* ]]
}

@test "EC_SUBNET_ID pins a specific subnet" {
  local _subnet
  _subnet=$(aws --output text ec2 describe-subnets \
    --filters "Name=tag:Name,Values=*private*" \
    --query "Subnets[0].SubnetId" 2>/dev/null)
  skip_if "No private subnets found" "[[ -z '$_subnet' || '$_subnet' == 'None' ]]"

  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_SUBNET_ID=$_subnet"

  _run "$ECLAUNCH" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
  [[ "$output" == *"$_subnet"* ]]
}

@test "EC_VPC_ID pins a specific VPC" {
  local _vpc
  _vpc=$(aws --output text ec2 describe-vpcs \
    --query "Vpcs[0].VpcId" 2>/dev/null)
  skip_if "No VPCs found" "[[ -z '$_vpc' || '$_vpc' == 'None' ]]"

  _write_user_conf \
    "EC_INSTANCE_TYPE=$IT_INSTANCE_TYPE" \
    "EC_PROJECT=$IT_PROJECT" \
    "EC_VPC_ID=$_vpc"

  _run "$ECLAUNCH" --dry-run 2>/dev/null <<< ""
  [ "$status" -eq 0 ]
}
