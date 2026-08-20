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
}

teardown() {
    tmux kill-session -t test-workspace 2>/dev/null || true
    tmux kill-session -t myapp 2>/dev/null || true
    tmux kill-session -t bad-format 2>/dev/null || true
    tmux kill-session -t no-template 2>/dev/null || true
    tmux kill-session -t fail-hook 2>/dev/null || true
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
