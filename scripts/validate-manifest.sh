#!/usr/bin/env bash
# Shared manifest validation logic for MCPB bundles.
# Sourced by action.yml (via $GITHUB_ACTION_PATH) and the reusable workflow
# (via a sparse checkout of this repo).
#
# Usage:
#   source scripts/validate-manifest.sh
#   if ! errors=$(validate_manifest "manifest.json"); then
#     echo "$errors"
#   fi
#
# validate_manifest <path>
#   Prints validation error lines to stdout.
#   Returns 0 on success, 1 on failure.
validate_manifest() {
	local manifest="$1"
	local errors=""

	_check_field() {
		local value
		value=$(jq -r "$1 // empty" "$manifest")
		if [ -z "$value" ]; then
			errors+="Missing required field: $1\n"
		fi
	}

	_check_field '.manifest_version'
	_check_field '.name'
	_check_field '.version'
	_check_field '.description'
	_check_field '.author.name'
	_check_field '.server.type'
	_check_field '.server.entry_point'

	local server_type
	server_type=$(jq -r '.server.type // empty' "$manifest")
	if [ -n "$server_type" ]; then
		case "$server_type" in
		node | python | binary | uv) ;;
		*) errors+="Invalid server type: ${server_type}\n" ;;
		esac
	fi

	local version
	version=$(jq -r '.version // empty' "$manifest")
	if [ -n "$version" ]; then
		local semver='^[0-9]+\.[0-9]+\.[0-9]+(-[a-zA-Z0-9.]+)?(\+[a-zA-Z0-9.]+)?$'
		if ! echo "$version" | grep -qE "$semver"; then
			errors+="Invalid version (not semver): ${version}\n"
		fi
	fi

	local manifest_ver
	manifest_ver=$(jq -r '.manifest_version // empty' "$manifest")
	if [ "$server_type" = "uv" ] && [ "$manifest_ver" != "0.4" ]; then
		errors+="UV server type requires manifest_version 0.4, got: ${manifest_ver}\n"
	fi

	local platforms
	platforms=$(jq -r '.compatibility.platforms[]? // empty' "$manifest" 2>/dev/null || true)
	for p in $platforms; do
		case "$p" in
		darwin | win32 | linux) ;;
		*) errors+="Invalid platform: ${p}\n" ;;
		esac
	done

	local config_types
	config_types=$(jq -r '.user_config // {} | to_entries[] | .value.type // empty' \
		"$manifest" 2>/dev/null || true)
	for t in $config_types; do
		case "$t" in
		string | number | boolean | directory | file) ;;
		*) errors+="Invalid user_config type: ${t}\n" ;;
		esac
	done

	local used_vars
	used_vars=$(jq -r '
    [
      .server.mcp_config.args[]?,
      (.server.mcp_config.env // {} | to_entries[] | .value)
    ] |
    map(select(test("\\$\\{user_config\\."))) |
    map(capture("\\$\\{user_config\\.(?<key>[^}]+)\\}") | .key) |
    unique[]
  ' "$manifest" 2>/dev/null || true)
	for var in $used_vars; do
		local has_config
		has_config=$(jq -r ".user_config.\"$var\" // empty" "$manifest")
		if [ -z "$has_config" ]; then
			errors+="Variable \${user_config.${var}} referenced but not defined in user_config\n"
		fi
	done

	local tool_missing
	tool_missing=$(jq -r '
    .tools[]? |
    select((.name // "") == "" or (.description // "") == "") |
    .name // "(unnamed)"
  ' "$manifest" 2>/dev/null || true)
	if [ -n "$tool_missing" ]; then
		errors+="Tool missing name or description: ${tool_missing}\n"
	fi

	local dups
	dups=$(jq -r '
    [.tools[]?.name] |
    group_by(.) |
    map(select(length > 1)) |
    .[0][0] // empty
  ' "$manifest" 2>/dev/null || true)
	if [ -n "$dups" ]; then
		errors+="Duplicate tool name: ${dups}\n"
	fi

	if [ -n "$errors" ]; then
		printf "%b" "$errors"
		return 1
	fi

	return 0
}
