# mcp-bundle

Claude Code plugin for generating MCPB (MCP Bundle) packages and a reusable GitHub Actions workflow for automated MCPB packaging.

## Plugin Structure

```
mcp-bundle/
├── .claude-plugin/
│   └── plugin.json           # Plugin manifest (required)
├── skills/
│   └── mcpb/
│       └── SKILL.md          # /mcp-bundle:mcpb skill
├── .github/
│   └── workflows/
│       └── mcp-bundle.yml    # Reusable workflow for CI/CD packaging
├── action.yml                # GitHub Actions Marketplace composite action
├── examples/                  # Example caller workflows
├── tests/                     # Validation and test scripts
├── CLAUDE.md                  # This file
├── LICENSE                    # MIT
└── README.md                  # Documentation
```

## Skills

### `/mcp-bundle:mcpb`
Generates MCPB bundle packages for MCP server projects. Detects existing MCP server implementations, generates `manifest.json`, creates bundle directory structure, validates against the MANIFEST.md spec, and wires in CI/CD via the reusable workflow.

## Testing

Run the test suite:

```bash
./tests/test-manifest-validation.sh
```

Requires: `bash` 4+, `jq`. Tests validate manifest parsing, required fields, validation rules, workflow/action structure, skill content, and example presence. All 213 tests must pass before committing.

Test fixtures live in `tests/fixtures/` — add new `.json` fixtures there for additional validation test cases.

## MCPB Spec Reference

- Manifest spec version: `0.3` (Node/Python/Binary), `0.4` (UV runtime)
- Bundle format: ZIP archive with `.mcpb` extension
- Transport: stdio only
- Required manifest fields: `manifest_version`, `name`, `version`, `description`, `author`, `server`
- Server types: `node`, `python`, `binary`, `uv`
