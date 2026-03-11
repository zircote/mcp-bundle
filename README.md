# mcp-bundle

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Marketplace-2088FF?logo=github-actions&logoColor=white)](https://github.com/zircote/mcp-bundle)
[![Claude Code Plugin](https://img.shields.io/badge/Claude%20Code-Plugin-orange?logo=data:image/svg+xml;base64,PHN2ZyB4bWxucz0iaHR0cDovL3d3dy53My5vcmcvMjAwMC9zdmciIHZpZXdCb3g9IjAgMCAyNCAyNCI+PHBhdGggZmlsbD0id2hpdGUiIGQ9Ik0xMiAyQzYuNDggMiAyIDYuNDggMiAxMnM0LjQ4IDEwIDEwIDEwIDEwLTQuNDggMTAtMTBTMTcuNTIgMiAxMiAyeiIvPjwvc3ZnPg==)](https://github.com/zircote/mcp-bundle)
[![MCP](https://img.shields.io/badge/MCP-Server%20Packaging-blueviolet)](https://github.com/anthropics/mcpb)

A Claude Code plugin and GitHub Actions workflow for generating [MCPB (MCP Bundle)](https://github.com/anthropics/mcpb) packages from MCP server projects.

## Prerequisites

- An MCP server project using stdio transport
- [Node.js](https://nodejs.org/) 18+ (for Node.js server types and the `mcpb` CLI)
- `jq` installed (used by validation scripts)
- For local testing: `npm install -g @anthropic-ai/mcpb`

## What It Does

- **`/mcpb` skill**: Detects MCP server projects, generates `manifest.json`, creates bundle directory structure, validates against the MCPB spec, and wires in CI/CD
- **Reusable GitHub Actions workflow**: Full CI/CD pipeline for MCPB packaging with build, test, validate, package, and release steps
- **Composite GitHub Action**: Marketplace-published action for validate, package, checksum, and upload steps within an existing workflow

## Installation

### As a Claude Code Plugin

Add this repository as a plugin dependency in your Claude Code project, then use `/mcpb` in any MCP server project.

### As a GitHub Actions Reusable Workflow

Reference the reusable workflow at the **job level** in your caller workflow:

```yaml
name: Package MCP Bundle
on:
  push:
    tags: ['v*']

jobs:
  package:
    uses: zircote/mcp-bundle/.github/workflows/mcp-bundle.yml@v1
    with:
      source-files: "src/**"
```

### As a GitHub Actions Composite Action (Marketplace)

Reference the action at the **step level** within an existing job:

```yaml
jobs:
  build:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-node@v4
        with:
          node-version: '20'
      - run: npm ci && npm run build && npm test
      - uses: zircote/mcp-bundle@v1
        with:
          source-files: "src/**"
```

### Reusable Workflow vs. Composite Action

| Feature | Reusable Workflow | Composite Action |
|---------|-------------------|------------------|
| Usage | `uses:` at **job level** | `uses:` at **step level** |
| Checkout & setup | Handled automatically | You handle in prior steps |
| Build & test | Configurable via inputs | You handle in prior steps |
| Manifest validation | Full (10 checks) | Full (10 checks) |
| Bundle packaging | Yes | Yes |
| SHA-256 checksum | Yes | Yes |
| Artifact upload | Yes | Yes |
| Release attachment | Yes | Yes |
| Best for | Standalone CI/CD pipeline | Integration into existing workflows |

## `/mcpb` Skill Usage

Run `/mcpb` in a project directory containing an MCP server. The skill will:

1. **Detect** the MCP server implementation (Node.js, Python, UV, or binary)
2. **Generate** a valid `manifest.json` following the [MANIFEST.md spec](https://github.com/anthropics/mcpb/blob/main/MANIFEST.md)
3. **Create** the bundle directory structure
4. **Validate** the manifest against schema rules
5. **Wire in** a CI/CD caller workflow that invokes the reusable packaging workflow

### Detection Signals

| Language | Detection Criteria |
|----------|-------------------|
| Node.js | `@modelcontextprotocol/sdk` in dependencies, `StdioServerTransport` usage |
| Python | `mcp` package imports, `stdio_server()` usage, `pyproject.toml` with MCP deps |
| Python UV | `pyproject.toml` with `mcp` dep, no `server/lib/` or `server/venv/` |
| Binary | Compiled server executables, `Cargo.toml`/`go.mod` with MCP dependencies |

## Reusable Workflow Reference

### Inputs

| Input | Type | Required | Default | Description |
|-------|------|----------|---------|-------------|
| `source-files` | string | no | `src/**` | Glob pattern(s) for MCP server source files |
| `manifest-path` | string | no | `manifest.json` | Path to manifest.json |
| `config-files` | string | no | `""` | Glob pattern(s) for config files to include |
| `additional-artifacts` | string | no | `""` | Glob pattern(s) for extra files to bundle |
| `node-version` | string | no | `"18"` | Node.js version for build environment |
| `build-command` | string | no | `npm run build` | Build command to run before packaging |
| `test-command` | string | no | `npm test` | Test command (empty string to skip) |
| `bundle-name` | string | no | `""` | Override bundle output filename |
| `upload-artifact` | boolean | no | `true` | Upload bundle as GitHub Actions artifact |
| `create-release-asset` | boolean | no | `false` | Attach bundle to GitHub Release (tag pushes only) |
| `mcpb-version` | string | no | `latest` | Version of mcpb toolchain |
| `runs-on` | string | no | `ubuntu-latest` | Runner label for the packaging job |

### Outputs

| Output | Description |
|--------|-------------|
| `bundle-path` | Path to the generated `.mcpb` bundle file |
| `bundle-sha256` | SHA-256 checksum of the bundle |
| `manifest-valid` | Whether manifest validation passed (`true`/`false`) |

### Manifest Validation Checks

Both the reusable workflow and composite action perform these 11 validation checks:

1. All required fields present (`manifest_version`, `name`, `version`, `description`, `author.name`, `server.type`, `server.entry_point`)
2. `server.type` is one of: `node`, `python`, `binary`, `uv`
3. `version` is valid semver
4. UV server type requires `manifest_version: "0.4"`
5. `compatibility.platforms` values are valid (`darwin`, `win32`, `linux`)
6. `server.entry_point` file exists (warning in composite action, error in reusable workflow)
7. `user_config` field types are valid (`string`, `number`, `boolean`, `directory`, `file`)
8. All `${user_config.*}` variable references have matching `user_config` entries
9. No duplicate tool names in `tools` array
10. Each tool entry has both `name` and `description`
11. JSON is well-formed and parseable

### Example Caller Workflows

See the [`examples/`](examples/) directory for complete caller workflow files:
- [`minimal-caller.yml`](examples/minimal-caller.yml) — bare minimum
- [`standard-caller.yml`](examples/standard-caller.yml) — with config files and Node.js 20
- [`advanced-caller.yml`](examples/advanced-caller.yml) — with release assets and custom build

## Bundle Structure

Generated bundles follow the MCPB spec. Structure varies by server type:

```text
bundle.mcpb (ZIP)
├── manifest.json          # Required
├── server/
│   └── index.js           # Node.js entry point
│       main.py            # Python entry point
│       <binary>           # Binary entry point
├── node_modules/          # Node.js only
├── package.json           # Node.js only (optional)
├── pyproject.toml         # UV runtime only
├── requirements.txt       # Python only (optional)
├── icon.png               # Optional
└── .mcpbignore            # Exclusion rules
```

## Testing

Run the test suite:

```bash
./tests/test-manifest-validation.sh
```

The test suite covers:
- Manifest validation: required fields, semver, server types, UV version constraint, platforms, config types, variable substitution refs, duplicate tools
- JSON structure validation for all fixtures
- Workflow and action YAML structure verification
- Skill file structure and content completeness
- Example workflow presence and references

## `.mcpbignore`

Create a `.mcpbignore` file in your repository root to exclude files from the bundle. Format is similar to `.gitignore`:

```text
# Comments start with #
*.log
*.tmp
tests/
docs/
__pycache__/
```

- Blank lines and lines starting with `#` are ignored
- Patterns ending with `/` match directories
- All other patterns match by filename

The reusable workflow applies exclusions by pruning from the staging directory before packaging. The composite action passes them as `-x` arguments to `zip`.

## Security Considerations

> **Note:** The reusable workflow uses `eval` to execute user-provided `build-command` and `test-command` inputs. These values come from `workflow_call` inputs (set by the calling workflow author, not by PR authors or external contributors), so they are not attacker-controlled in normal usage. However, avoid passing untrusted values through these inputs.

## License

MIT
