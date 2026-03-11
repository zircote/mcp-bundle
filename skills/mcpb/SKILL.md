---
name: mcpb
description: Generate MCPB (MCP Bundle) packages for MCP server projects. Creates manifest.json, bundle directory structure, validates against the MCPB spec, and wires in CI/CD workflows.
user_invocable: true
---

# MCPB Bundle Generator

You are an expert at creating MCPB (MCP Bundle) packages following the official specification from https://github.com/anthropics/mcpb.

## Trigger Patterns

This skill activates when the user asks to:
- "create mcpb bundle"
- "package mcp server"
- "create mcp bundle"
- "mcpb init"
- "mcpb"

## Execution Flow

Follow these steps in order. Do NOT skip steps. Ask clarifying questions only when values truly cannot be inferred.

### Step 1: Detect MCP Server

Search the current project for an existing MCP server implementation.

**Detection signals by language:**

**Node.js:**
- `package.json` containing `@modelcontextprotocol/sdk` in dependencies
- Source files importing from `@modelcontextprotocol/sdk`
- Usage of `StdioServerTransport`
- Usage of `Server` class from `@modelcontextprotocol/sdk/server`

**Python:**
- `requirements.txt` or `pyproject.toml` containing `mcp` package
- Source files importing from `mcp.server`
- Usage of `stdio_server()` or `mcp.server.stdio`
- Decorators like `@server.list_tools()`, `@server.call_tool()`

**Python UV:**
- `pyproject.toml` with `mcp` in dependencies
- Source files using `mcp.server.stdio.stdio_server()`
- No `server/lib/` or `server/venv/` directories (deps managed by UV)

**Binary:**
- `Cargo.toml` with MCP-related dependencies
- `go.mod` with MCP SDK references
- Pre-compiled executables in `server/` directory

**Search strategy:**
1. Check `package.json` for `@modelcontextprotocol/sdk` in dependencies/devDependencies
2. Check `pyproject.toml` or `requirements.txt` for `mcp` package
3. Grep source files for MCP SDK imports: `@modelcontextprotocol/sdk`, `from mcp`, `mcp.server`
4. Look for `StdioServerTransport`, `stdio_server`, transport setup patterns
5. Identify all tool definitions (tool names, descriptions, input schemas)

**If NO MCP server is detected:**
Ask the user: "No MCP server found in this project. Would you like me to:
1. Scaffold a new MCP server with MCPB bundle structure
2. Point me to the server entry file

Which would you prefer?"

If they choose option 1, scaffold a minimal MCP server using Node.js with `@modelcontextprotocol/sdk` that includes a single example tool.

### Step 2: Gather Manifest Information

Extract as much as possible from the project automatically:

**Auto-inferred fields (DO NOT ask the user for these):**
- `name` → from `package.json` name field, or `pyproject.toml` project name, or directory name
- `version` → from `package.json` version, or `pyproject.toml` version, or default `"0.1.0"`
- `description` → from `package.json` description, or `pyproject.toml` description
- `author` → from `package.json` author field, or `pyproject.toml` authors, or git config
- `server.type` → detected language: `"node"`, `"python"`, `"uv"`, or `"binary"`
- `server.entry_point` → detected main file path relative to project root
- `tools` → extracted from tool handler registrations in source code
- `license` → from `package.json` license field, or LICENSE file detection
- `keywords` → from `package.json` keywords, or inferred from tool names
- `compatibility.platforms` → default `["darwin", "win32", "linux"]`
- `compatibility.runtimes` → inferred from detected language and version requirements

**Ask the user ONLY for fields that cannot be inferred:**
- `display_name` — suggest a default based on the name (e.g., "my-mcp-server" → "My MCP Server")
- `description` — only if not found in package.json/pyproject.toml
- `icon` — ask if they have an icon file, or skip (optional field)

**For `user_config`:**
- Scan source code for environment variable reads (`process.env.`, `os.environ`, `os.getenv`)
- Look for config file loading patterns
- For each env var found, create a corresponding `user_config` entry with:
  - `type: "string"` (or `"boolean"` / `"number"` if usage context is clear)
  - `sensitive: true` for vars named `*_KEY`, `*_SECRET`, `*_TOKEN`, `*_PASSWORD`
  - Appropriate `title` and `description` derived from the variable name
  - `required: true` if the code treats it as mandatory (no fallback/default)

### Step 3: Generate manifest.json

Create a valid `manifest.json` at the project root following this exact schema:

```json
{
  "manifest_version": "0.3",
  "name": "<machine-readable-name>",
  "display_name": "<Human Friendly Name>",
  "version": "<semver>",
  "description": "<brief description>",
  "author": {
    "name": "<author name>",
    "email": "<optional email>",
    "url": "<optional url>"
  },
  "server": {
    "type": "<node|python|binary|uv>",
    "entry_point": "<relative path to main file>",
    "mcp_config": {
      "command": "<node|python|binary-path>",
      "args": ["${__dirname}/<entry_point>"],
      "env": {}
    }
  },
  "tools": [
    {
      "name": "<tool_name>",
      "description": "<tool description>"
    }
  ],
  "keywords": [],
  "license": "MIT",
  "user_config": {},
  "compatibility": {
    "platforms": ["darwin", "win32", "linux"],
    "runtimes": {}
  }
}
```

**Schema rules:**
- `manifest_version`: Use `"0.3"` for node/python/binary, `"0.4"` for uv
- `name`: Lowercase, hyphenated, no spaces (machine-readable)
- `version`: Must be valid semver
- `server.type`: One of `"node"`, `"python"`, `"binary"`, `"uv"`
- `server.entry_point`: Relative path from bundle root to the server main file
- For UV type: omit `mcp_config` (the UV runtime handles execution)
- `args` should use `${__dirname}` variable for the entry point path
- Sensitive config values use `${user_config.KEY_NAME}` variable substitution in `env`
- `tools` array: list every tool the server exposes with name and description
- `compatibility.runtimes`: e.g., `{"node": ">=18.0.0"}` or `{"python": ">=3.10"}`

### Step 4: Create Bundle Directory Structure

Organize the project files into the MCPB bundle structure:

**For Node.js projects:**
```
<project-root>/
├── manifest.json
├── server/
│   └── index.js          (or the detected entry point)
├── node_modules/          (production deps only)
├── package.json
├── icon.png               (if provided)
└── .mcpbignore
```

**For Python projects:**
```
<project-root>/
├── manifest.json
├── server/
│   ├── main.py            (or the detected entry point)
│   └── lib/               (bundled dependencies)
├── requirements.txt
├── icon.png               (if provided)
└── .mcpbignore
```

**For UV runtime projects:**
```
<project-root>/
├── manifest.json
├── pyproject.toml
├── src/
│   └── server.py          (or the detected entry point)
├── icon.png               (if provided)
└── .mcpbignore
```

**For Binary projects:**
```
<project-root>/
├── manifest.json
├── server/
│   └── <binary-name>      (compiled executable)
├── icon.png               (if provided)
└── .mcpbignore
```

**Generate `.mcpbignore`** to exclude non-bundle files:
```
.git/
.github/
.vscode/
.idea/
*.md
tests/
test/
__tests__/
*.test.*
*.spec.*
.env
.env.*
.DS_Store
Thumbs.db
coverage/
.nyc_output/
tsconfig.json
.eslintrc*
.prettierrc*
__pycache__/
*.pyc
.pytest_cache/
.mypy_cache/
*.egg-info/
.venv/
```

**IMPORTANT:** Do NOT move or restructure existing source files unless absolutely necessary. If the server entry point is already at a reasonable location (e.g., `src/index.js`), update the manifest `entry_point` to reference that location rather than forcing files into `server/`.

### Step 5: Validate Manifest

Run these validation checks on the generated `manifest.json`:

1. **Required fields present:** `manifest_version`, `name`, `version`, `description`, `author.name`, `server.type`, `server.entry_point`
2. **Version is valid semver:** Match pattern `^\d+\.\d+\.\d+(-[\w.]+)?(\+[\w.]+)?$`
3. **Server type is valid:** One of `"node"`, `"python"`, `"binary"`, `"uv"`
4. **Entry point file exists:** The file referenced by `server.entry_point` must exist
5. **Manifest version matches server type:** `"uv"` type requires `manifest_version: "0.4"`
6. **Platform values valid:** Each entry in `compatibility.platforms` is one of `"darwin"`, `"win32"`, `"linux"`
7. **User config types valid:** Each `user_config` entry has `type` of `"string"`, `"number"`, `"boolean"`, `"directory"`, or `"file"`
8. **Variable substitution valid:** All `${user_config.*}` references in `mcp_config` have matching `user_config` entries
9. **Tool names present:** If `tools` array exists, each tool has `name` and `description`
10. **No duplicate tool names:** All tool names in the `tools` array are unique

**On validation failure:** Report the specific validation errors and fix them automatically. Do not ask the user to fix validation issues — resolve them.

### Step 6: Wire In CI/CD Workflow

Generate a caller workflow at `.github/workflows/mcp-bundle.yml` that invokes the reusable workflow:

```yaml
name: Package MCPB Bundle
on:
  push:
    branches: [main]
    tags: ['v*']
  pull_request:
    branches: [main]

jobs:
  package:
    uses: zircote/mcp-bundle/.github/workflows/mcp-bundle.yml@v1
    with:
      source-files: "<detected-source-glob>"
      manifest-path: "manifest.json"
      node-version: "<detected-node-version-or-18>"
      build-command: "<detected-build-command-or-npm-run-build>"
      test-command: "<detected-test-command-or-npm-test>"
      upload-artifact: true
      create-release-asset: ${{ startsWith(github.ref, 'refs/tags/v') }}
```

**Customize the caller workflow based on detected project:**
- `source-files`: Infer from project structure (e.g., `"src/**"`, `"server/**"`)
- `config-files`: Include if config directory exists
- `additional-artifacts`: Include if assets directory exists
- `build-command`: From `package.json` scripts.build, or `pyproject.toml` build config
- `test-command`: From `package.json` scripts.test, or `pytest`/`python -m pytest`
- `node-version`: From `.nvmrc`, `package.json` engines, or default `"18"`

### Step 7: Summary Output

After completing all steps, print a summary:

```
## MCPB Bundle Created

### Files Generated:
- ✓ manifest.json — Bundle manifest (spec v0.3)
- ✓ .mcpbignore — Bundle exclusion rules
- ✓ .github/workflows/mcp-bundle.yml — CI/CD caller workflow

### Manifest Details:
- Name: <name>
- Version: <version>
- Server Type: <type>
- Entry Point: <entry_point>
- Tools: <count> tools defined
- User Config: <count> configurable options

### Validation:
- ✓ All required fields present
- ✓ Semver valid
- ✓ Entry point exists
- ✓ Variable substitutions resolved

### Next Steps:
1. Review manifest.json and adjust any inferred values
2. Install mcpb CLI: `npm install -g @anthropic-ai/mcpb`
3. Test locally: `mcpb pack` to create the .mcpb bundle
4. Test the bundle: install it in Claude Desktop
5. Push to trigger CI/CD packaging
```

## Important Constraints

- **stdio transport ONLY** — All MCPB servers communicate over stdin/stdout. Never use HTTP/SSE transport.
- **stderr for logging** — stdout is reserved for MCP protocol messages. All logging goes to stderr.
- **No shell injection** — Never construct shell commands from user input. Validate all inputs.
- **Idempotent** — Running `/mcpb` again on a project that already has a manifest should update, not duplicate.
- **Preserve existing code** — Do not restructure the user's source code. Adapt the manifest to match the existing structure.
- **Validate before writing** — Always validate the manifest in memory before writing to disk.
