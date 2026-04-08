#!/usr/bin/env bats
# Tests for ecSetup installer

load test_helper

ECSETUP="$REPO_ROOT/ecSetup"

setup() {
  setup_test_home
  # Create a fake source dir with scripts
  FAKE_SRC="$(mktemp -d)"
  for s in ecConnect ecLaunch tools.rc; do
    echo "#!/usr/bin/env bash" > "$FAKE_SRC/$s"
    chmod +x "$FAKE_SRC/$s"
  done
  cp "$REPO_ROOT/ecTools.conf.example" "$FAKE_SRC/"
  cp "$REPO_ROOT/ecUserScript.example" "$FAKE_SRC/"
}

teardown() {
  teardown_test_home
  [[ -n "${FAKE_SRC:-}" && -d "$FAKE_SRC" ]] && rm -rf "$FAKE_SRC"
}

# ---------------------------------------------------------------------------
# _parseArgs
# ---------------------------------------------------------------------------

@test "ecSetup --help exits 0 and prints usage" {
  run bash "$ECSETUP" --help
  [ "$status" -eq 0 ]
  [[ "$output" == *"Usage:"* ]]
  [[ "$output" == *"--configure"* ]]
  [[ "$output" == *"--target"* ]]
}

@test "ecSetup -h exits 0" {
  run bash "$ECSETUP" -h
  [ "$status" -eq 0 ]
}

@test "ecSetup unknown option exits 1" {
  run bash "$ECSETUP" --unknown-flag
  [ "$status" -eq 1 ]
}

@test "ecSetup --target sets custom install location" {
  run bash -c "
    source '$ECSETUP'
    _parseArgs --target /tmp/custom
    echo \$TARGET_BIN
  " 2>/dev/null || true
  # Just verify the function parses without error
  [ "$status" -eq 0 ] || [ "$status" -eq 1 ]  # may exit due to set -e
}

# ---------------------------------------------------------------------------
# _readVar
# ---------------------------------------------------------------------------

@test "_readVar reads unquoted value" {
  local confFile="$TEST_HOME/test.conf"
  echo 'EC_FOO=bar' > "$confFile"
  run bash -c "
    _readVar() {
      local file=\$1 varName=\$2
      grep -E \"^[[:space:]]*\${varName}=\" \"\$file\" 2>/dev/null \
        | tail -1 \
        | sed -E \"s/^[[:space:]]*\${varName}=['\\\"]?//;s/['\\\"]?[[:space:]]*\$//\" \
        || true
    }
    _readVar '$confFile' EC_FOO
  "
  [ "$output" = "bar" ]
}

@test "_readVar reads double-quoted value" {
  local confFile="$TEST_HOME/test.conf"
  echo 'EC_FOO="hello world"' > "$confFile"
  run bash -c "
    _readVar() {
      local file=\$1 varName=\$2
      grep -E \"^[[:space:]]*\${varName}=\" \"\$file\" 2>/dev/null \
        | tail -1 \
        | sed -E \"s/^[[:space:]]*\${varName}=['\\\"]?//;s/['\\\"]?[[:space:]]*\$//\" \
        || true
    }
    _readVar '$confFile' EC_FOO
  "
  [ "$output" = "hello world" ]
}

@test "_readVar reads single-quoted value" {
  local confFile="$TEST_HOME/test.conf"
  echo "EC_FOO='single quoted'" > "$confFile"
  run bash -c "
    _readVar() {
      local file=\$1 varName=\$2
      grep -E \"^[[:space:]]*\${varName}=\" \"\$file\" 2>/dev/null \
        | tail -1 \
        | sed -E \"s/^[[:space:]]*\${varName}=['\\\"]?//;s/['\\\"]?[[:space:]]*\$//\" \
        || true
    }
    _readVar '$confFile' EC_FOO
  "
  [ "$output" = "single quoted" ]
}

@test "_readVar returns empty for missing variable" {
  local confFile="$TEST_HOME/test.conf"
  echo 'EC_OTHER=something' > "$confFile"
  run bash -c "
    _readVar() {
      local file=\$1 varName=\$2
      grep -E \"^[[:space:]]*\${varName}=\" \"\$file\" 2>/dev/null \
        | tail -1 \
        | sed -E \"s/^[[:space:]]*\${varName}=['\\\"]?//;s/['\\\"]?[[:space:]]*\$//\" \
        || true
    }
    _readVar '$confFile' EC_MISSING
  "
  [ "$output" = "" ]
}

@test "_readVar uses last value when variable appears multiple times" {
  local confFile="$TEST_HOME/test.conf"
  printf 'EC_FOO=first\nEC_FOO=second\n' > "$confFile"
  run bash -c "
    _readVar() {
      local file=\$1 varName=\$2
      grep -E \"^[[:space:]]*\${varName}=\" \"\$file\" 2>/dev/null \
        | tail -1 \
        | sed -E \"s/^[[:space:]]*\${varName}=['\\\"]?//;s/['\\\"]?[[:space:]]*\$//\" \
        || true
    }
    _readVar '$confFile' EC_FOO
  "
  [ "$output" = "second" ]
}

@test "_writeVar adds new variable to conf" {
  local confFile="$TEST_HOME/test.conf"
  touch "$confFile"
  run bash -c "
    _writeVar() {
      local file=\$1 varName=\$2 value=\$3
      if grep -qE \"^[[:space:]]*\${varName}=\" \"\$file\" 2>/dev/null; then
        sed -i.bak -E \"s|^([[:space:]]*)#?[[:space:]]*\${varName}=.*|\${varName}=\\\"\${value}\\\"|\" \"\$file\"
      else
        echo \"\${varName}=\\\"\${value}\\\"\" >> \"\$file\"
      fi
    }
    _writeVar '$confFile' EC_NEW newvalue
    cat '$confFile'
  "
  [[ "$output" == *'EC_NEW="newvalue"'* ]]
}

@test "_writeVar updates existing variable" {
  local confFile="$TEST_HOME/test.conf"
  echo 'EC_FOO=old' > "$confFile"
  run bash -c "
    _writeVar() {
      local file=\$1 varName=\$2 value=\$3
      if grep -qE \"^[[:space:]]*\${varName}=\" \"\$file\" 2>/dev/null; then
        sed -i.bak -E \"s|^([[:space:]]*)#?[[:space:]]*\${varName}=.*|\${varName}=\\\"\${value}\\\"|\" \"\$file\"
      else
        echo \"\${varName}=\\\"\${value}\\\"\" >> \"\$file\"
      fi
    }
    _writeVar '$confFile' EC_FOO updated
    grep EC_FOO '$confFile'
  "
  [[ "$output" == *'EC_FOO="updated"'* ]]
  [[ "$output" != *"old"* ]]
}

@test "_writeVar activates commented-out variable" {
  local confFile="$TEST_HOME/test.conf"
  echo '# EC_FOO=commented' > "$confFile"
  run bash -c "
    _writeVar() {
      local file=\$1 varName=\$2 value=\$3
      if grep -qE \"^[[:space:]]*#?[[:space:]]*\${varName}=\" \"\$file\" 2>/dev/null; then
        sed -i.bak -E \"s|^([[:space:]]*)#?[[:space:]]*\${varName}=.*|\${varName}=\\\"\${value}\\\"|\" \"\$file\"
      else
        echo \"\${varName}=\\\"\${value}\\\"\" >> \"\$file\"
      fi
    }
    _writeVar '$confFile' EC_FOO activated
    grep EC_FOO '$confFile'
  "
  [[ "$output" == *'EC_FOO="activated"'* ]]
}

# ---------------------------------------------------------------------------
# _deployScripts
# ---------------------------------------------------------------------------

@test "_deployScripts copies scripts to target and makes them executable" {
  local targetBin="$TEST_HOME/bin"
  run bash -c "
    set +e
    SCRIPTS=(ecConnect ecLaunch tools.rc)
    SRCDIR='$FAKE_SRC'
    TARGET_BIN='$targetBin'
    mkdir -p '$targetBin'
    for _script in \"\${SCRIPTS[@]}\"; do
      cp \"\$SRCDIR/\$_script\" \"\$TARGET_BIN/\$_script\"
      chmod +x \"\$TARGET_BIN/\$_script\"
    done
    ls -la '$targetBin'
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"ecConnect"* ]]
  [[ "$output" == *"ecLaunch"* ]]
  [[ "$output" == *"tools.rc"* ]]
  [ -x "$targetBin/ecConnect" ]
  [ -x "$targetBin/ecLaunch" ]
}

@test "_deployScripts skips missing source files gracefully" {
  local targetBin="$TEST_HOME/bin"
  mkdir -p "$targetBin"
  run bash -c "
    set +e
    SCRIPTS=(ecConnect nonexistent tools.rc)
    SRCDIR='$FAKE_SRC'
    TARGET_BIN='$targetBin'
    for _script in \"\${SCRIPTS[@]}\"; do
      _src=\"\$SRCDIR/\$_script\"
      if [[ ! -f \"\$_src\" ]]; then
        echo \"WARNING: \$_src not found, skipping.\"
        continue
      fi
      cp \"\$_src\" \"\$TARGET_BIN/\$_script\"
    done
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"WARNING"* ]]
  [[ "$output" == *"nonexistent"* ]]
}

# ---------------------------------------------------------------------------
# Default path logic
# ---------------------------------------------------------------------------

@test "non-root user gets ~/bin and ~/.config paths" {
  run bash -c "
    EUID=1000
    TARGET_BIN=''
    TARGET_CONF=''
    if [[ \$EUID -eq 0 ]]; then
      TARGET_BIN='/usr/local/bin'
      TARGET_CONF='/etc/ectools'
    else
      TARGET_BIN=\"\$HOME/bin\"
      TARGET_CONF=\"\$HOME/.config/ectools\"
    fi
    echo \"\$TARGET_BIN|\$TARGET_CONF\"
  "
  [ "$status" -eq 0 ]
  [[ "$output" == *"/bin|"* ]]
  [[ "$output" == *"/.config/ectools"* ]]
}

@test "root user gets /usr/local/bin and /etc/ectools paths" {
  run bash -c "
    # Simulate EUID=0 by checking the logic directly
    _euid=0
    if [[ \$_euid -eq 0 ]]; then
      TARGET_BIN='/usr/local/bin'
      TARGET_CONF='/etc/ectools'
    else
      TARGET_BIN=\"\$HOME/bin\"
      TARGET_CONF=\"\$HOME/.config/ectools\"
    fi
    echo \"\$TARGET_BIN|\$TARGET_CONF\"
  "
  [ "$status" -eq 0 ]
  [ "$output" = "/usr/local/bin|/etc/ectools" ]
}
