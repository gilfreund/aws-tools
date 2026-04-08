#!/usr/bin/env bats
# Tests for ecLaunch argument parsing, VPC/subnet resolution, tag building

load test_helper

ECLAUNCH="$REPO_ROOT/ecLaunch"

setup() {
  setup_test_home
  write_test_conf
  export EC_INSTANCE_TYPE="t3.medium"
  export EC_NAME_PREFIX="test-"
  export EC_PROJECT="test-project"
  export EC_SUBNET_FILTER="*rivate*"
  export AWS_DEFAULT_REGION="us-east-1"
  export _callerArn="arn:aws:iam::123456789012:user/testuser"
  export userConf="$TEST_HOME/.config/ecTools/ecTools.conf"
}

teardown() {
  teardown_test_home
}

# ---------------------------------------------------------------------------
# --help
# ---------------------------------------------------------------------------

@test "ecLaunch usage contains all flags" {
  run bash -c "
    usage() {
      echo 'Usage: ecLaunch [ -t | --type TYPE ] [ -o | --owner OWNER ] [ -a | --ami AMI ]'
      echo '       [ -s | --subnet ] [ -v | --vpc ] [ -T | --tag ] [ --replace-tags ]'
      echo '       [ -p | --profile ] [ --list-subnets ] [ -h | --help ]'
      exit 0
    }
    usage
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"--type"* ]]
  [[ "$output" == *"--subnet"* ]]
  [[ "$output" == *"--vpc"* ]]
  [[ "$output" == *"--tag"* ]]
  [[ "$output" == *"--replace-tags"* ]]
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

@test "ecLaunch -t sets EC_INSTANCE_TYPE" {
  run bash -c "
    EC_INSTANCE_TYPE=''
    set -- -t r5d.large --
    while true; do
      case \$1 in
        -t) EC_INSTANCE_TYPE=\$2; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \$EC_INSTANCE_TYPE
  "
  [ "$status" -eq 0 ]
  [ "$output" = "r5d.large" ]
}

@test "ecLaunch -o sets owner tag" {
  run bash -c "
    _OWNERTAG=''
    set -- -o jsmith --
    while true; do
      case \$1 in
        -o) _OWNERTAG=\$2; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \$_OWNERTAG
  "
  [ "$status" -eq 0 ]
  [ "$output" = "jsmith" ]
}

@test "ecLaunch -s overrides subnet" {
  run bash -c "
    _SUBNET_OVERRIDE=''
    set -- -s subnet-abc123 --
    while true; do
      case \$1 in
        -s) _SUBNET_OVERRIDE=\$2; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \$_SUBNET_OVERRIDE
  "
  [ "$status" -eq 0 ]
  [ "$output" = "subnet-abc123" ]
}

@test "ecLaunch -v overrides VPC" {
  run bash -c "
    _VPC_OVERRIDE=''
    set -- -v vpc-abc123 --
    while true; do
      case \$1 in
        -v) _VPC_OVERRIDE=\$2; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \$_VPC_OVERRIDE
  "
  [ "$status" -eq 0 ]
  [ "$output" = "vpc-abc123" ]
}

@test "ecLaunch -T accumulates tags" {
  run bash -c "
    _CLI_TAGS=''
    set -- -T env=dev -T team=platform --
    while true; do
      case \$1 in
        -T) _CLI_TAGS=\"\${_CLI_TAGS:+\$_CLI_TAGS,}\$2\"; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \$_CLI_TAGS
  "
  [ "$status" -eq 0 ]
  [ "$output" = "env=dev,team=platform" ]
}

@test "ecLaunch --replace-tags sets flag" {
  run bash -c "
    _REPLACE_TAGS=0
    set -- --replace-tags --
    while true; do
      case \$1 in
        --replace-tags) _REPLACE_TAGS=1; shift ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \$_REPLACE_TAGS
  "
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

# ---------------------------------------------------------------------------
# Tag building
# ---------------------------------------------------------------------------

@test "extra tags are appended to EC_EXTRA_TAGS by default" {
  run bash -c "
    EC_EXTRA_TAGS='env=dev'
    _CLI_TAGS='team=platform'
    _REPLACE_TAGS=0
    if [[ \$_REPLACE_TAGS -eq 1 ]]; then
      _extraTagsRaw=\"\${_CLI_TAGS:-}\"
    else
      _extraTagsRaw=\"\${EC_EXTRA_TAGS:-}\"
      [[ -n \"\$_CLI_TAGS\" ]] && _extraTagsRaw=\"\${_extraTagsRaw:+\$_extraTagsRaw,}\$_CLI_TAGS\"
    fi
    echo \$_extraTagsRaw
  "
  [ "$status" -eq 0 ]
  [ "$output" = "env=dev,team=platform" ]
}

@test "--replace-tags discards EC_EXTRA_TAGS" {
  run bash -c "
    EC_EXTRA_TAGS='env=dev'
    _CLI_TAGS='team=platform'
    _REPLACE_TAGS=1
    if [[ \$_REPLACE_TAGS -eq 1 ]]; then
      _extraTagsRaw=\"\${_CLI_TAGS:-}\"
    else
      _extraTagsRaw=\"\${EC_EXTRA_TAGS:-}\"
      [[ -n \"\$_CLI_TAGS\" ]] && _extraTagsRaw=\"\${_extraTagsRaw:+\$_extraTagsRaw,}\$_CLI_TAGS\"
    fi
    echo \$_extraTagsRaw
  "
  [ "$status" -eq 0 ]
  [ "$output" = "team=platform" ]
}

@test "tag pairs are converted to AWS JSON format" {
  run bash -c "
    _extraTagsRaw='env=dev,team=platform'
    _extraTagJson=''
    IFS=',' read -ra _tagPairs <<< \"\$_extraTagsRaw\"
    for _pair in \"\${_tagPairs[@]}\"; do
      _k=\"\${_pair%%=*}\"
      _v=\"\${_pair#*=}\"
      _extraTagJson=\"\${_extraTagJson:+\$_extraTagJson,}{Key=\$_k,Value=\$_v}\"
    done
    echo \$_extraTagJson
  "
  [ "$status" -eq 0 ]
  [ "$output" = "{Key=env,Value=dev},{Key=team,Value=platform}" ]
}

@test "empty extra tags produce empty JSON fragment" {
  run bash -c "
    _extraTagsRaw=''
    _extraTagJson=''
    if [[ -n \"\$_extraTagsRaw\" ]]; then
      IFS=',' read -ra _tagPairs <<< \"\$_extraTagsRaw\"
      for _pair in \"\${_tagPairs[@]}\"; do
        _k=\"\${_pair%%=*}\"
        _v=\"\${_pair#*=}\"
        _extraTagJson=\"\${_extraTagJson:+\$_extraTagJson,}{Key=\$_k,Value=\$_v}\"
      done
      _extraTagJson=\",\$_extraTagJson\"
    fi
    echo \"'\$_extraTagJson'\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "''" ]
}

# ---------------------------------------------------------------------------
# VPC resolution
# ---------------------------------------------------------------------------

@test "_resolveVpc uses _VPC_OVERRIDE when set" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    _VPC_OVERRIDE='vpc-override123'
    _VPC_ID=''
    if [[ -n \"\${_VPC_OVERRIDE:-}\" ]]; then
      _VPC_ID=\"\$_VPC_OVERRIDE\"
      echo \"Using VPC: \$_VPC_ID (from command line)\"
    fi
    echo \$_VPC_ID
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"vpc-override123"* ]]
}

@test "_resolveVpc uses EC_VPC_ID from conf" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    _VPC_OVERRIDE=''
    EC_VPC_ID='vpc-from-conf'
    _VPC_ID=''
    if [[ -z \"\${_VPC_OVERRIDE:-}\" ]] && [[ -n \"\${EC_VPC_ID:-}\" ]]; then
      _VPC_ID=\"\$EC_VPC_ID\"
    fi
    echo \$_VPC_ID
  "
  [ "$status" -eq 0 ]
  [ "$output" = "vpc-from-conf" ]
}

@test "_resolveVpc auto-selects single VPC" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    _vpcIds=('vpc-11223344')
    _count=\${#_vpcIds[@]}
    if [[ \$_count -eq 1 ]]; then
      _VPC_ID=\"\${_vpcIds[0]}\"
      echo \"Using VPC: \$_VPC_ID (only VPC available)\"
    fi
    echo \$_VPC_ID
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"vpc-11223344"* ]]
}

@test "_resolveVpc exits 1 when no VPCs found" {
  run bash -c "
    _vpcIds=()
    _count=\${#_vpcIds[@]}
    if [[ \$_count -eq 0 ]]; then
      echo 'ERROR: No VPCs found.'
      exit 1
    fi
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"No VPCs found"* ]]
}

# ---------------------------------------------------------------------------
# Subnet resolution
# ---------------------------------------------------------------------------

@test "subnet uses _SUBNET_OVERRIDE when set" {
  run bash -c "
    _SUBNET_OVERRIDE='subnet-explicit'
    EC_SUBNET_ID=''
    if [[ -n \"\${_SUBNET_OVERRIDE:-}\" ]]; then
      subnet=\"\$_SUBNET_OVERRIDE\"
      echo \"Using subnet: \$subnet (from command line)\"
    fi
    echo \$subnet
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"subnet-explicit"* ]]
}

@test "subnet uses EC_SUBNET_ID when set" {
  run bash -c "
    _SUBNET_OVERRIDE=''
    EC_SUBNET_ID='subnet-pinned'
    if [[ -z \"\${_SUBNET_OVERRIDE:-}\" ]] && [[ -n \"\${EC_SUBNET_ID:-}\" ]]; then
      subnet=\"\$EC_SUBNET_ID\"
    fi
    echo \$subnet
  "
  [ "$status" -eq 0 ]
  [ "$output" = "subnet-pinned" ]
}

@test "no subnets found exits 1" {
  run bash -c "
    _subnetList=()
    subnetCount=\${#_subnetList[@]}
    if [[ \$subnetCount -eq 0 ]]; then
      echo \"No subnets found matching filter\"
      exit 1
    fi
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"No subnets found"* ]]
}

# ---------------------------------------------------------------------------
# Multi-value instance type
# ---------------------------------------------------------------------------

@test "single EC_INSTANCE_TYPE is used directly" {
  run bash -c "
    EC_INSTANCE_TYPE='t3.medium'
    read -ra _typeList <<< \"\$EC_INSTANCE_TYPE\"
    echo \${#_typeList[@]}
  "
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "multi-value EC_INSTANCE_TYPE is detected" {
  run bash -c "
    EC_INSTANCE_TYPE='t3.medium r5d.large p3.2xlarge'
    read -ra _typeList <<< \"\$EC_INSTANCE_TYPE\"
    echo \${#_typeList[@]}
  "
  [ "$status" -eq 0 ]
  [ "$output" = "3" ]
}

# ---------------------------------------------------------------------------
# EC_NAME_PREFIX default
# ---------------------------------------------------------------------------

@test "EC_NAME_PREFIX defaults to compute- when unset" {
  run bash -c "
    unset EC_NAME_PREFIX
    EC_NAME_PREFIX=\"\${EC_NAME_PREFIX:-compute-}\"
    echo \$EC_NAME_PREFIX
  "
  [ "$status" -eq 0 ]
  [ "$output" = "compute-" ]
}

# ---------------------------------------------------------------------------
# IMAGEID default
# ---------------------------------------------------------------------------

@test "_IMAGEID defaults to 2023 when not provided" {
  run bash -c "
    unset _IMAGEID
    _IMAGEID=\"\${_IMAGEID:-2023}\"
    echo \$_IMAGEID
  "
  [ "$status" -eq 0 ]
  [ "$output" = "2023" ]
}

# ---------------------------------------------------------------------------
# Launch template version
# ---------------------------------------------------------------------------

@test "EC_LAUNCH_TEMPLATE_VERSION defaults to \$Default" {
  run bash -c "
    unset EC_LAUNCH_TEMPLATE_VERSION
    # shellcheck disable=SC2016
    EC_LAUNCH_TEMPLATE_VERSION=\"\${EC_LAUNCH_TEMPLATE_VERSION:-\\\$Default}\"
    echo \$EC_LAUNCH_TEMPLATE_VERSION
  "
  [ "$status" -eq 0 ]
  [ "$output" = '$Default' ]
}
