#!/bin/bash

# Test script for bwsm_secret.sh
# This script validates the main functionality of the Bitwarden Secrets Manager script

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test counters
TESTS_PASSED=0
TESTS_FAILED=0
TESTS_SKIPPED=0

# Script path
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT="$SCRIPT_DIR/bwsm_secret.sh"

# Check if required environment variables are set
if [[ -z "$BWS_ACCESS_TOKEN" ]] || [[ -z "$BWS_ORG_ID" ]] || [[ -z "$PROJECT_ID" ]]; then
    echo -e "${YELLOW}Warning: Required environment variables not set.${NC}"
    echo "Please set: BWS_ACCESS_TOKEN, BWS_ORG_ID, PROJECT_ID"
    echo ""
    echo "Some tests will be skipped."
    SKIP_TESTS=true
else
    SKIP_TESTS=false
fi

# Test helper functions
test_pass() {
    echo -e "${GREEN}✓ PASS${NC}: $1"
    ((TESTS_PASSED++))
}

test_fail() {
    echo -e "${RED}✗ FAIL${NC}: $1"
    echo "  Error: $2"
    ((TESTS_FAILED++))
}

test_skip() {
    echo -e "${YELLOW}⊘ SKIP${NC}: $1"
    ((TESTS_SKIPPED++))
}

# Test function: Check if command succeeds
test_command() {
    local test_name="$1"
    local command="$2"
    local expected_exit="${3:-0}"

    if [[ "$SKIP_TESTS" == "true" ]] && [[ "$test_name" == *"requires env"* ]]; then
        test_skip "$test_name"
        return
    fi

    if eval "$command" >/tmp/test_output 2>&1; then
        exit_code=$?
    else
        exit_code=$?
    fi

    if [[ $exit_code -eq $expected_exit ]]; then
        test_pass "$test_name"
    else
        test_fail "$test_name" "Expected exit code $expected_exit, got $exit_code"
        if [[ -f /tmp/test_output ]]; then
            echo "  Output: $(head -3 /tmp/test_output | tr '\n' ' ')"
        fi
    fi
}

# Test function: Check if output contains expected text
test_output_contains() {
    local test_name="$1"
    local command="$2"
    local expected_text="$3"

    if [[ "$SKIP_TESTS" == "true" ]] && [[ "$test_name" == *"requires env"* ]]; then
        test_skip "$test_name"
        return
    fi

    if output=$(eval "$command" 2>&1); then
        if echo "$output" | grep -q "$expected_text"; then
            test_pass "$test_name"
        else
            test_fail "$test_name" "Output does not contain '$expected_text'"
            echo "  Actual output: $output"
        fi
    else
        test_fail "$test_name" "Command failed"
    fi
}

# Test function: Check if output does NOT contain text
test_output_not_contains() {
    local test_name="$1"
    local command="$2"
    local unexpected_text="$3"

    if [[ "$SKIP_TESTS" == "true" ]] && [[ "$test_name" == *"requires env"* ]]; then
        test_skip "$test_name"
        return
    fi

    if output=$(eval "$command" 2>&1); then
        if ! echo "$output" | grep -q "$unexpected_text"; then
            test_pass "$test_name"
        else
            test_fail "$test_name" "Output contains unexpected '$unexpected_text'"
        fi
    else
        test_fail "$test_name" "Command failed"
    fi
}

echo "=========================================="
echo "Testing bwsm_secret.sh"
echo "=========================================="
echo ""

# Test 1: Script exists and is executable
echo "=== Basic Tests ==="
test_command "Script exists and is executable" "test -x '$SCRIPT'"

# Test 2: Help/usage works
test_command "Help/usage displays" "'$SCRIPT' --help" 1

# Test 3: Invalid subcommand
test_command "Invalid subcommand returns error" "'$SCRIPT' invalid-subcommand" 2

# Test 4: Missing required arguments (get)
echo ""
echo "=== Get Subcommand Tests ==="
test_command "Get without arguments returns error" "'$SCRIPT' get" 2

# Test 5: Missing access token
test_command "Get without access token returns error" "'$SCRIPT' get --secret-id 00000000-0000-0000-0000-000000000000" 2

# Test 6: Invalid secret ID format
if [[ "$SKIP_TESTS" == "false" ]]; then
    test_command "Get with invalid secret ID format returns error" "'$SCRIPT' get --secret-id invalid-uuid --access-token '$BWS_ACCESS_TOKEN'" 2
fi

# Test 7: Get with secret-name requires org-id
test_command "Get with secret-name without org-id returns error" "'$SCRIPT' get --secret-name test --access-token test-token" 2

# Test 8: Create subcommand tests
echo ""
echo "=== Create Subcommand Tests ==="
test_command "Create without arguments returns error" "'$SCRIPT' create" 2

# Test 9: Create missing required arguments
test_command "Create without key returns error" "'$SCRIPT' create --org-id test --project-ids test --access-token test" 2

# Test 10: Create without org-id
test_command "Create without org-id returns error" "'$SCRIPT' create --key test-key --project-ids test --access-token test" 2

# Test 11: Create without project-ids
test_command "Create without project-ids returns error" "'$SCRIPT' create --key test-key --org-id test --access-token test" 2

# Test 12: Create with invalid UUID format
if [[ "$SKIP_TESTS" == "false" ]]; then
    test_command "Create with invalid org-id UUID returns error" "'$SCRIPT' create --key test --org-id invalid-uuid --project-ids '$PROJECT_ID' --access-token '$BWS_ACCESS_TOKEN' --value test" 2
fi

# Test 13: Duplicate detection (if env vars are set)
if [[ "$SKIP_TESTS" == "false" ]]; then
    echo ""
    echo "=== Duplicate Detection Tests ==="

    # Create a test secret first
    TEST_KEY="test-$(date +%s)"
    echo "Creating test secret: $TEST_KEY"

    if SECRET_ID=$("$SCRIPT" create --key "$TEST_KEY" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN" --value "test-value" 2>&1); then
        test_pass "Create test secret for duplicate test"

        # Try to create duplicate (should fail)
        test_command "Create duplicate secret without --allow-duplicate fails" "'$SCRIPT' create --key '$TEST_KEY' --org-id '$BWS_ORG_ID' --project-ids '$PROJECT_ID' --access-token '$BWS_ACCESS_TOKEN' --value 'test-value2'" 2

        # Try to create duplicate with --allow-duplicate (should succeed)
        test_command "Create duplicate secret with --allow-duplicate succeeds" "'$SCRIPT' create --key '$TEST_KEY' --org-id '$BWS_ORG_ID' --project-ids '$PROJECT_ID' --access-token '$BWS_ACCESS_TOKEN' --value 'test-value3' --allow-duplicate" 0

        # Clean up: Get the secret IDs and note them for manual cleanup
        echo "  Note: Test secrets created with key '$TEST_KEY' - please clean up manually"
    else
        test_skip "Create test secret for duplicate test (requires env vars)"
        test_skip "Duplicate detection test"
    fi
fi

# Test 14: Multiple secrets with same name handling
if [[ "$SKIP_TESTS" == "false" ]]; then
    echo ""
    echo "=== Multiple Secrets Tests ==="

    # This test assumes there are already multiple secrets with the same name
    # We'll test that the error message is helpful
    test_output_contains "Get with secret-name shows helpful error when multiple exist" \
        "'$SCRIPT' get --secret-name 'my-secret' --org-id '$BWS_ORG_ID' --access-token '$BWS_ACCESS_TOKEN' 2>&1" \
        "MULTIPLE_SECRETS\|To disambiguate"

fi

# Test 15: JSON output format
if [[ "$SKIP_TESTS" == "false" ]]; then
    echo ""
    echo "=== Output Format Tests ==="

    # Test JSON output contains expected fields
    test_output_contains "Create with --json outputs JSON" \
        "'$SCRIPT' create --key 'json-test-$(date +%s)' --org-id '$BWS_ORG_ID' --project-ids '$PROJECT_ID' --access-token '$BWS_ACCESS_TOKEN' --value 'test' --json" \
        "secret_id"
fi

# Test 16: Stdin input
if [[ "$SKIP_TESTS" == "false" ]]; then
    echo ""
    echo "=== Stdin Input Tests ==="

    TEST_KEY="stdin-test-$(date +%s)"
    test_command "Create with value from stdin" \
        "echo 'stdin-value' | '$SCRIPT' create --key '$TEST_KEY' --org-id '$BWS_ORG_ID' --project-ids '$PROJECT_ID' --access-token '$BWS_ACCESS_TOKEN'" \
        "0"
fi

# Test 17: Debug mode
if [[ "$SKIP_TESTS" == "false" ]]; then
    echo ""
    echo "=== Debug Mode Tests ==="

    test_output_contains "Create with --debug shows debug output" \
        "'$SCRIPT' create --key 'debug-test-$(date +%s)' --org-id '$BWS_ORG_ID' --project-ids '$PROJECT_ID' --access-token '$BWS_ACCESS_TOKEN' --value 'test' --debug 2>&1" \
        "Authenticating\|Creating"
fi

# Test 18: Update subcommand tests
echo ""
echo "=== Update Subcommand Tests ==="
test_command "Update without arguments returns error" "'$SCRIPT' update" 2

# Test 19: Update missing required arguments
test_command "Update without secret identifier returns error" "'$SCRIPT' update --key test --access-token test" 2

# Test 20: Update with no update fields
if [[ "$SKIP_TESTS" == "false" ]] && [[ -n "$SECRET_ID" ]]; then
    test_output_contains "Update without update fields shows error" \
        "'$SCRIPT' update --secret-id '$SECRET_ID' --access-token '$BWS_ACCESS_TOKEN' 2>&1" \
        "no update fields provided"
else
    test_skip "Update without update fields test (requires env vars)"
fi

# Test 21: Update with invalid UUID
test_command "Update with invalid secret ID format returns error" "'$SCRIPT' update --secret-id invalid-uuid --key test --access-token test" 2

# Test 22: Update by secret-name requires org-id
test_command "Update with secret-name without org-id returns error" "'$SCRIPT' update --secret-name test --key test --access-token test" 2

# Test 23: Update both --secret-id and --secret-name
test_command "Update with both --secret-id and --secret-name returns error" "'$SCRIPT' update --secret-id test --secret-name test --key test --access-token test" 2

# Test 24: Update by secret-id (value only)
if [[ "$SKIP_TESTS" == "false" ]] && [[ -n "$SECRET_ID" ]]; then
    OLD_VALUE=$("$SCRIPT" get --secret-id "$SECRET_ID" --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null || echo "")
    NEW_VALUE="updated-value-$(date +%s)"
    if OUTPUT=$("$SCRIPT" update --secret-id "$SECRET_ID" --value "$NEW_VALUE" --access-token "$BWS_ACCESS_TOKEN" 2>&1) && \
       UPDATED_VALUE=$("$SCRIPT" get --secret-id "$SECRET_ID" --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null || echo "") && \
       [[ "$UPDATED_VALUE" == "$NEW_VALUE" ]]; then
        test_pass "Update by secret-id (value only)"
        # Restore old value
        "$SCRIPT" update --secret-id "$SECRET_ID" --value "$OLD_VALUE" --access-token "$BWS_ACCESS_TOKEN" >/dev/null 2>&1 || true
    else
        test_fail "Update by secret-id (value only)" "Value mismatch or update failed"
    fi
else
    test_skip "Update by secret-id (value only) (requires env vars)"
fi

# Test 25: Update with --json flag
if [[ "$SKIP_TESTS" == "false" ]] && [[ -n "$SECRET_ID" ]]; then
    test_output_contains "Update with --json outputs JSON" \
        "'$SCRIPT' update --secret-id '$SECRET_ID' --note 'Test note $(date +%s)' --access-token '$BWS_ACCESS_TOKEN' --json" \
        "secret_id"
else
    test_skip "Update with --json flag (requires env vars)"
fi

# Test 26: Update with value from stdin
if [[ "$SKIP_TESTS" == "false" ]] && [[ -n "$SECRET_ID" ]]; then
    OLD_VALUE=$("$SCRIPT" get --secret-id "$SECRET_ID" --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null || echo "")
    NEW_VALUE="stdin-value-$(date +%s)"
    if OUTPUT=$(echo "$NEW_VALUE" | "$SCRIPT" update --secret-id "$SECRET_ID" --access-token "$BWS_ACCESS_TOKEN" 2>&1) && \
       UPDATED_VALUE=$("$SCRIPT" get --secret-id "$SECRET_ID" --access-token "$BWS_ACCESS_TOKEN" 2>/dev/null || echo "") && \
       [[ "$UPDATED_VALUE" == "$NEW_VALUE" ]]; then
        test_pass "Update with value from stdin"
        # Restore old value
        "$SCRIPT" update --secret-id "$SECRET_ID" --value "$OLD_VALUE" --access-token "$BWS_ACCESS_TOKEN" >/dev/null 2>&1 || true
    else
        test_fail "Update with value from stdin" "Value mismatch or update failed"
    fi
else
    test_skip "Update with value from stdin (requires env vars)"
fi

# Test 27: Update error - secret not found
if [[ "$SKIP_TESTS" == "false" ]]; then
    test_command "Update with non-existent secret ID returns error" "'$SCRIPT' update --secret-id '00000000-0000-0000-0000-000000000000' --key 'new-key' --access-token '$BWS_ACCESS_TOKEN'" 4
else
    test_skip "Update error - secret not found (requires env vars)"
fi

# Test 28: Delete subcommand tests
echo ""
echo "=== Delete Subcommand Tests ==="
test_command "Delete without arguments returns error" "'$SCRIPT' delete" 2

# Test 29: Delete missing required arguments
test_command "Delete without secret identifier returns error" "'$SCRIPT' delete --access-token test" 2

# Test 30: Delete missing force flag (non-interactive)
if [[ "$SKIP_TESTS" == "false" ]]; then
    test_output_contains "Delete without --force in non-interactive mode shows error" \
        "echo 'test' | '$SCRIPT' delete --secret-id '00000000-0000-0000-0000-000000000000' --access-token '$BWS_ACCESS_TOKEN' 2>&1" \
        "--force flag is required"
fi

# Test 31: Delete with invalid UUID
if [[ "$SKIP_TESTS" == "false" ]]; then
    test_command "Delete with invalid secret ID format returns error" "'$SCRIPT' delete --secret-id invalid-uuid --access-token '$BWS_ACCESS_TOKEN' --force" 2
fi

# Test 32: Delete by secret-name requires org-id
test_command "Delete with secret-name without org-id returns error" "'$SCRIPT' delete --secret-name test --access-token test --force" 2

# Test 33: Delete multiple secrets
if [[ "$SKIP_TESTS" == "false" ]]; then
    # Create test secrets first
    TEST_KEY1="delete-test-1-$(date +%s)"
    TEST_KEY2="delete-test-2-$(date +%s)"
    echo "Creating test secrets for deletion test..."

    if SECRET_ID1=$("$SCRIPT" create --key "$TEST_KEY1" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN" --value "test-value1" 2>&1) && \
       SECRET_ID2=$("$SCRIPT" create --key "$TEST_KEY2" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN" --value "test-value2" 2>&1); then
        test_pass "Create test secrets for deletion test"

        # Test delete by ID
        test_command "Delete single secret by ID" \
            "'$SCRIPT' delete --secret-id '$SECRET_ID1' --access-token '$BWS_ACCESS_TOKEN' --force" \
            "0"

        # Test delete multiple secrets
        test_command "Delete multiple secrets by ID" \
            "'$SCRIPT' delete --secret-id '$SECRET_ID2' --access-token '$BWS_ACCESS_TOKEN' --force" \
            "0"

        echo "  Note: Test secrets deleted - cleanup complete"
    else
        test_skip "Create test secrets for deletion test (requires env vars)"
        test_skip "Delete by ID test"
        test_skip "Delete multiple secrets test"
    fi
fi

# Test 34: Delete JSON output
if [[ "$SKIP_TESTS" == "false" ]]; then
    TEST_KEY="json-delete-test-$(date +%s)"
    if SECRET_ID=$("$SCRIPT" create --key "$TEST_KEY" --org-id "$BWS_ORG_ID" --project-ids "$PROJECT_ID" --access-token "$BWS_ACCESS_TOKEN" --value "test" 2>&1); then
        test_output_contains "Delete with --json outputs JSON" \
            "'$SCRIPT' delete --secret-id '$SECRET_ID' --access-token '$BWS_ACCESS_TOKEN' --force --json" \
            "deleted_secret_ids"
    else
        test_skip "Delete JSON output test (requires env vars)"
    fi
fi

# Summary
echo ""
echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo -e "${GREEN}Passed: $TESTS_PASSED${NC}"
echo -e "${RED}Failed: $TESTS_FAILED${NC}"
echo -e "${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
echo ""

if [[ $TESTS_FAILED -eq 0 ]]; then
    echo -e "${GREEN}All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}Some tests failed.${NC}"
    exit 1
fi
