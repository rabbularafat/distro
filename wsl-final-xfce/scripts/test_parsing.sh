#!/bin/bash
# Test script to verify .env parsing and enforcement logic

# 1. Setup paths
UTILS_PATH="$(pwd)/scripts/utils.sh"
TEST_ENV="$(pwd)/test_env"

source "$UTILS_PATH"

test_mode() {
    local mode=$1
    local line_ending=$2
    
    echo -e "Testing Mode: $mode with line ending: $line_ending"
    
    # Create test .env with CRLF or LF
    if [ "$line_ending" = "CRLF" ]; then
        echo -e "CLAIM_MODE=$mode\r" > "$TEST_ENV"
    else
        echo -e "CLAIM_MODE=$mode" > "$TEST_ENV"
    fi
    
    # Override ENV_FILE for load_env
    load_env_mock() {
        # Check multiple locations for .env files
        local possible_envs=("$TEST_ENV")
        
        local found_env=""
        for env_path in "${possible_envs[@]}"; do
            if [ -f "$env_path" ]; then
                found_env="$env_path"
                set -a
                eval "$(sed 's/^\xEF\xBB\xBF//; s/^#.*//; s/^[[:space:]]*$//' "$found_env" | tr -d '\r' | sed 's/^\([^=]*\)=\(.*\)$/export \1=\2/' | sed 's/=\([^\"]*$\)/="\1"/')"
                set +a
                break
            fi
        done

        local raw_mode="${CLAIM_MODE:-$MODE}"
        raw_mode="${raw_mode:-HEADLESS}"
        export CLAIM_MODE=$(echo "$raw_mode" | tr -d '\r' | sed 's/^["]//;s/["]$//;s/^['\'']//;s/['\'']$//' | tr '[:lower:]' '[:upper:]')
        export MODE="$CLAIM_MODE"
    }
    
    unset CLAIM_MODE
    unset MODE
    load_env_mock
    
    echo "Extracted CLAIM_MODE: '$CLAIM_MODE'"
    
    if [ "$CLAIM_MODE" = "$mode" ]; then
        echo "SUCCESS: Mode matched exactly."
    else
        echo "FAILURE: Mode mismatch. Detected: '$CLAIM_MODE' Expected: '$mode'"
        exit 1
    fi
}

# Run tests
test_mode "DEVELOPMENT" "CRLF"
test_mode "HEADLESS" "CRLF"
test_mode "DEVELOPMENT" "LF"
test_mode "HEADLESS" "LF"

echo "ALL TESTS PASSED!"
rm "$TEST_ENV"
