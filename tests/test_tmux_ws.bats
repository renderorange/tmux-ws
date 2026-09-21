#!/usr/bin/env bats
# tests/test_tmux_ws.bats — tests for tmux-ws

setup() {
    export TEST_CONFIG_DIR="$BATS_TEST_TMPDIR/tmux-ws-config"
    export TMUX_WS_CONFIG="$TEST_CONFIG_DIR"
    export TMUX_WS_BIN="$BATS_TEST_DIRNAME/../bin/tmux-ws"

    # Ensure tmux-ws is on PATH for `run`
    export PATH="$BATS_TEST_DIRNAME/../bin:$PATH"

    # Create test directories that configs reference
    mkdir -p "$BATS_TEST_TMPDIR/test-workspace-dir"
    mkdir -p "$BATS_TEST_TMPDIR/myapp-dir"

    # Create test config structure
    mkdir -p "$TEST_CONFIG_DIR/_templates"
    mkdir -p "$TEST_CONFIG_DIR/test-workspace/hooks"
    mkdir -p "$TEST_CONFIG_DIR/myapp/hooks"
    mkdir -p "$TEST_CONFIG_DIR/bad-format"
    mkdir -p "$TEST_CONFIG_DIR/no-template/hooks"
    mkdir -p "$TEST_CONFIG_DIR/fail-hook/hooks"
    cat > "$TEST_CONFIG_DIR/_templates/node.conf" <<EOF
DEFAULT_DIR="$BATS_TEST_TMPDIR/node-default"
WINDOWS=(
    "editor::vim"
    "server::npm start"
    "shell::"
)
EOF

    # Default template
    cat > "$TEST_CONFIG_DIR/_templates/default.conf" <<EOF
DEFAULT_DIR="$BATS_TEST_TMPDIR"
WINDOWS=(
    "shell::"
)
EOF

    # test-workspace (no inheritance)
    cat > "$TEST_CONFIG_DIR/test-workspace/workspace.conf" <<EOF
DEFAULT_DIR="$BATS_TEST_TMPDIR/test-workspace-dir"
WINDOWS=(
    "editor::vim"
    "server::npm start"
    "shell::"
)
EOF

    # myapp (inherits from default, overrides DEFAULT_DIR)
    cat > "$TEST_CONFIG_DIR/myapp/workspace.conf" <<EOF
_BASE="default"
DEFAULT_DIR="$BATS_TEST_TMPDIR/myapp-dir"
WINDOWS=(
    "code::vim ."
    "terminal::"
)
EOF

    # bad-format: window entry missing colons
    cat > "$TEST_CONFIG_DIR/bad-format/workspace.conf" <<EOF
DEFAULT_DIR="$BATS_TEST_TMPDIR"
WINDOWS=(
    "editor"
)
EOF

    # no-template: _BASE set to nonexistent template
    cat > "$TEST_CONFIG_DIR/no-template/workspace.conf" <<EOF
_BASE="nonexistent"
DEFAULT_DIR="$BATS_TEST_TMPDIR"
WINDOWS=(
    "shell::"
)
EOF

    # Hooks for test-workspace
    cat > "$TEST_CONFIG_DIR/test-workspace/hooks/pre-create.sh" <<'EOF'
#!/bin/bash
echo "pre-hook ran" > "${TMUX_WS_CONFIG}/_hook_ran"
EOF

    cat > "$TEST_CONFIG_DIR/test-workspace/hooks/post-create.sh" <<'EOF'
#!/bin/bash
echo "post-hook ran" > "${TMUX_WS_CONFIG}/_hook_ran_post"
EOF

    # fail-hook workspace
    cat > "$TEST_CONFIG_DIR/fail-hook/workspace.conf" <<EOF
DEFAULT_DIR="$BATS_TEST_TMPDIR"
WINDOWS=(
    "shell::"
)
EOF
    cat > "$TEST_CONFIG_DIR/fail-hook/hooks/pre-create.sh" <<'EOF'
#!/bin/bash
echo "this hook fails" >&2
exit 1
EOF

    # Clean up any leftover sessions
    tmux kill-session -t test-workspace 2>/dev/null || true
    tmux kill-session -t myapp 2>/dev/null || true
    tmux kill-session -t bad-format 2>/dev/null || true
    tmux kill-session -t no-template 2>/dev/null || true
    tmux kill-session -t fail-hook 2>/dev/null || true
    tmux kill-session -t test-attach 2>/dev/null || true
}

teardown() {
    tmux kill-session -t test-workspace 2>/dev/null || true
    tmux kill-session -t myapp 2>/dev/null || true
    tmux kill-session -t bad-format 2>/dev/null || true
    tmux kill-session -t no-template 2>/dev/null || true
    tmux kill-session -t fail-hook 2>/dev/null || true
    tmux kill-session -t test-attach 2>/dev/null || true
    rm -rf "$TEST_CONFIG_DIR"
    rm -rf "$BATS_TEST_TMPDIR/test-workspace-dir"
    rm -rf "$BATS_TEST_TMPDIR/myapp-dir"
}

# --- Help & Version ---

@test "help shows usage" {
    run tmux-ws help
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Usage"* ]]
}

@test "no args shows usage" {
    run tmux-ws
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Usage"* ]]
}

@test "unknown command fails" {
    run tmux-ws bogus
    [ "$status" -eq 1 ]
    [[ "${output}" == *"Unknown command"* ]]
}

@test "version flag works" {
    run tmux-ws version
    [ "$status" -eq 0 ]
    [[ "${output}" == *"tmux-ws"* ]]
    [[ "${output}" == *"0."* ]]
}

@test "short version flag works" {
    run tmux-ws -v
    [ "$status" -eq 0 ]
    [[ "${output}" == *"0."* ]]
}

# --- List ---

@test "list shows available workspaces" {
    run tmux-ws list
    [ "$status" -eq 0 ]
    [[ "${output}" == *"test-workspace"* ]]
    [[ "${output}" == *"myapp"* ]]
}

@test "list shows running indicator" {
    tmux new-session -d -s test-workspace
    run tmux-ws list
    [ "$status" -eq 0 ]
    [[ "${output}" == *"running"* ]]
}

@test "list shows running sessions section" {
    run tmux-ws list
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Running sessions"* ]]
}

# --- Create ---

@test "create requires a name" {
    run tmux-ws create
    [ "$status" -eq 1 ]
    [[ "${output}" == *"Workspace name required"* ]]
}

@test "create fails for nonexistent workspace" {
    run tmux-ws create nonexistent --detach
    [ "$status" -eq 1 ]
    [[ "${output}" == *"not found"* ]]
}

@test "create builds workspace from config" {
    run tmux-ws create test-workspace --detach
    [ "$status" -eq 0 ]
    [[ "${output}" == *"created with 3 windows"* ]]

    run tmux has-session -t test-workspace
    [ "$status" -eq 0 ]

    run tmux list-windows -t test-workspace -F "#{window_name}"
    [[ "${output}" == *"editor"* ]]
    [[ "${output}" == *"server"* ]]
    [[ "${output}" == *"shell"* ]]
}

@test "create runs pre-create hook" {
    run tmux-ws create test-workspace --detach
    [ "$status" -eq 0 ]
    [ -f "$TEST_CONFIG_DIR/_hook_ran" ]
}

@test "create runs post-create hook" {
    run tmux-ws create test-workspace --detach
    [ "$status" -eq 0 ]
    [ -f "$TEST_CONFIG_DIR/_hook_ran_post" ]
}

@test "create with inheritance" {
    run tmux-ws create myapp --detach
    [ "$status" -eq 0 ]
    [[ "${output}" == *"created with 2 windows"* ]]

    run tmux list-windows -t myapp -F "#{window_name}"
    [[ "${output}" == *"code"* ]]
    [[ "${output}" == *"terminal"* ]]
}

@test "create --force kills existing session" {
    tmux new-session -d -s test-workspace
    run tmux-ws create test-workspace --detach --force
    [ "$status" -eq 0 ]
    [[ "${output}" == *"Killing existing session"* ]]
}

@test "create reattaches to existing session without --force" {
    tmux new-session -d -s test-workspace
    run tmux-ws create test-workspace --detach
    [ "$status" -eq 0 ]
    [[ "${output}" == *"already exists"* ]]
}

# --- Add ---

@test "add requires a name" {
    run tmux-ws add
    [ "$status" -eq 1 ]
    [[ "${output}" == *"Workspace name required"* ]]
}

@test "add scaffolds config from default template" {
    run tmux-ws add new-project
    [ "$status" -eq 0 ]
    [[ "${output}" == *"scaffolded"* ]]

    [ -f "$TEST_CONFIG_DIR/new-project/workspace.conf" ]
    [ -d "$TEST_CONFIG_DIR/new-project/hooks" ]
    [ -f "$TEST_CONFIG_DIR/new-project/hooks/pre-create.sh" ]
    [ -f "$TEST_CONFIG_DIR/new-project/hooks/post-create.sh" ]
}

@test "add substitutes DEFAULT_DIR when dir arg given" {
    run tmux-ws add new-project /tmp/custom-dir
    [ "$status" -eq 0 ]

    grep -qF 'DEFAULT_DIR="/tmp/custom-dir"' "$TEST_CONFIG_DIR/new-project/workspace.conf"
}

@test "add with --template uses specified template" {
    run tmux-ws add node-project --template node
    [ "$status" -eq 0 ]

    [ -f "$TEST_CONFIG_DIR/node-project/workspace.conf" ]
    grep -qF 'npm start' "$TEST_CONFIG_DIR/node-project/workspace.conf"
}

@test "add fails if config already exists" {
    run tmux-ws add test-workspace
    [ "$status" -eq 1 ]
    [[ "${output}" == *"already exists"* ]]
}

@test "add fails for nonexistent template" {
    run tmux-ws add new-project --template bogus
    [ "$status" -eq 1 ]
    [[ "${output}" == *"not found"* ]]
}

@test "add warns if dir arg does not exist" {
    run tmux-ws add new-project /nonexistent/path
    [ "$status" -eq 0 ]
    [[ "${output}" == *"does not exist"* ]]
}

# --- Validation ---

@test "create fails for malformed window entry" {
    run tmux-ws create bad-format --detach
    [ "$status" -eq 1 ]
    [[ "${output}" == *"invalid format"* ]]
}

@test "create fails for missing _BASE template" {
    run tmux-ws create no-template --detach
    [ "$status" -eq 1 ]
    [[ "${output}" == *"not found"* ]]
}

@test "create fails when hook fails" {
    run tmux-ws create fail-hook --detach
    [ "$status" -eq 1 ]
    [[ "${output}" == *"hook failed"* ]]
}

# --- Kill ---

@test "kill requires a name" {
    run tmux-ws kill
    [ "$status" -eq 1 ]
    [[ "${output}" == *"Workspace name required"* ]]
}

@test "kill removes running session" {
    tmux new-session -d -s test-workspace
    run tmux-ws kill test-workspace
    [ "$status" -eq 0 ]
    [[ "${output}" == *"killed"* ]]

    run tmux has-session -t test-workspace
    [ "$status" -eq 1 ]
}

@test "kill warns for non-running session" {
    run tmux-ws kill test-workspace
    [ "$status" -eq 0 ]
    [[ "${output}" == *"not running"* ]]
}

# --- Attach ---

@test "attach requires a name" {
    run tmux-ws attach
    [ "$status" -eq 1 ]
    [[ "${output}" == *"Workspace name required"* ]]
}

@test "attach fails for nonexistent session" {
    run tmux-ws attach nonexistent
    [ "$status" -eq 1 ]
    [[ "${output}" == *"not running"* ]]
}

@test "attach passes validation for running session" {
    tmux new-session -d -s test-attach
    # tmux attach requires a tty, so we can't test the actual attach.
    # Verify the session exists (would pass the has-session check).
    run tmux has-session -t test-attach
    [ "$status" -eq 0 ]
}

# --- Edit ---

@test "edit requires a name" {
    run tmux-ws edit
    [ "$status" -eq 1 ]
    [[ "${output}" == *"Workspace name required"* ]]
}

@test "edit fails for nonexistent workspace" {
    run tmux-ws edit nonexistent
    [ "$status" -eq 1 ]
    [[ "${output}" == *"not found"* ]]
}

# --- Init ---

@test "init creates config directory" {
    rm -rf "$TEST_CONFIG_DIR"
    run tmux-ws init
    [ "$status" -eq 0 ]
    [ -d "$TEST_CONFIG_DIR/_templates" ]
    [ -d "$TEST_CONFIG_DIR/_examples/hooks" ]
    [ -f "$TEST_CONFIG_DIR/_templates/default.conf" ]
    [ -f "$TEST_CONFIG_DIR/_examples/workspace.conf" ]
}

@test "init warns if config already exists" {
    run tmux-ws init
    [ "$status" -eq 0 ]
    [[ "${output}" == *"already exists"* ]]
}

# --- TPM Install ---

setup_mock_bin() {
    mkdir -p "$BATS_TEST_TMPDIR/fake-bin"
    cat > "$BATS_TEST_TMPDIR/fake-bin/tmux" <<'EOF'
#!/bin/bash
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/fake-bin/tmux"

    cat > "$BATS_TEST_TMPDIR/fake-bin/git" <<'EOF'
#!/bin/bash
if [[ "$1" == "clone" ]]; then
    mkdir -p "$3"
    exit 0
fi
exit 0
EOF
    chmod +x "$BATS_TEST_TMPDIR/fake-bin/git"
}

@test "install clones TPM" {
    setup_mock_bin
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    run bash -c "export HOME='$HOME'; export TMUX_WS_CONFIG='$HOME/.config/tmux-ws'; PATH='$BATS_TEST_TMPDIR/fake-bin:$PATH' bash '$BATS_TEST_DIRNAME/../install.sh'"
    [ "$status" -eq 0 ]
    [ -d "$HOME/.tmux/plugins/tpm" ]
}

@test "install patches .tmux.conf" {
    setup_mock_bin
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    run bash -c "export HOME='$HOME'; export TMUX_WS_CONFIG='$HOME/.config/tmux-ws'; PATH='$BATS_TEST_TMPDIR/fake-bin:$PATH' bash '$BATS_TEST_DIRNAME/../install.sh'"
    [ "$status" -eq 0 ]
    grep -qF "tmux-plugins/tpm" "$HOME/.tmux.conf"
    grep -qF "tmux-resurrect" "$HOME/.tmux.conf"
    grep -qF "tmux-continuum" "$HOME/.tmux.conf"
    grep -qF "continuum-restore" "$HOME/.tmux.conf"
}

@test "install is idempotent" {
    setup_mock_bin
    export HOME="$BATS_TEST_TMPDIR/home"
    mkdir -p "$HOME"
    # Run twice
    bash -c "export HOME='$HOME'; export TMUX_WS_CONFIG='$HOME/.config/tmux-ws'; PATH='$BATS_TEST_TMPDIR/fake-bin:$PATH' bash '$BATS_TEST_DIRNAME/../install.sh'" >/dev/null 2>&1
    run bash -c "export HOME='$HOME'; export TMUX_WS_CONFIG='$HOME/.config/tmux-ws'; PATH='$BATS_TEST_TMPDIR/fake-bin:$PATH' bash '$BATS_TEST_DIRNAME/../install.sh'"
    [ "$status" -eq 0 ]
    # Count plugin declarations — should be exactly 1
    local count
    count=$(grep -cF "tmux-plugins/tpm" "$HOME/.tmux.conf")
    [ "$count" -eq 1 ]
}
