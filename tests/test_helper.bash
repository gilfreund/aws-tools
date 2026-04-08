# test_helper.bash — shared setup for all bats tests

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MOCKS_DIR="$REPO_ROOT/tests/mocks"
FIXTURES_DIR="$REPO_ROOT/tests/fixtures"

# Prepend mocks to PATH so they shadow real aws/ssh/curl
export PATH="$MOCKS_DIR:$PATH"

# Create a temp home dir per test to isolate config files
setup_test_home() {
  TEST_HOME="$(mktemp -d)"
  export HOME="$TEST_HOME"
  export userConf="$TEST_HOME/.config/aws-tools/ecTools.conf"
  mkdir -p "$TEST_HOME/.ssh" "$TEST_HOME/.config/aws-tools"
}

teardown_test_home() {
  [[ -n "${TEST_HOME:-}" && -d "$TEST_HOME" ]] && rm -rf "$TEST_HOME"
}

# Source a script's functions without executing top-level code
# Usage: source_functions <script_path>
# Works by stubbing out tools.rc and skipping top-level execution guards
source_functions() {
  local script="$1"
  # Stub tools.rc so sourcing ecConnect/ecLaunch doesn't call AWS
  export _callerArn="arn:aws:iam::123456789012:user/testuser"
  export AWS_DEFAULT_REGION="us-east-1"
  export AVAILABILITY_ZONE="us-east-1a"
  export userConf="${TEST_HOME:-$HOME}/.config/aws-tools/ecTools.conf"
  # Source only function definitions by extracting them
  bash -c "
    source() { :; }  # stub source
    $(grep -A999 '^function \|^[a-zA-Z_][a-zA-Z0-9_]*()' "$script" | head -200)
  " 2>/dev/null || true
}

# Write a minimal valid conf file
write_test_conf() {
  local confDir="${TEST_HOME}/.config/aws-tools"
  mkdir -p "$confDir"
  cat > "$confDir/ecTools.conf" << 'EOF'
EC_SSH_KEY="-i ~/.ssh/test.pem"
EC_SSH_USER="ec2-user"
EC_TAG_KEY="Name"
EC_TAG_VALUE="test-*"
EC_IP_CONNECTION="private"
EC_INSTANCE_TYPE="t3.medium"
EC_NAME_PREFIX="test-"
EC_PROJECT="test-project"
EC_SUBNET_FILTER="*rivate*"
EOF
}

# Create a fake SSH key pair
create_test_key() {
  local keyPath="${TEST_HOME}/.ssh/test.pem"
  touch "$keyPath" "${keyPath}.pub"
  chmod 600 "$keyPath"
  echo "$keyPath"
}
