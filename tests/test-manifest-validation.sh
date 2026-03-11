#!/usr/bin/env bash
# Test suite for MCPB manifest validation
# Requires: jq, bash 4+
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FIXTURES="$SCRIPT_DIR/fixtures"
PASS=0
FAIL=0
ERRORS=""

pass() {
	PASS=$((PASS + 1))
	printf '\033[0;32mPASS\033[0m %s\n' "$1"
}

fail() {
	FAIL=$((FAIL + 1))
	ERRORS+="  FAIL: $1 — $2\n"
	printf '\033[0;31mFAIL\033[0m %s — %s\n' "$1" "$2"
}

# ── Manifest validation function ──
# Source the canonical validation script (scripts/validate-manifest.sh)
# shellcheck source=../scripts/validate-manifest.sh
source "$SCRIPT_DIR/../scripts/validate-manifest.sh"

# ── Test cases ──

echo ""
printf '\033[1;33m=== MCPB Manifest Validation Tests ===\033[0m\n'
echo ""

# --- Valid manifests ---

echo "-- Valid manifests --"

if validate_manifest \
	"$FIXTURES/valid-manifest.json" \
	>/dev/null 2>&1; then
	pass "valid-manifest.json passes validation"
else
	fail "valid-manifest.json" \
		"should pass but failed"
fi

if validate_manifest \
	"$FIXTURES/valid-uv-manifest.json" \
	>/dev/null 2>&1; then
	pass "valid-uv-manifest.json passes validation"
else
	fail "valid-uv-manifest.json" \
		"should pass but failed"
fi

if validate_manifest \
	"$FIXTURES/valid-binary-manifest.json" \
	>/dev/null 2>&1; then
	pass "valid-binary-manifest.json passes validation"
else
	fail "valid-binary-manifest.json" \
		"should pass but failed"
fi

echo ""
echo "-- Invalid manifests --"

# --- Missing required fields ---
if validate_manifest \
	"$FIXTURES/invalid-missing-fields.json" \
	>/dev/null 2>&1; then
	fail "invalid-missing-fields.json" \
		"should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-missing-fields.json" \
		2>&1 || true)
	if echo "$output" | grep -q "Missing required field:"; then
		pass "missing fields detected correctly"
	else
		fail "invalid-missing-fields.json" \
			"wrong error type"
	fi
fi

# --- Bad semver ---
if validate_manifest \
	"$FIXTURES/invalid-bad-version.json" \
	>/dev/null 2>&1; then
	fail "invalid-bad-version.json" \
		"should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-bad-version.json" \
		2>&1 || true)
	if echo "$output" | grep -q "Invalid version"; then
		pass "invalid semver detected correctly"
	else
		fail "invalid-bad-version.json" \
			"wrong error type"
	fi
fi

# --- Bad server type ---
if validate_manifest \
	"$FIXTURES/invalid-bad-type.json" \
	>/dev/null 2>&1; then
	fail "invalid-bad-type.json" \
		"should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-bad-type.json" \
		2>&1 || true)
	if echo "$output" | grep -q "Invalid server type"; then
		pass "invalid server type detected correctly"
	else
		fail "invalid-bad-type.json" \
			"wrong error type"
	fi
fi

# --- UV with wrong manifest version ---
if validate_manifest \
	"$FIXTURES/invalid-uv-wrong-version.json" \
	>/dev/null 2>&1; then
	fail "invalid-uv-wrong-version.json" \
		"should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-uv-wrong-version.json" \
		2>&1 || true)
	if echo "$output" |
		grep -q "UV server type requires manifest_version 0.4"; then
		pass "UV version mismatch detected correctly"
	else
		fail "invalid-uv-wrong-version.json" \
			"wrong error type"
	fi
fi

# --- Duplicate tool names ---
if validate_manifest \
	"$FIXTURES/invalid-duplicate-tools.json" \
	>/dev/null 2>&1; then
	fail "invalid-duplicate-tools.json" \
		"should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-duplicate-tools.json" \
		2>&1 || true)
	if echo "$output" | grep -q "Duplicate tool"; then
		pass "duplicate tools detected correctly"
	else
		fail "invalid-duplicate-tools.json" \
			"wrong error type"
	fi
fi

# --- Bad platform ---
if validate_manifest \
	"$FIXTURES/invalid-bad-platform.json" \
	>/dev/null 2>&1; then
	fail "invalid-bad-platform.json" \
		"should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-bad-platform.json" \
		2>&1 || true)
	if echo "$output" |
		grep -q "Invalid platform"; then
		pass "invalid platform detected correctly"
	else
		fail "invalid-bad-platform.json" \
			"wrong error type"
	fi
fi

# --- Undefined config reference ---
if validate_manifest \
	"$FIXTURES/invalid-undefined-config-ref.json" \
	>/dev/null 2>&1; then
	fail "invalid-undefined-config-ref.json" \
		"should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-undefined-config-ref.json" \
		2>&1 || true)
	if echo "$output" | grep -q "user_config"; then
		pass "undefined config ref detected correctly"
	else
		fail "invalid-undefined-config-ref.json" \
			"wrong error type: $output"
	fi
fi

# --- Bad config type ---
if validate_manifest \
	"$FIXTURES/invalid-bad-config-type.json" \
	>/dev/null 2>&1; then
	fail "invalid-bad-config-type.json" \
		"should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-bad-config-type.json" \
		2>&1 || true)
	if echo "$output" |
		grep -q "Invalid user_config type"; then
		pass "invalid config type detected correctly"
	else
		fail "invalid-bad-config-type.json" \
			"wrong error type"
	fi
fi

# --- Tool missing description ---
if validate_manifest \
	"$FIXTURES/invalid-tool-missing-description.json" \
	>/dev/null 2>&1; then
	fail "invalid-tool-missing-description.json" \
		"should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-tool-missing-description.json" \
		2>&1 || true)
	if echo "$output" |
		grep -q "Tool missing name or description"; then
		pass "tool missing description detected correctly"
	else
		fail "invalid-tool-missing-description.json" \
			"wrong error type: $output"
	fi
fi

# --- JSON parse test ---
echo ""
echo "-- JSON structure tests --"

for fixture in "$FIXTURES"/*.json; do
	fname=$(basename "$fixture")
	if jq empty "$fixture" 2>/dev/null; then
		pass "$fname is valid JSON"
	else
		fail "$fname" "invalid JSON"
	fi
done

# --- Workflow YAML tests ---
echo ""
echo "-- Workflow YAML tests --"

WORKFLOW="$SCRIPT_DIR/../.github/workflows/mcp-bundle.yml"
ACTION="$SCRIPT_DIR/../action.yml"

# Check workflow file exists
if [ -f "$WORKFLOW" ]; then
	pass "mcp-bundle.yml exists"
else
	fail "mcp-bundle.yml" "file not found"
fi

# Check action.yml exists
if [ -f "$ACTION" ]; then
	pass "action.yml exists"
else
	fail "action.yml" "file not found"
fi

# Validate workflow has required inputs
if [ -f "$WORKFLOW" ]; then
	for input in \
		source-files manifest-path config-files \
		additional-artifacts node-version \
		build-command test-command bundle-name \
		upload-artifact create-release-asset \
		mcpb-version runs-on; do
		if grep -q "      ${input}:" "$WORKFLOW"; then
			pass "workflow has input: $input"
		else
			fail "workflow input" \
				"missing input: $input"
		fi
	done

	# Validate workflow has required outputs
	for output in \
		bundle-path bundle-sha256 manifest-valid; do
		if grep -q "      ${output}:" "$WORKFLOW"; then
			pass "workflow has output: $output"
		else
			fail "workflow output" \
				"missing output: $output"
		fi
	done
fi

# Check action.yml has required fields
if [ -f "$ACTION" ]; then
	for field in name description author branding; do
		if grep -q "^${field}:" "$ACTION"; then
			pass "action.yml has field: $field"
		else
			fail "action.yml" "missing field: $field"
		fi
	done
fi

# --- Shared validation script tests ---
echo ""
echo "-- Shared validation script tests --"

VALIDATE_SCRIPT="$SCRIPT_DIR/../scripts/validate-manifest.sh"
if [ -f "$VALIDATE_SCRIPT" ]; then
	pass "scripts/validate-manifest.sh exists"
	if [ -x "$VALIDATE_SCRIPT" ]; then
		pass "scripts/validate-manifest.sh is executable"
	else
		fail "scripts/validate-manifest.sh" "not executable"
	fi
	# action.yml sources the shared script via GITHUB_ACTION_PATH
	if grep -q 'source.*GITHUB_ACTION_PATH.*validate-manifest' "$ACTION"; then
		pass "action.yml sources scripts/validate-manifest.sh"
	else
		fail "action.yml" \
			"does not source scripts/validate-manifest.sh"
	fi
	# workflow has sync comment noting it mirrors the shared script
	if grep -q 'mirrors scripts/validate-manifest' "$WORKFLOW"; then
		pass "workflow validate step notes sync with shared script"
	else
		fail "workflow" \
			"missing sync comment for scripts/validate-manifest.sh"
	fi
else
	fail "scripts/validate-manifest.sh" "file not found"
fi

# --- Validation sync drift-detection tests ---
# Verify that the workflow's inline validate step and scripts/validate-manifest.sh
# stay in sync by checking that identical validation rules exist in both files.
echo ""
echo "-- Validation sync drift-detection tests --"

VALIDATE_SCRIPT="$SCRIPT_DIR/../scripts/validate-manifest.sh"

if [ -f "$VALIDATE_SCRIPT" ] && [ -f "$WORKFLOW" ]; then

	# Required fields: same set checked in both files
	# Script uses single-quotes: _check_field '.manifest_version'
	# Workflow uses single-quotes: check_field '.manifest_version'
	for field in \
		'.manifest_version' '.name' '.version' \
		'.description' '.author.name' \
		'.server.type' '.server.entry_point'; do
		in_script=$(grep -c "$field" "$VALIDATE_SCRIPT" || true)
		in_workflow=$(grep -c "$field" "$WORKFLOW" || true)
		if [ "$in_script" -ge 1 ] && [ "$in_workflow" -ge 1 ]; then
			pass "both files check required field: $field"
		elif [ "$in_script" -lt 1 ]; then
			fail "drift: required field $field" \
				"missing from scripts/validate-manifest.sh"
		else
			fail "drift: required field $field" \
				"missing from workflow validate step"
		fi
	done

	# check_field call count parity:
	# script uses _check_field, workflow uses check_field
	script_field_count=$(grep -c '_check_field ' "$VALIDATE_SCRIPT" || true)
	workflow_field_count=$(grep -c 'check_field ' "$WORKFLOW" || true)
	if [ "$script_field_count" -eq "$workflow_field_count" ]; then
		pass "check_field count matches: script=$script_field_count workflow=$workflow_field_count"
	else
		fail "drift: check_field count mismatch" \
			"script has $script_field_count, workflow has $workflow_field_count"
	fi

	# Server type list: both must list all four valid types
	for stype in node python binary uv; do
		if grep -q "$stype" "$VALIDATE_SCRIPT" &&
			grep -q "$stype" "$WORKFLOW"; then
			pass "both files list server type: $stype"
		elif ! grep -q "$stype" "$VALIDATE_SCRIPT"; then
			fail "drift: server type $stype" \
				"missing from scripts/validate-manifest.sh"
		else
			fail "drift: server type $stype" \
				"missing from workflow validate step"
		fi
	done

	# Semver validation: both must have the [0-9] regex pattern
	if grep -q '\[0-9\]' "$VALIDATE_SCRIPT" &&
		grep -q '\[0-9\]' "$WORKFLOW"; then
		pass "both files contain semver regex validation"
	elif ! grep -q '\[0-9\]' "$VALIDATE_SCRIPT"; then
		fail "drift: semver regex" \
			"missing from scripts/validate-manifest.sh"
	else
		fail "drift: semver regex" \
			"missing from workflow validate step"
	fi

	# UV manifest_version check: both must enforce uv -> 0.4
	if grep -qE 'uv.*0\.4|0\.4.*uv' "$VALIDATE_SCRIPT" &&
		grep -qE 'uv.*0\.4|0\.4.*uv' "$WORKFLOW"; then
		pass "both files enforce UV requires manifest_version 0.4"
	elif ! grep -qE 'uv.*0\.4|0\.4.*uv' "$VALIDATE_SCRIPT"; then
		fail "drift: UV version check" \
			"missing from scripts/validate-manifest.sh"
	else
		fail "drift: UV version check" \
			"missing from workflow validate step"
	fi

	# Platform validation: both must validate darwin|win32|linux
	if grep -q 'darwin.*win32\|win32.*linux' "$VALIDATE_SCRIPT" &&
		grep -q 'darwin.*win32\|win32.*linux' "$WORKFLOW"; then
		pass "both files validate platform values (darwin|win32|linux)"
	elif ! grep -q 'darwin.*win32\|win32.*linux' "$VALIDATE_SCRIPT"; then
		fail "drift: platform validation" \
			"missing from scripts/validate-manifest.sh"
	else
		fail "drift: platform validation" \
			"missing from workflow validate step"
	fi

	# user_config type validation: both must include directory|file types
	if grep -q 'directory.*file\|file.*directory' "$VALIDATE_SCRIPT" &&
		grep -q 'directory.*file\|file.*directory' "$WORKFLOW"; then
		pass "both files validate user_config types (includes directory|file)"
	elif ! grep -q 'directory.*file\|file.*directory' "$VALIDATE_SCRIPT"; then
		fail "drift: user_config type validation" \
			"missing from scripts/validate-manifest.sh"
	else
		fail "drift: user_config type validation" \
			"missing from workflow validate step"
	fi

	# Variable ref validation: both must check ${user_config.*} substitution
	if grep -q 'user_config\.' "$VALIDATE_SCRIPT" &&
		grep -q 'user_config\.' "$WORKFLOW"; then
		pass "both files validate user_config variable references"
	elif ! grep -q 'user_config\.' "$VALIDATE_SCRIPT"; then
		fail "drift: variable ref validation" \
			"missing from scripts/validate-manifest.sh"
	else
		fail "drift: variable ref validation" \
			"missing from workflow validate step"
	fi

	# Duplicate tool name check: both must use group_by to detect duplicates
	if grep -q 'group_by' "$VALIDATE_SCRIPT" &&
		grep -q 'group_by' "$WORKFLOW"; then
		pass "both files check for duplicate tool names (group_by)"
	elif ! grep -q 'group_by' "$VALIDATE_SCRIPT"; then
		fail "drift: duplicate tool check" \
			"missing from scripts/validate-manifest.sh"
	else
		fail "drift: duplicate tool check" \
			"missing from workflow validate step"
	fi

	# Tool description check: both must emit the same error message
	tool_msg='Tool missing name or description'
	if grep -q "$tool_msg" "$VALIDATE_SCRIPT" &&
		grep -q "$tool_msg" "$WORKFLOW"; then
		pass "both files check for tool missing name or description"
	elif ! grep -q "$tool_msg" "$VALIDATE_SCRIPT"; then
		fail "drift: tool description check" \
			"missing from scripts/validate-manifest.sh"
	else
		fail "drift: tool description check" \
			"missing from workflow validate step"
	fi

else
	fail "drift-detection" \
		"cannot run: validate-manifest.sh or workflow not found"
fi

# --- Plugin structure tests ---
echo ""
echo "-- Plugin structure tests --"

PLUGIN_JSON="$SCRIPT_DIR/../.claude-plugin/plugin.json"
if [ -f "$PLUGIN_JSON" ]; then
	pass ".claude-plugin/plugin.json exists"
	if jq empty "$PLUGIN_JSON" 2>/dev/null; then
		pass "plugin.json is valid JSON"
	else
		fail "plugin.json" "invalid JSON"
	fi
	PLUGIN_NAME=$(jq -r '.name // empty' "$PLUGIN_JSON")
	if [ -n "$PLUGIN_NAME" ]; then
		pass "plugin.json has name: $PLUGIN_NAME"
	else
		fail "plugin.json" "missing required name field"
	fi
else
	fail ".claude-plugin/plugin.json" "file not found"
fi

# --- Skill file tests ---
echo ""
echo "-- Skill file tests --"

SKILL="$SCRIPT_DIR/../skills/mcpb/SKILL.md"
if [ -f "$SKILL" ]; then
	pass "skills/mcpb/SKILL.md exists"

	# Check frontmatter
	if head -1 "$SKILL" | grep -q "^---"; then
		pass "skill has YAML frontmatter"
	else
		fail "skill" "missing YAML frontmatter"
	fi

	# Check required frontmatter fields
	for field in name description user_invocable; do
		if grep -q "^${field}:" "$SKILL"; then
			pass "skill has frontmatter: $field"
		else
			fail "skill frontmatter" "missing: $field"
		fi
	done

	# Check key content sections
	for section in \
		"Step 1" "Step 2" "Step 3" \
		"Step 4" "Step 5" "Step 6" "Step 7"; do
		if grep -q "$section" "$SKILL"; then
			pass "skill has section: $section"
		else
			fail "skill content" \
				"missing section: $section"
		fi
	done
else
	fail "skills/mcpb/SKILL.md" "file not found"
fi

# --- Example workflows ---
echo ""
echo "-- Example workflow tests --"

EXAMPLES="$SCRIPT_DIR/../examples"
for example in \
	minimal-caller.yml \
	standard-caller.yml \
	advanced-caller.yml \
	binary-caller.yml; do
	if [ -f "$EXAMPLES/$example" ]; then
		pass "example exists: $example"
		if grep -q "workflow_call\|uses:" \
			"$EXAMPLES/$example"; then
			pass "$example references reusable workflow"
		else
			fail "$example" \
				"no workflow reference found"
		fi
	else
		fail "example" "missing: $example"
	fi
done

# --- Review remediation tests ---
echo ""
echo "-- Review remediation tests --"

# workflow runs-on defaults to ubuntu-latest
if grep -q "default: ubuntu-latest" "$WORKFLOW"; then
	pass "workflow runs-on defaults to ubuntu-latest"
else
	fail "workflow runs-on" \
		"missing default ubuntu-latest"
fi

# workflow has .mcpbignore step
if grep -q "Apply .mcpbignore exclusions" "$WORKFLOW"; then
	pass "workflow has .mcpbignore step"
else
	fail "workflow" "missing .mcpbignore step"
fi

# action.yml reads .mcpbignore
if grep -q "mcpbignore" "$ACTION"; then
	pass "action.yml reads .mcpbignore"
else
	fail "action.yml" "missing .mcpbignore support"
fi

# action.yml entry_point is warning not error
if grep -q "::warning::Entry point" "$ACTION"; then
	pass "action.yml entry_point is warning"
else
	fail "action.yml" \
		"entry_point should be warning"
fi

# workflow entry_point is still error
if grep -q 'Entry point file not found' "$WORKFLOW"; then
	pass "workflow entry_point is still error"
else
	fail "workflow" \
		"entry_point should remain error"
fi

# ci.yml exists
CI_WORKFLOW="$SCRIPT_DIR/../.github/workflows/ci.yml"
if [ -f "$CI_WORKFLOW" ]; then
	pass "ci.yml exists"
else
	fail "ci.yml" "file not found"
fi

# ci.yml runs test suite
if [ -f "$CI_WORKFLOW" ] &&
	grep -q "test-manifest-validation" "$CI_WORKFLOW"; then
	pass "ci.yml runs test suite"
else
	fail "ci.yml" \
		"missing test-manifest-validation ref"
fi

# --- Server-type auto-include tests ---
echo ""
echo "-- Server-type auto-include tests --"

# workflow auto-includes requirements.txt for python
if grep -q 'requirements.txt.*python' "$WORKFLOW"; then
	pass "workflow auto-includes requirements.txt for python"
else
	fail "workflow" \
		"missing requirements.txt auto-include"
fi

# workflow auto-includes pyproject.toml for uv
if grep -q 'pyproject.toml.*uv' "$WORKFLOW"; then
	pass "workflow auto-includes pyproject.toml for uv"
else
	fail "workflow" \
		"missing pyproject.toml auto-include"
fi

# workflow auto-includes LICENSE for all types
if grep -q 'LICENSE.*STAGING' "$WORKFLOW"; then
	pass "workflow auto-includes LICENSE"
else
	fail "workflow" \
		"missing LICENSE auto-include"
fi

# --- New valid fixture tests ---
echo ""
echo "-- Extended valid fixture tests --"

# Python manifest
if validate_manifest \
	"$FIXTURES/valid-python-manifest.json" \
	>/dev/null 2>&1; then
	pass "valid-python-manifest.json passes validation"
else
	fail "valid-python-manifest.json" \
		"should pass but failed"
fi

# Pre-release semver (1.0.0-beta.1)
if validate_manifest \
	"$FIXTURES/valid-semver-prerelease.json" \
	>/dev/null 2>&1; then
	pass "pre-release semver 1.0.0-beta.1 passes validation"
else
	fail "valid-semver-prerelease.json" \
		"pre-release semver should pass but failed"
fi

# Build-metadata semver (1.0.0+build.42)
if validate_manifest \
	"$FIXTURES/valid-semver-buildmeta.json" \
	>/dev/null 2>&1; then
	pass "build-metadata semver 1.0.0+build.42 passes validation"
else
	fail "valid-semver-buildmeta.json" \
		"build-metadata semver should pass but failed"
fi

# No tools key at all
if validate_manifest \
	"$FIXTURES/valid-no-tools.json" \
	>/dev/null 2>&1; then
	pass "manifest with no tools key passes validation"
else
	fail "valid-no-tools.json" \
		"no tools key should pass but failed"
fi

# Empty tools array
if validate_manifest \
	"$FIXTURES/valid-empty-tools.json" \
	>/dev/null 2>&1; then
	pass "manifest with empty tools array passes validation"
else
	fail "valid-empty-tools.json" \
		"empty tools array should pass but failed"
fi

# All valid user_config types (string, number, boolean, directory, file)
if validate_manifest \
	"$FIXTURES/valid-all-config-types.json" \
	>/dev/null 2>&1; then
	pass "all valid user_config types pass validation"
else
	fail "valid-all-config-types.json" \
		"all config types should pass but failed"
fi

# Both args and env config refs defined
if validate_manifest \
	"$FIXTURES/valid-partial-config-refs.json" \
	>/dev/null 2>&1; then
	pass "config refs in both args and env pass validation"
else
	fail "valid-partial-config-refs.json" \
		"defined config refs should pass but failed"
fi

# --- Extended invalid fixture tests ---
echo ""
echo "-- Extended invalid fixture tests --"

# v-prefixed version (v1.0.0)
if validate_manifest \
	"$FIXTURES/invalid-version-with-v-prefix.json" \
	>/dev/null 2>&1; then
	fail "invalid-version-with-v-prefix.json" \
		"v-prefix version should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-version-with-v-prefix.json" \
		2>&1 || true)
	if echo "$output" | grep -q "Invalid version"; then
		pass "v-prefixed version rejected correctly"
	else
		fail "invalid-version-with-v-prefix.json" \
			"wrong error type: $output"
	fi
fi

# Empty string name (not null — jq returns empty for empty string)
if validate_manifest \
	"$FIXTURES/invalid-empty-name.json" \
	>/dev/null 2>&1; then
	fail "invalid-empty-name.json" \
		"empty name should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-empty-name.json" \
		2>&1 || true)
	if echo "$output" | grep -q "Missing required field:"; then
		pass "empty name string rejected correctly"
	else
		fail "invalid-empty-name.json" \
			"wrong error type: $output"
	fi
fi

# Multiple missing required fields at once
if validate_manifest \
	"$FIXTURES/invalid-multiple-missing-fields.json" \
	>/dev/null 2>&1; then
	fail "invalid-multiple-missing-fields.json" \
		"multiple missing fields should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-multiple-missing-fields.json" \
		2>&1 || true)
	missing_count=$(echo "$output" |
		grep -c "Missing required field:" || true)
	if [ "$missing_count" -ge 3 ]; then
		pass "multiple missing fields reported ($missing_count errors)"
	else
		fail "invalid-multiple-missing-fields.json" \
			"expected >=3 Missing required field: errors, got $missing_count"
	fi
fi

# Multiple undefined config refs in args and env
if validate_manifest \
	"$FIXTURES/invalid-multiple-config-refs.json" \
	>/dev/null 2>&1; then
	fail "invalid-multiple-config-refs.json" \
		"multiple undefined refs should fail but passed"
else
	output=$(validate_manifest \
		"$FIXTURES/invalid-multiple-config-refs.json" \
		2>&1 || true)
	ref_count=$(echo "$output" |
		grep -c "user_config" || true)
	if [ "$ref_count" -ge 2 ]; then
		pass "multiple undefined config refs reported ($ref_count errors)"
	else
		fail "invalid-multiple-config-refs.json" \
			"expected >=2 user_config errors, got $ref_count"
	fi
fi

# --- Security: eval usage ---
echo ""
echo "-- Security audit tests --"

# workflow build/test commands use bash -c (not eval)
# shellcheck disable=SC2016
if grep -q 'bash -c "\$BUILD_CMD"' "$WORKFLOW"; then
	pass "workflow build-command uses bash -c (not eval)"
else
	fail "workflow security" \
		"build-command should use bash -c not eval"
fi
# shellcheck disable=SC2016
if grep -q 'bash -c "\$TEST_CMD"' "$WORKFLOW"; then
	pass "workflow test-command uses bash -c (not eval)"
else
	fail "workflow security" \
		"test-command should use bash -c not eval"
fi

# action.yml zip excludes use bash array (not eval + string concatenation)
if grep -q 'EXCLUDE_ARGS\+=\|EXCLUDES=(' "$ACTION"; then
	pass "action.yml zip excludes use bash array (no eval injection risk)"
else
	fail "action.yml security" \
		"zip excludes should use bash array, not eval+string"
fi

# Workflow: GH_TOKEN is sourced from github.token (not a user input)
# shellcheck disable=SC2016
if grep -q 'GH_TOKEN: \${{ github.token }}' "$WORKFLOW"; then
	pass "workflow GH_TOKEN sourced from github.token (not user input)"
else
	fail "workflow security" \
		"GH_TOKEN not sourced from github.token"
fi

# action.yml: GH_TOKEN is sourced from github.token (not a user input)
# shellcheck disable=SC2016
if grep -q 'GH_TOKEN: \${{ github.token }}' "$ACTION"; then
	pass "action.yml GH_TOKEN sourced from github.token (not user input)"
else
	fail "action.yml security" \
		"GH_TOKEN not sourced from github.token"
fi

# --- Security: VERSION sanitization (prevents path injection via manifest version) ---
if grep -q "tr -cd.*VERSION\|VERSION.*tr -cd" "$WORKFLOW"; then
	pass "workflow sanitizes VERSION string before use in filename"
else
	fail "workflow security" \
		"VERSION string not sanitized (path injection risk)"
fi
if grep -q "tr -cd.*VERSION\|VERSION.*tr -cd" "$ACTION"; then
	pass "action.yml sanitizes VERSION string before use in filename"
else
	fail "action.yml security" \
		"VERSION string not sanitized (path injection risk)"
fi

# .mcpbignore pattern handling does not allow absolute paths to escape staging
if grep -q 'find.*STAGING.*-name' "$WORKFLOW"; then
	pass "workflow .mcpbignore uses find -name (confined to staging dir)"
else
	fail "workflow security" \
		".mcpbignore processing may not be confined to staging dir"
fi

# node_modules copied to staging (not skipped) for node server type
if grep -q 'node_modules.*STAGING\|cp.*node_modules.*STAGING' "$WORKFLOW" ||
	grep -q 'node_modules.*staging' "$WORKFLOW"; then
	pass "workflow copies node_modules to staging for node type"
else
	fail "workflow capability" \
		"node_modules not copied to staging"
fi

# --- Security: bundle-name path traversal prevention ---
if grep -q "tr -d '/'\|sed.*\\\\+\." "$WORKFLOW"; then
	pass "workflow sanitizes bundle-name against path traversal"
else
	fail "workflow security" \
		"bundle-name not sanitized (path traversal risk)"
fi
if grep -q "tr -d '/'\|sed.*\\\\+\." "$ACTION"; then
	pass "action.yml sanitizes bundle-name against path traversal"
else
	fail "action.yml security" \
		"bundle-name not sanitized (path traversal risk)"
fi

# --- Security: bundle-name sanitization — component-level ---
echo ""
echo "-- Bundle-name sanitization tests --"

# workflow: tr -d '/' strips forward slashes (path traversal component)
if grep -q "tr -d '/'" "$WORKFLOW"; then
	pass "workflow pack step strips '/' from bundle-name (tr -d)"
else
	fail "workflow security" \
		"workflow missing tr -d '/' in bundle-name sanitization"
fi

# workflow: sed strips leading dots (e.g. '../' after slash removal leaves '..name')
if grep -q "sed 's/\^\\\\.\\\\+//'" "$WORKFLOW" ||
	grep -q "sed 's/\^" "$WORKFLOW"; then
	pass "workflow pack step strips leading dots from bundle-name (sed)"
else
	fail "workflow security" \
		"workflow missing sed leading-dot strip in bundle-name sanitization"
fi

# workflow: sanitization is applied to BNAME before constructing BUNDLE_FILE
if grep -A2 "tr -d '/'" "$WORKFLOW" |
	grep -q 'BUNDLE_FILE\|sed'; then
	pass "workflow BNAME sanitization applied before BUNDLE_FILE construction"
else
	fail "workflow security" \
		"workflow sanitization may not precede BUNDLE_FILE construction"
fi

# action.yml: tr -d '/' strips forward slashes
if grep -q "tr -d '/'" "$ACTION"; then
	pass "action.yml pack step strips '/' from bundle-name (tr -d)"
else
	fail "action.yml security" \
		"action.yml missing tr -d '/' in bundle-name sanitization"
fi

# action.yml: sed strips leading dots
if grep -q "sed 's/\^\\\\.\\\\+//'" "$ACTION" ||
	grep -q "sed 's/\^" "$ACTION"; then
	pass "action.yml pack step strips leading dots from bundle-name (sed)"
else
	fail "action.yml security" \
		"action.yml missing sed leading-dot strip in bundle-name sanitization"
fi

# action.yml: sanitization applied before BUNDLE_FILE construction
if grep -A2 "tr -d '/'" "$ACTION" |
	grep -q 'BUNDLE_FILE\|sed'; then
	pass "action.yml BNAME sanitization applied before BUNDLE_FILE construction"
else
	fail "action.yml security" \
		"action.yml sanitization may not precede BUNDLE_FILE construction"
fi

# Functional verification: the sanitization logic works correctly in shell
# Test that tr -d '/' and sed 's/^\.\+//' together neutralize traversal inputs
_sanitize() {
	echo "$1" | tr -d '/' | sed 's/^\.\+//'
}

_test_sanitize() {
	local input="$1" expected="$2" label="$3"
	local result
	result=$(_sanitize "$input")
	if [ "$result" = "$expected" ]; then
		pass "sanitize: $label → '$result'"
	else
		fail "sanitize: $label" \
			"expected '$expected', got '$result'"
	fi
}

_test_sanitize "../../../etc/passwd" "etcpasswd" "path traversal stripped"
_test_sanitize "../../secret" "secret" "double-dot traversal stripped"
_test_sanitize "./my-bundle" "my-bundle" "leading dot-slash stripped"
_test_sanitize "...evil" "evil" "triple leading dot stripped"
_test_sanitize "my-bundle" "my-bundle" "clean name unchanged"
_test_sanitize "my/nested/bundle" "mynestedbundle" "all slashes stripped"
_test_sanitize "/abs/path" "abspath" "absolute path stripped"

# --- Workflow: mcpb-version input injection safety ---
# mcpb-version is passed as env var to shell before npm install
if grep -q 'MCPB_VER.*mcpb-version\|mcpb-version.*MCPB_VER' "$WORKFLOW"; then
	pass "workflow mcpb-version passed via env var (not inline)"
else
	fail "workflow security" \
		"mcpb-version not isolated via env var before npm install"
fi

# --- Workflow: sha256sum availability ---
# Workflow uses sha256sum (GNU coreutils - linux specific)
# This is fine on ubuntu-latest but may fail on macOS
if grep -q 'sha256sum' "$WORKFLOW"; then
	pass "workflow uses sha256sum for checksums"
fi
# action.yml must have portable sha256 fallback (sha256sum || shasum -a 256)
if grep -q 'sha256sum' "$ACTION" &&
	grep -q 'shasum' "$ACTION"; then
	pass "action.yml has portable sha256 fallback (sha256sum || shasum)"
else
	fail "action.yml capability" \
		"action.yml missing portable sha256 fallback for macOS runners"
fi

# --- Workflow: cleanup step runs on always() ---
if grep -q "if: always()" "$WORKFLOW"; then
	pass "workflow has cleanup step with always() condition"
else
	fail "workflow" \
		"missing cleanup step with always() condition"
fi

# --- Workflow: cleanup guards empty STAGING ---
if grep -q '\-n.*STAGING.*rm\|STAGING.*&&.*rm' "$WORKFLOW"; then
	pass "workflow cleanup guards empty STAGING variable"
else
	fail "workflow security" \
		"rm -rf STAGING not guarded against empty value"
fi

# --- Workflow: globstar enabled for ** patterns ---
if grep -q 'shopt -s globstar' "$WORKFLOW"; then
	pass "workflow enables globstar for ** glob expansion"
else
	fail "workflow capability" \
		"missing shopt -s globstar for ** patterns"
fi

# --- Capability: node_modules included for node type ---
if grep -q 'SERVER_TYPE.*node\|node.*SERVER_TYPE' "$WORKFLOW" &&
	grep -q 'node_modules' "$WORKFLOW"; then
	pass "workflow conditionally includes node_modules for node type"
else
	fail "workflow capability" \
		"node_modules not conditionally included for node type"
fi

# --- Capability: icon.png support ---
if grep -q '\.icon\|icon.*STAGING\|ICON' "$WORKFLOW"; then
	pass "workflow supports icon file from manifest"
else
	fail "workflow capability" \
		"workflow missing icon.png support"
fi

# --- Capability: checkout step present in reusable workflow ---
if grep -q 'actions/checkout' "$WORKFLOW"; then
	pass "reusable workflow includes checkout step"
else
	fail "workflow capability" \
		"missing checkout step"
fi

# --- Skill: security constraints documented ---
if grep -q 'No shell injection\|shell injection' "$SKILL"; then
	pass "skill documents shell injection constraint"
else
	fail "skill security" \
		"skill missing shell injection constraint"
fi

# --- Skill: stdio transport constraint documented ---
if grep -q 'stdio transport ONLY\|stdio.*ONLY' "$SKILL"; then
	pass "skill documents stdio transport constraint"
else
	fail "skill capability" \
		"skill missing stdio transport constraint"
fi

# --- Skill: stderr logging constraint documented ---
if grep -q 'stderr.*logging\|logging.*stderr' "$SKILL"; then
	pass "skill documents stderr logging constraint"
else
	fail "skill capability" \
		"skill missing stderr logging constraint"
fi

# --- Skill: idempotency constraint documented ---
if grep -q '[Ii]dempotent' "$SKILL"; then
	pass "skill documents idempotency constraint"
else
	fail "skill capability" \
		"skill missing idempotency constraint"
fi

# ── Summary ──
echo ""
printf '\033[1;33m=== Results ===\033[0m\n'
TOTAL=$((PASS + FAIL))
printf 'Total: %d  ' "$TOTAL"
printf '\033[0;32mPassed: %d\033[0m  ' "$PASS"
printf '\033[0;31mFailed: %d\033[0m\n' "$FAIL"

if [ "$FAIL" -gt 0 ]; then
	echo ""
	printf '\033[0;31mFailures:\033[0m\n'
	printf "%b" "$ERRORS"
	exit 1
fi

echo ""
printf '\033[0;32mAll tests passed!\033[0m\n'
exit 0
