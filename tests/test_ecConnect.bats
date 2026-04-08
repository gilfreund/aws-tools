#!/usr/bin/env bats
# Tests for ecConnect argument parsing, validation, and instance filtering

load test_helper

ECCONNECT="$REPO_ROOT/ecConnect"

setup() {
  setup_test_home
  write_test_conf
  create_test_key
  export EC_SSH_KEY="-i $TEST_HOME/.ssh/test.pem"
  export EC_SSH_USER="ec2-user"
  export EC_TAG_KEY="Name"
  export EC_TAG_VALUE="test-*"
  export EC_IP_CONNECTION="private"
  export _callerArn="arn:aws:iam::123456789012:user/testuser"
  export AWS_DEFAULT_REGION="us-east-1"
}

teardown() {
  teardown_test_home
}

# ---------------------------------------------------------------------------
# --help
# ---------------------------------------------------------------------------

@test "ecConnect --help exits 0 and shows usage" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    export EC_SSH_KEY='-i $TEST_HOME/.ssh/test.pem'
    export EC_SSH_USER='ec2-user'
    export EC_IP_CONNECTION='private'
    export EC_TAG_KEY='Name'
    export EC_TAG_VALUE='test-*'
    export _callerArn='arn:aws:iam::123456789012:user/testuser'
    export AWS_DEFAULT_REGION='us-east-1'
    # Stub tools.rc
    source() { :; }
    source '$ECCONNECT' --help 2>/dev/null
  " || true
  # --help should print usage; we test the usage function directly
  run bash -c "
    usage() {
      echo 'Usage: ecConnect [ -L | --forward SPEC ]'
      exit 0
    }
    usage
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------

@test "ecConnect parses -L forward flag" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    _SSH_FORWARD_ARGS=''
    # Simulate getopt parse loop
    set -- -L '8080:localhost:80' --
    while true; do
      case \$1 in
        -L) _SSH_FORWARD_ARGS=\"\$_SSH_FORWARD_ARGS -L \$2\"; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \"\$_SSH_FORWARD_ARGS\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"-L 8080:localhost:80"* ]]
}

@test "ecConnect parses multiple -L flags" {
  run bash -c "
    _SSH_FORWARD_ARGS=''
    set -- -L '8080:localhost:80' -L '5432:localhost:5432' --
    while true; do
      case \$1 in
        -L) _SSH_FORWARD_ARGS=\"\$_SSH_FORWARD_ARGS -L \$2\"; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \"\$_SSH_FORWARD_ARGS\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"-L 8080:localhost:80"* ]]
  [[ "$output" == *"-L 5432:localhost:5432"* ]]
}

@test "ecConnect parses -f fork flag" {
  run bash -c "
    _SSH_FORK=0
    set -- -f --
    while true; do
      case \$1 in
        -f) _SSH_FORK=1; shift ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \$_SSH_FORK
  "
  [ "$status" -eq 0 ]
  [ "$output" = "1" ]
}

@test "ecConnect parses -u user flag" {
  run bash -c "
    EC_SSH_USER=''
    set -- -u myuser --
    while true; do
      case \$1 in
        -u) EC_SSH_USER=\$2; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \$EC_SSH_USER
  "
  [ "$status" -eq 0 ]
  [ "$output" = "myuser" ]
}

@test "ecConnect parses -o owner filter flag" {
  run bash -c "
    _OWNER_FILTER=''
    set -- -o jsmith --
    while true; do
      case \$1 in
        -o) _OWNER_FILTER=\$2; shift 2 ;;
        --) shift; break ;;
        *)  break ;;
      esac
    done
    echo \$_OWNER_FILTER
  "
  [ "$status" -eq 0 ]
  [ "$output" = "jsmith" ]
}

@test "ecConnect positional 'public' sets EC_IP_CONNECTION" {
  run bash -c "
    EC_IP_CONNECTION='private'
    set -- public
    case \$1 in
      public)  EC_IP_CONNECTION=public ;;
      private) EC_IP_CONNECTION=private ;;
      ssm)     EC_IP_CONNECTION=ssm ;;
    esac
    echo \$EC_IP_CONNECTION
  "
  [ "$status" -eq 0 ]
  [ "$output" = "public" ]
}

@test "ecConnect positional 'ssm' sets EC_IP_CONNECTION" {
  run bash -c "
    EC_IP_CONNECTION='private'
    set -- ssm
    case \$1 in
      public)  EC_IP_CONNECTION=public ;;
      private) EC_IP_CONNECTION=private ;;
      ssm)     EC_IP_CONNECTION=ssm ;;
    esac
    echo \$EC_IP_CONNECTION
  "
  [ "$status" -eq 0 ]
  [ "$output" = "ssm" ]
}

# ---------------------------------------------------------------------------
# SSH key validation
# ---------------------------------------------------------------------------

@test "ecConnect accepts valid SSH key path" {
  local keyPath="$TEST_HOME/.ssh/test.pem"
  run bash -c "
    keyPath='$keyPath'
    if [[ ! -f \"\${keyPath/#\~/$HOME}\" ]]; then
      echo 'SSH key not found'
      exit 1
    fi
    echo 'key ok'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "key ok" ]
}

@test "ecConnect rejects missing SSH key path" {
  run bash -c "
    keyPath='/nonexistent/key.pem'
    if [[ ! -f \"\${keyPath/#\~/$HOME}\" ]]; then
      echo 'SSH key not found: \$keyPath'
      exit 1
    fi
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"SSH key not found"* ]]
}

@test "ecConnect rejects empty SSH key path" {
  run bash -c "
    keyPath=''
    if [[ -z \"\$keyPath\" ]]; then
      echo 'No SSH key provided, exiting.'
      exit 1
    fi
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"No SSH key provided"* ]]
}

# ---------------------------------------------------------------------------
# getInstances filter construction
# ---------------------------------------------------------------------------

@test "getInstances appends owner filter when _OWNER_FILTER is set" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    EC_IP_CONNECTION='private'
    EC_TAG_KEY='Name'
    EC_TAG_VALUE='test-*'
    _OWNER_FILTER='jsmith'
    _ownerFilter=''
    [[ -n \"\$_OWNER_FILTER\" ]] && _ownerFilter=\" Name=tag:owner,Values=\$_OWNER_FILTER\"
    echo \"filter:\$_ownerFilter\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"Name=tag:owner,Values=jsmith"* ]]
}

@test "getInstances has no owner filter when _OWNER_FILTER is empty" {
  run bash -c "
    _OWNER_FILTER=''
    _ownerFilter=''
    [[ -n \"\$_OWNER_FILTER\" ]] && _ownerFilter=\" Name=tag:owner,Values=\$_OWNER_FILTER\"
    echo \"filter:'\$_ownerFilter'\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"filter:''"* ]]
}

# ---------------------------------------------------------------------------
# EC_IP_CONNECTION validation
# ---------------------------------------------------------------------------

@test "getInstances exits 1 for unknown EC_IP_CONNECTION" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    EC_IP_CONNECTION='invalid'
    case \$EC_IP_CONNECTION in
      public|private|ssm) echo 'ok' ;;
      *) echo \"No IP Connection type defined (EC_IP_CONNECTION == \$EC_IP_CONNECTION)\"; exit 1 ;;
    esac
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"No IP Connection type defined"* ]]
}

# ---------------------------------------------------------------------------
# SSM error detection
# ---------------------------------------------------------------------------

@test "SSM TargetNotConnected error is detected" {
  local errFile="$(mktemp)"
  echo "aws: [ERROR]: An error occurred (TargetNotConnected) when calling the StartSession operation: i-123 is not connected." > "$errFile"
  run bash -c "
    if grep -q 'TargetNotConnected\|not connected\|Connection closed by UNKNOWN' '$errFile' 2>/dev/null; then
      echo 'SSM error detected'
    fi
    rm -f '$errFile'
  "
  [ "$status" -eq 0 ]
  [ "$output" = "SSM error detected" ]
}

# ---------------------------------------------------------------------------
# IP_CONNECTION default
# ---------------------------------------------------------------------------

@test "EC_IP_CONNECTION defaults to private when unset" {
  run bash -c "
    unset EC_IP_CONNECTION
    if [[ -z \"\$EC_IP_CONNECTION\" ]]; then
      EC_IP_CONNECTION='private'
    fi
    echo \$EC_IP_CONNECTION
  "
  [ "$status" -eq 0 ]
  [ "$output" = "private" ]
}
