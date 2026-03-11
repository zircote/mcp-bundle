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

# action.yml must NOT define source-files, config-files, or additional-artifacts
# (those inputs are silently ignored — the action bundles the entire working dir)
if [ -f "$ACTION" ]; then
	for removed_input in source-files config-files additional-artifacts; do
		if ! grep -q "^  ${removed_input}:" "$ACTION"; then
			pass "action.yml does not expose ${removed_input} (not applicable to PWD bundling)"
		else
			fail "action.yml" \
				"${removed_input} still defined — it is silently ignored and should be removed"
		fi
	done
	# action.yml must document bundling strategy
	if grep -qi 'bundles.*working dir\|source-files.*not.*applicable\|does not accept' \
		"$ACTION"; then
		pass "action.yml documents bundling strategy"
	else
		fail "action.yml" \
			"missing comment documenting bundling strategy"
	fi
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

# --- Validation sync drift-prevention tests ---
# The workflow now sources the canonical scripts/validate-manifest.sh via a
# checkout of zircote/mcp-bundle, eliminating inline duplication entirely.
# These tests verify the architecture that prevents drift.
echo ""
echo "-- Validation sync drift-prevention tests --"

VALIDATE_SCRIPT="$SCRIPT_DIR/../scripts/validate-manifest.sh"

if [ -f "$VALIDATE_SCRIPT" ] && [ -f "$WORKFLOW" ]; then

	# Workflow checks out mcp-bundle repo for the validation script
	if grep -q 'repository: zircote/mcp-bundle' "$WORKFLOW"; then
		pass "workflow checks out mcp-bundle repo for validation script"
	else
		fail "drift-prevention" \
			"workflow missing checkout of zircote/mcp-bundle"
	fi

	# Workflow uses sparse-checkout-cone-mode: false (required for file-level sparse checkout)
	if grep -q 'sparse-checkout-cone-mode: false' "$WORKFLOW"; then
		pass "workflow uses sparse-checkout-cone-mode: false (file-level sparse checkout)"
	else
		fail "drift-prevention" \
			"missing sparse-checkout-cone-mode: false — file-level sparse checkout won't work"
	fi

	# Workflow pins sparse checkout to ref: main
	if grep -q 'ref: main' "$WORKFLOW"; then
		pass "workflow sparse checkout pinned to ref: main"
	else
		fail "drift-prevention" \
			"workflow sparse checkout missing ref: main — may pull wrong branch"
	fi

	# Workflow places checkout at .mcp-bundle-action path
	if grep -q 'path: .mcp-bundle-action' "$WORKFLOW"; then
		pass "workflow sparse-checkout placed at .mcp-bundle-action"
	else
		fail "drift-prevention" \
			"workflow missing path: .mcp-bundle-action for action script checkout"
	fi

	# Workflow sparse-checkouts only the validation script
	if grep -q 'sparse-checkout.*validate-manifest' "$WORKFLOW"; then
		pass "workflow sparse-checkouts validate-manifest.sh"
	else
		fail "drift-prevention" \
			"workflow missing sparse-checkout of validate-manifest.sh"
	fi

	# Workflow sources the checked-out script (not an inline copy)
	if grep -q 'source.*mcp-bundle-action.*validate-manifest' "$WORKFLOW"; then
		pass "workflow sources validate-manifest.sh from checked-out repo"
	else
		fail "drift-prevention" \
			"workflow does not source validate-manifest.sh from checkout"
	fi

	# Workflow sources from GITHUB_WORKSPACE (not a relative path)
	if grep -q 'GITHUB_WORKSPACE.*mcp-bundle-action' "$WORKFLOW"; then
		pass "workflow sources validate-manifest.sh via GITHUB_WORKSPACE (absolute path)"
	else
		fail "drift-prevention" \
			"workflow should reference GITHUB_WORKSPACE to ensure absolute source path"
	fi

	# Workflow calls validate_manifest function (from the sourced script)
	if grep -q 'validate_manifest' "$WORKFLOW"; then
		pass "workflow calls validate_manifest function"
	else
		fail "drift-prevention" \
			"workflow missing validate_manifest function call"
	fi

	# Workflow does NOT contain inline check_field (no duplication)
	inline_check_field=$(grep -c 'check_field ' "$WORKFLOW" || true)
	if [ "$inline_check_field" -eq 0 ]; then
		pass "workflow has no inline check_field (drift eliminated)"
	else
		fail "drift-prevention" \
			"workflow still has inline check_field ($inline_check_field occurrences)"
	fi

	# action.yml also sources the canonical script
	if grep -q 'source.*validate-manifest' "$ACTION"; then
		pass "action.yml sources scripts/validate-manifest.sh"
	else
		fail "drift-prevention" \
			"action.yml does not source validate-manifest.sh"
	fi

	# action.yml sources via GITHUB_ACTION_PATH (correct for composite actions)
	if grep -q 'GITHUB_ACTION_PATH.*validate-manifest' "$ACTION"; then
		pass "action.yml sources validate-manifest.sh via GITHUB_ACTION_PATH"
	else
		fail "drift-prevention" \
			"action.yml should source via GITHUB_ACTION_PATH, not a relative path"
	fi

	# Canonical script contains all required validation rules
	for rule in \
		'_check_field' 'Invalid server type' \
		'Invalid version' 'manifest_version 0.4' \
		'Invalid platform' 'Invalid user_config type' \
		'user_config' 'Duplicate tool name' \
		'Tool missing name or description'; do
		if grep -q "$rule" "$VALIDATE_SCRIPT"; then
			pass "canonical script contains rule: $rule"
		else
			fail "canonical script" \
				"missing validation rule: $rule"
		fi
	done

	# Functional: sourcing the canonical script makes validate_manifest callable
	# (already tested implicitly by the valid/invalid manifest tests at top,
	# but verify the function is exported after source by testing its signature)
	if bash -c "source '$VALIDATE_SCRIPT' && declare -f validate_manifest" \
		>/dev/null 2>&1; then
		pass "validate_manifest function is defined after sourcing canonical script"
	else
		fail "canonical script" \
			"validate_manifest not callable after source"
	fi

else
	fail "drift-prevention" \
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

# workflow entry_point is warning (consistent with action.yml)
if grep -q '::warning::Entry point not found' "$WORKFLOW"; then
	pass "workflow entry_point is warning"
else
	fail "workflow" \
		"entry_point should be warning"
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
if grep -q 'find.*STAGING.*-name' "$WORKFLOW" &&
	grep -q 'find.*STAGING.*-path' "$WORKFLOW"; then
	pass "workflow .mcpbignore uses find -name/-path (confined to staging dir)"
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
# Both workflow and action.yml must have portable sha256 fallback
if grep -q 'sha256sum' "$WORKFLOW" &&
	grep -q 'shasum' "$WORKFLOW"; then
	pass "workflow has portable sha256 fallback (sha256sum || shasum)"
else
	fail "workflow capability" \
		"missing portable sha256 fallback for macOS runners"
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

# workflow warns when node_modules exceeds size threshold before bundling
if grep -q 'node_modules.*MB\|NM_MB' "$WORKFLOW"; then
	pass "workflow emits node_modules size warning before bundling"
else
	fail "workflow capability" \
		"missing node_modules size warning in collect step"
fi

# warning threshold is >50MB (reasonable for production bundles)
if grep -q '50' "$WORKFLOW" && grep -q 'NM_MB\|node_modules.*MB' "$WORKFLOW"; then
	pass "workflow node_modules size warning threshold is 50MB"
else
	fail "workflow capability" \
		"node_modules size warning threshold not set to 50MB"
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

# --- .mcpbignore path-relative matching tests ---
echo ""
echo "-- .mcpbignore path-relative matching tests --"

# workflow supports path-relative patterns (find -path for patterns with /)
if grep -q '\-path.*pattern\|find.*-path' "$WORKFLOW"; then
	pass "workflow .mcpbignore supports path-relative patterns (find -path)"
else
	fail "workflow .mcpbignore" \
		"missing path-relative pattern support (find -path)"
fi

# workflow still supports simple basename patterns (find -name)
if grep -q 'find.*-name.*pattern\|find.*-name.*pat\|find.*-name.*dirpat' \
	"$WORKFLOW"; then
	pass "workflow .mcpbignore supports basename patterns (find -name)"
else
	fail "workflow .mcpbignore" \
		"missing basename pattern support (find -name)"
fi

# action.yml .mcpbignore reads patterns from file
if grep -q 'mcpbignore' "$ACTION" &&
	grep -q 'EXCLUDES' "$ACTION"; then
	pass "action.yml .mcpbignore populates EXCLUDES array"
else
	fail "action.yml .mcpbignore" \
		"missing path-relative pattern handling"
fi

# workflow handles 4-way branching: dir with path (/), basename dir (/), path file, basename
# Branch 1: trailing-slash dir with path component (e.g. build/tmp/) → -type d -path
if grep -q 'type d.*-path.*dirpat\|-type d.*-path' "$WORKFLOW"; then
	pass "workflow .mcpbignore: path-relative dir (e.g. build/tmp/) uses -type d -path"
else
	fail "workflow .mcpbignore" \
		"missing -type d -path branch for path-relative directory patterns"
fi

# Branch 2: trailing-slash basename dir (e.g. __pycache__/) → -type d -name
if grep -q 'type d.*-name.*dirpat\|-type d.*-name' "$WORKFLOW"; then
	pass "workflow .mcpbignore: basename-only dir (e.g. __pycache__/) uses -type d -name"
else
	fail "workflow .mcpbignore" \
		"missing -type d -name branch for basename-only directory patterns"
fi

# Branch 3: path-relative file (e.g. dist/debug.log) → find -path
if grep -q '\*\/\$pattern\|find.*-path.*\*\/\$' "$WORKFLOW"; then
	pass "workflow .mcpbignore: path-relative file pattern uses find -path"
else
	fail "workflow .mcpbignore" \
		"missing find -path branch for path-relative file patterns"
fi

# action.yml appends trailing * for directory patterns (zip -x 'dir/*')
if grep -q '"${pattern%/}\*"\|${pattern}*\|pattern%/}*' "$ACTION"; then
	pass "action.yml .mcpbignore: directory patterns appended with * for zip -x"
else
	fail "action.yml .mcpbignore" \
		"directory patterns should append * so zip -x 'dir/*' works"
fi

# Functional: simulate workflow 4-way branching logic in shell
_MCPB_SEMANTIC_STAGING=$(mktemp -d)
trap 'rm -rf "$_MCPB_SEMANTIC_STAGING"' EXIT

mkdir -p \
	"$_MCPB_SEMANTIC_STAGING/build/tmp" \
	"$_MCPB_SEMANTIC_STAGING/__pycache__" \
	"$_MCPB_SEMANTIC_STAGING/dist" \
	"$_MCPB_SEMANTIC_STAGING/src"
touch \
	"$_MCPB_SEMANTIC_STAGING/build/tmp/cache.bin" \
	"$_MCPB_SEMANTIC_STAGING/__pycache__/module.pyc" \
	"$_MCPB_SEMANTIC_STAGING/dist/debug.log" \
	"$_MCPB_SEMANTIC_STAGING/src/index.js" \
	"$_MCPB_SEMANTIC_STAGING/README.md"

# Simulate branch 1: path-relative dir trailing slash (build/tmp/)
_dirpat="build/tmp"
find "$_MCPB_SEMANTIC_STAGING" -type d -path "*/${_dirpat}" \
	-exec rm -rf {} + 2>/dev/null || true
if [ ! -d "$_MCPB_SEMANTIC_STAGING/build/tmp" ]; then
	pass ".mcpbignore functional: 'build/tmp/' path-relative dir removed"
else
	fail ".mcpbignore functional" \
		"'build/tmp/' path-relative dir pattern not applied"
fi

# Simulate branch 2: basename-only dir trailing slash (__pycache__/)
_dirpat="__pycache__"
find "$_MCPB_SEMANTIC_STAGING" -type d -name "${_dirpat}" \
	-exec rm -rf {} + 2>/dev/null || true
if [ ! -d "$_MCPB_SEMANTIC_STAGING/__pycache__" ]; then
	pass ".mcpbignore functional: '__pycache__/' basename dir removed"
else
	fail ".mcpbignore functional" \
		"'__pycache__/' basename dir pattern not applied"
fi

# Simulate branch 3: path-relative file (dist/debug.log)
_pat="dist/debug.log"
find "$_MCPB_SEMANTIC_STAGING" -path "*/${_pat}" \
	-exec rm -rf {} + 2>/dev/null || true
if [ ! -f "$_MCPB_SEMANTIC_STAGING/dist/debug.log" ]; then
	pass ".mcpbignore functional: 'dist/debug.log' path-relative file removed"
else
	fail ".mcpbignore functional" \
		"'dist/debug.log' path-relative file pattern not applied"
fi

# Verify non-excluded files survived
if [ -f "$_MCPB_SEMANTIC_STAGING/src/index.js" ] &&
	[ -f "$_MCPB_SEMANTIC_STAGING/README.md" ]; then
	pass ".mcpbignore functional: non-excluded files survived all patterns"
else
	fail ".mcpbignore functional" \
		"non-excluded files were incorrectly removed"
fi

# --- .mcpbignore negation pattern tests ---
echo ""
echo "-- .mcpbignore negation pattern tests --"

# workflow warns and skips negation patterns (not silently misapplied)
if grep -q 'negation pattern not supported' "$WORKFLOW"; then
	pass "workflow warns on .mcpbignore negation patterns"
else
	fail "workflow .mcpbignore" \
		"missing negation pattern warning in Apply .mcpbignore step"
fi

# action.yml warns and skips negation patterns
if grep -q 'negation pattern not supported' "$ACTION"; then
	pass "action.yml warns on .mcpbignore negation patterns"
else
	fail "action.yml .mcpbignore" \
		"missing negation pattern warning in pack step"
fi

# both emit ::warning:: annotation (not ::error::)
if grep -q '::warning::.*negation pattern' "$WORKFLOW"; then
	pass "workflow negation pattern uses ::warning:: annotation"
else
	fail "workflow .mcpbignore" \
		"negation pattern should use ::warning:: not ::error::"
fi
if grep -q '::warning::.*negation pattern' "$ACTION"; then
	pass "action.yml negation pattern uses ::warning:: annotation"
else
	fail "action.yml .mcpbignore" \
		"negation pattern should use ::warning:: not ::error::"
fi

# both continue (skip pattern) after warning — do not abort
if grep -A1 'negation pattern not supported' "$WORKFLOW" | grep -q 'continue'; then
	pass "workflow negation pattern skipped with continue (does not abort)"
else
	fail "workflow .mcpbignore" \
		"negation pattern handler should continue, not abort"
fi
if grep -A1 'negation pattern not supported' "$ACTION" | grep -q 'continue'; then
	pass "action.yml negation pattern skipped with continue (does not abort)"
else
	fail "action.yml .mcpbignore" \
		"negation pattern handler should continue, not abort"
fi

# Functional: negation pattern detection
_is_negation() { [[ "$1" == \!* ]]; }

if _is_negation "!important.log"; then
	pass "negation detection: !important.log identified as negation"
else
	fail "negation detection" "!important.log not identified as negation"
fi
if _is_negation "!dist/keep.js"; then
	pass "negation detection: !dist/keep.js identified as negation"
else
	fail "negation detection" "!dist/keep.js not identified as negation"
fi
if ! _is_negation "*.log"; then
	pass "negation detection: *.log not treated as negation"
else
	fail "negation detection" "*.log incorrectly identified as negation"
fi
if ! _is_negation "#comment"; then
	pass "negation detection: #comment not treated as negation"
else
	fail "negation detection" "#comment incorrectly identified as negation"
fi

# --- Zip fallback bundle validation tests ---
echo ""
echo "-- Zip fallback validation tests --"

# workflow validates bundle contains manifest.json after packaging
if grep -q 'unzip.*BUNDLE_FILE' "$WORKFLOW" &&
	grep -q 'manifest\.json' "$WORKFLOW"; then
	pass "workflow validates bundle structure after packaging"
else
	fail "workflow packaging" \
		"missing bundle validation after packaging"
fi

# workflow uses unzip -Z1 (list names only, no header lines — reliable grep target)
if grep -q 'unzip -Z1' "$WORKFLOW"; then
	pass "workflow uses unzip -Z1 for bundle structure check (names-only output)"
else
	fail "workflow packaging" \
		"should use unzip -Z1 for clean name listing (avoids header false positives)"
fi

# workflow checks for manifest.json at root (anchored with ^ and $)
# The workflow contains: grep -q '^manifest\.json$'
if grep -q "'\^manifest\\\\.json\\\$'" "$WORKFLOW" ||
	grep -q "\\^manifest\\.json\\\$" "$WORKFLOW"; then
	pass "workflow anchors manifest.json check to root path (^ and \$ anchors)"
else
	fail "workflow packaging" \
		"manifest.json check should be anchored to root (^manifest.json\$) to prevent subdir false positive"
fi

# workflow emits entry_point warning when missing from bundle
if grep -q '::warning::Bundle does not contain declared entry_point' "$WORKFLOW"; then
	pass "workflow emits warning when entry_point missing from bundle"
else
	fail "workflow packaging" \
		"missing ::warning:: for entry_point absent from bundle"
fi

# action.yml validates bundle structure unconditionally (not just on fallback)
if grep -q 'unzip -Z1' "$ACTION" &&
	grep -q 'manifest\.json' "$ACTION"; then
	pass "action.yml validates bundle structure unconditionally (unzip -Z1)"
else
	fail "action.yml packaging" \
		"missing unconditional bundle validation"
fi

# action.yml does NOT use USED_FALLBACK conditional (validation is always run)
if ! grep -q 'USED_FALLBACK' "$ACTION"; then
	pass "action.yml bundle validation is unconditional (USED_FALLBACK removed)"
else
	fail "action.yml packaging" \
		"USED_FALLBACK still present — validation should be unconditional"
fi

# action.yml warns if entry_point is absent from the bundle
if grep -q '::warning::Bundle does not contain declared entry_point' "$ACTION"; then
	pass "action.yml warns when entry_point missing from bundle"
else
	fail "action.yml packaging" \
		"missing ::warning:: for entry_point absent from bundle"
fi

# workflow emits ::error:: on missing manifest in bundle
if grep -q '::error::Bundle missing manifest.json' "$WORKFLOW"; then
	pass "workflow emits error annotation on invalid bundle"
else
	fail "workflow packaging" \
		"missing error annotation for invalid bundle"
fi

# action.yml emits ::error:: on missing manifest in bundle
if grep -q '::error::Bundle missing manifest.json' "$ACTION"; then
	pass "action.yml emits error annotation on invalid bundle"
else
	fail "action.yml packaging" \
		"missing error annotation for invalid bundle"
fi

# Functional: verify unzip -Z1 reliably detects manifest.json at root vs subdirectory
_MCPB_ZIP_TEST_DIR=$(mktemp -d)
trap 'rm -rf "$_MCPB_SEMANTIC_STAGING" "$_MCPB_ZIP_TEST_DIR"' EXIT

# Build a valid bundle (manifest.json at root)
mkdir -p "$_MCPB_ZIP_TEST_DIR/valid-staging/src"
printf '{"manifest_version":"0.3","name":"t","version":"1.0.0","description":"T","author":{"name":"T"},"server":{"type":"node","entry_point":"src/index.js"}}' \
	>"$_MCPB_ZIP_TEST_DIR/valid-staging/manifest.json"
touch "$_MCPB_ZIP_TEST_DIR/valid-staging/src/index.js"
_valid_bundle="$_MCPB_ZIP_TEST_DIR/valid.mcpb"
(cd "$_MCPB_ZIP_TEST_DIR/valid-staging" && zip -ry "$_valid_bundle" . -x '*.git*' >/dev/null 2>&1)

# Verify unzip -Z1 finds manifest.json at root
if unzip -Z1 "$_valid_bundle" 2>/dev/null | grep -q '^manifest\.json$'; then
	pass "functional: unzip -Z1 detects manifest.json at bundle root"
else
	fail "functional: zip fallback" \
		"unzip -Z1 failed to detect manifest.json at bundle root"
fi

# Build a bad bundle (manifest.json in subdirectory, not root)
mkdir -p "$_MCPB_ZIP_TEST_DIR/bad-staging/subdir/src"
cp "$_MCPB_ZIP_TEST_DIR/valid-staging/manifest.json" \
	"$_MCPB_ZIP_TEST_DIR/bad-staging/subdir/manifest.json"
touch "$_MCPB_ZIP_TEST_DIR/bad-staging/subdir/src/index.js"
_bad_bundle="$_MCPB_ZIP_TEST_DIR/bad.mcpb"
(cd "$_MCPB_ZIP_TEST_DIR/bad-staging" && zip -ry "$_bad_bundle" . -x '*.git*' >/dev/null 2>&1)

# Verify unzip -Z1 with ^ anchor does NOT match subdir/manifest.json as root
if ! unzip -Z1 "$_bad_bundle" 2>/dev/null | grep -q '^manifest\.json$'; then
	pass "functional: unzip -Z1 with ^ anchor rejects manifest.json in subdirectory"
else
	fail "functional: zip fallback" \
		"unzip -Z1 incorrectly matched subdir/manifest.json as root manifest"
fi

# --- Validation script completeness ---
echo ""
echo "-- Validation script completeness --"

# Verify the canonical script exports validate_manifest function
if grep -q '^validate_manifest()' "$VALIDATE_SCRIPT"; then
	pass "canonical script defines validate_manifest function"
else
	fail "canonical script" \
		"missing validate_manifest function definition"
fi

# Verify the canonical script checks all 7 required fields
script_field_count=$(grep -c '_check_field ' "$VALIDATE_SCRIPT" || true)
if [ "$script_field_count" -eq 7 ]; then
	pass "canonical script checks 7 required fields"
else
	fail "canonical script" \
		"expected 7 _check_field calls, got $script_field_count"
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

# --- copy_glob() behavior tests ---
echo ""
echo "-- copy_glob() behavior tests --"

# Structural: copy_glob emits ::warning:: on zero-match (not ::error::)
if grep -q '::warning::No files matched glob' "$WORKFLOW"; then
	pass "copy_glob emits ::warning:: on zero-match (not ::error::)"
else
	fail "copy_glob" \
		"missing ::warning:: annotation for zero-match in copy_glob"
fi

# Structural: copy_glob zero-match message includes cwd diagnostic
if grep -q 'cwd:.*pwd\|verify source-files' "$WORKFLOW"; then
	pass "copy_glob zero-match warning includes cwd diagnostic"
else
	fail "copy_glob" \
		"zero-match warning should include cwd and input hint for debugging"
fi

# Structural: workflow emits ::error:: when zero source files total (fail-fast)
if grep -q '::error::.*source.*file\|::error::.*no.*source\|::error::.*No source' \
	"$WORKFLOW"; then
	pass "workflow emits ::error:: when zero source files matched (fail-fast)"
else
	fail "workflow copy_glob" \
		"missing ::error:: fail-fast for zero total source files"
fi

# Functional: copy_glob zero-match emits warning and exits 0
_CG_TEST_STAGING=$(mktemp -d)
trap 'rm -rf "$_MCPB_SEMANTIC_STAGING" "$_MCPB_ZIP_TEST_DIR" "$_CG_TEST_STAGING"' EXIT

copy_glob_sim() {
	local pattern="$1" dest="$2" matched=0
	shopt -s globstar
	for f in $pattern; do
		[ -f "$f" ] || continue
		local rel="${f#./}"
		mkdir -p "$dest/$(dirname "$rel")"
		cp "$f" "$dest/$rel"
		matched=$((matched + 1))
	done
	if [ "$matched" -eq 0 ]; then
		echo "::warning::No files matched glob: ${pattern} (cwd: $(pwd) — verify source-files/config-files input)"
	fi
	return 0
}

_cg_warning=$(copy_glob_sim "nonexistent-dir-xyz/**" "$_CG_TEST_STAGING" 2>&1)
_cg_exit=$?
if [ "$_cg_exit" -eq 0 ]; then
	pass "copy_glob functional: zero-match exits 0 (does not fail)"
else
	fail "copy_glob functional" \
		"zero-match should exit 0 (got exit $_cg_exit)"
fi

if echo "$_cg_warning" | grep -q '::warning::No files matched glob'; then
	pass "copy_glob functional: zero-match emits ::warning:: annotation"
else
	fail "copy_glob functional" \
		"zero-match did not emit expected ::warning:: (got: $_cg_warning)"
fi

# Functional: copy_glob successful match copies file and exits 0
_CG_SRC_DIR=$(mktemp -d)
_CG_DST_DIR=$(mktemp -d)
trap 'rm -rf "$_MCPB_SEMANTIC_STAGING" "$_MCPB_ZIP_TEST_DIR" "$_CG_TEST_STAGING" "$_CG_SRC_DIR" "$_CG_DST_DIR"' EXIT

mkdir -p "$_CG_SRC_DIR/src"
touch "$_CG_SRC_DIR/src/index.js"

_cg_match_out=$(cd "$_CG_SRC_DIR" && copy_glob_sim "src/*.js" "$_CG_DST_DIR" 2>&1)
_cg_match_exit=$?

if [ "$_cg_match_exit" -eq 0 ]; then
	pass "copy_glob functional: successful match exits 0"
else
	fail "copy_glob functional" \
		"successful match should exit 0 (got exit $_cg_match_exit)"
fi

if [ -f "$_CG_DST_DIR/src/index.js" ]; then
	pass "copy_glob functional: matched file copied to destination"
else
	fail "copy_glob functional" \
		"matched file not found in destination after copy_glob"
fi

if ! echo "$_cg_match_out" | grep -q '::warning::'; then
	pass "copy_glob functional: successful match emits no ::warning::"
else
	fail "copy_glob functional" \
		"successful match should not emit ::warning:: (got: $_cg_match_out)"
fi

# --- ref:main sparse checkout documentation tests ---
echo ""
echo "-- ref:main sparse checkout documentation tests --"

# Structural: workflow checkout step has intent comment explaining ref:main behavior
if grep -q 'frozen\|pinned.*validation\|composite action' "$WORKFLOW"; then
	pass "workflow ref:main checkout step has intent comment (frozen/pinned/composite)"
else
	fail "workflow ref:main" \
		"checkout step missing intent comment explaining live-main vs. pinned behavior"
fi

# Structural: checkout comment mentions callers get updated validation automatically
if grep -q 'automatically\|updated.*validation\|validation.*updated' "$WORKFLOW"; then
	pass "workflow ref:main comment explains callers get updated validation automatically"
else
	fail "workflow ref:main" \
		"checkout comment should explain automatic validation updates for callers"
fi

# Structural: README documents that reusable workflow pulls validate-manifest from main
if grep -q 'main.*validate\|validate.*main\|pulls.*main\|from main\|ref.*main' \
	"$WORKFLOW" &&
	grep -q 'frozen\|pinned\|composite action' "$WORKFLOW"; then
	pass "workflow documents ref:main and frozen/composite alternative"
else
	fail "workflow ref:main" \
		"workflow missing documentation of ref:main and composite alternative"
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
