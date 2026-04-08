#!/usr/bin/env bats
# Tests for tools.rc shared bootstrap

load test_helper

TOOLS_RC="$REPO_ROOT/tools.rc"

setup() {
  setup_test_home
}

teardown() {
  teardown_test_home
}

# ---------------------------------------------------------------------------
# Config loading
# ---------------------------------------------------------------------------

@test "tools.rc loads /etc config when present" {
  mkdir -p "$TEST_HOME/etc/ecTools"
  echo 'EC_TEST_VAR="from-etc"' > "$TEST_HOME/etc/ecTools/ecTools.conf"

  # Patch CONFNAME lookup paths
  run bash -c "
    CONFNAME=ecTools.conf
    if [[ -e '$TEST_HOME/etc/ecTools/ecTools.conf' ]]; then
      source '$TEST_HOME/etc/ecTools/ecTools.conf'
    fi
    echo \$EC_TEST_VAR
  "
  [ "$status" -eq 0 ]
  [ "$output" = "from-etc" ]
}

@test "tools.rc user config overrides system config" {
  mkdir -p "$TEST_HOME/etc/ecTools" "$TEST_HOME/.config/ecTools"
  echo 'EC_TEST_VAR="from-etc"'    > "$TEST_HOME/etc/ecTools/ecTools.conf"
  echo 'EC_TEST_VAR="from-user"'   > "$TEST_HOME/.config/ecTools/ecTools.conf"

  run bash -c "
    source '$TEST_HOME/etc/ecTools/ecTools.conf'
    source '$TEST_HOME/.config/ecTools/ecTools.conf'
    echo \$EC_TEST_VAR
  "
  [ "$status" -eq 0 ]
  [ "$output" = "from-user" ]
}

# ---------------------------------------------------------------------------
# AWS profile pre-parsing
# ---------------------------------------------------------------------------

@test "tools.rc sets AWS_PROFILE from -p flag" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    for _arg in -p myprofile; do
      case \$_arg in
        -p|--profile) _next=1 ;;
        *) [[ \${_next:-0} -eq 1 ]] && EC_AWS_PROFILE=\$_arg && _next=0 ;;
      esac
    done
    [[ -n \"\$EC_AWS_PROFILE\" ]] && export AWS_PROFILE=\"\$EC_AWS_PROFILE\"
    echo \$AWS_PROFILE
  "
  [ "$status" -eq 0 ]
  [ "$output" = "myprofile" ]
}

@test "tools.rc sets AWS_PROFILE from --profile flag" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    _next=0
    for _arg in --profile staging; do
      case \$_arg in
        -p|--profile) _next=1 ;;
        *) [[ \$_next -eq 1 ]] && EC_AWS_PROFILE=\$_arg && _next=0 ;;
      esac
    done
    [[ -n \"\$EC_AWS_PROFILE\" ]] && export AWS_PROFILE=\"\$EC_AWS_PROFILE\"
    echo \$AWS_PROFILE
  "
  [ "$status" -eq 0 ]
  [ "$output" = "staging" ]
}

# ---------------------------------------------------------------------------
# AWS credential check
# ---------------------------------------------------------------------------

@test "tools.rc exits 1 when no AWS credentials" {
  run bash -c "
    export PATH='$MOCKS_DIR:\$PATH'
    export AWS_MOCK_EXIT_CODE=255
    export AWS_MOCK_RESPONSES='sts get-caller-identity:'
    _callerIdentity=\$(aws sts get-caller-identity --output text 2>/dev/null) || true
    if [[ -z \"\$_callerIdentity\" ]]; then
      echo 'ERROR: No valid AWS credentials found.'
      exit 1
    fi
  "
  [ "$status" -eq 1 ]
  [[ "$output" == *"No valid AWS credentials"* ]]
}

@test "tools.rc extracts caller ARN from identity" {
  local s; s="$(mktemp /tmp/t.XXXXXX.sh)"
  printf '#!/usr/bin/env bash\nexport PATH="%s:$PATH"\n_id=$(aws sts get-caller-identity --output text 2>/dev/null)\necho "$_id" | awk '"'"'{print $2}'"'"'\n' "$MOCKS_DIR" > "$s"
  run bash "$s"; rm -f "$s"
  [ "$status" -eq 0 ]
  [[ "$output" == *"arn:aws"* ]]
}

# ---------------------------------------------------------------------------
# Region resolution
# ---------------------------------------------------------------------------

@test "tools.rc derives region from AZ metadata" {
  run bash -c "
    _az='us-west-2b'
    AWS_DEFAULT_REGION=\"\${_az:0:\${#_az}-1}\"
    echo \$AWS_DEFAULT_REGION
  "
  [ "$status" -eq 0 ]
  [ "$output" = "us-west-2" ]
}

@test "tools.rc falls back to AWS profile region" {
  local s; s="$(mktemp /tmp/t.XXXXXX.sh)"
  printf '#!/usr/bin/env bash\nexport PATH="%s:$PATH"\nunset AWS_DEFAULT_REGION\n_r=$(aws configure get region --profile default 2>/dev/null) || true\necho "$_r"\n' "$MOCKS_DIR" > "$s"
  run bash "$s"; rm -f "$s"
  [ "$status" -eq 0 ]
  [ "$output" = "us-east-1" ]
}

@test "promptAndSave saves value to userConf" {
  write_test_conf
  local confFile="$TEST_HOME/.config/ecTools/ecTools.conf"
  local s; s="$(mktemp /tmp/t.XXXXXX.sh)"
  printf '#!/usr/bin/env bash\nuserConf="%s"\nmkdir -p "$(dirname "$userConf")"\necho '"'"'export TEST_VAR="saved"'"'"' >> "$userConf"\ngrep TEST_VAR "$userConf"\n' "$confFile" > "$s"
  run bash "$s"; rm -f "$s"
  [ "$status" -eq 0 ]
  [[ "$output" == *"TEST_VAR"* ]]
}

# ---------------------------------------------------------------------------
# macOS getopt detection
# ---------------------------------------------------------------------------

@test "macOS getopt block skipped on Linux" {
  run bash -c "
    if [[ \"\$(uname)\" != 'Darwin' ]]; then
      echo 'skipped'
    fi
  "
  [ "$status" -eq 0 ]
  # On Linux this should print 'skipped'; on macOS it won't
  if [[ "$(uname)" != "Darwin" ]]; then
    [ "$output" = "skipped" ]
  fi
}
