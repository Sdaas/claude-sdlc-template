# {project-name}

{project-description}

[![CI](https://github.com/{org}/{project-name}/actions/workflows/ci.yml/badge.svg)](https://github.com/{org}/{project-name}/actions/workflows/ci.yml)
[![Security](https://github.com/{org}/{project-name}/actions/workflows/security.yml/badge.svg)](https://github.com/{org}/{project-name}/actions/workflows/security.yml)
[![codecov](https://codecov.io/gh/{org}/{project-name}/branch/main/graph/badge.svg)](https://codecov.io/gh/{org}/{project-name})

---

## Installation

### Via Homebrew (recommended)

```bash
brew tap {org}/tools
brew install {project-name}
```

### Verify installation

```bash
{project-name} --version
{project-name} --help
{project-name}
```

---

## Usage

```bash
{project-name} [OPTIONS] COMMAND [ARGS]
```

### Commands

| Command | Description |
|---------|-------------|
| *(add commands here)* | |

### Options

| Option | Description |
|--------|-------------|
| `--version` | Show the version and exit |
| `--verbose` | Enable verbose output (INFO level logging) |
| `--debug` | Enable debug output (DEBUG level logging) |
| `--help` | Show help and exit |

---

## Examples

```bash
# Add usage examples here
{project-name} --help
```

---

## Configuration

*(Describe any configuration files, environment variables, or settings here.)*

Default configuration location: `~/.config/{project-name}/`

---

## Requirements

- macOS (primary platform — installed via Homebrew)
- Python 3.11+ (managed automatically by Homebrew)

---

## First-time setup

After cloning, run these commands to confirm everything is wired up before writing any code:

```bash
uv sync
uv run pytest
uv run {project-name} --help
uv run {project-name}
uv run {project-name} --name you
```

All commands should exit cleanly. If pytest fails, check the output for setup issues. If the CLI fails, verify `uv sync` completed without errors.

**What's happening when you run `uv run {project-name}`:**

The entry point is defined in `pyproject.toml`:

```toml
[project.scripts]
{project-name} = "{package}.cli:main"
```

This maps the `{project-name}` command to the `main` function in `src/{package}/cli.py`. That function is a Click command with one option — `--name` — which defaults to `world`. So:

- `uv run {project-name}` prints `hello world` (the default)
- `uv run {project-name} --name alice` prints `hello alice`
- `uv run {project-name} --help` shows the help text with available options
- `uv run {project-name} --version` prints the current version from `pyproject.toml`

This placeholder command is your starting point. Replace `cli.py` with the real logic for your project.

---

## Development

This project uses [claude-sdlc-template](https://github.com/Sdaas/claude-sdlc-template)
for development workflow management. See the developer documentation:

- [OVERVIEW.md](docs/OVERVIEW.md) — conceptual overview of the development environment
- [DEVELOPER_GUIDE.md](docs/DEVELOPER_GUIDE.md) — setup and daily workflow reference
- [CONTRIBUTING.md](docs/CONTRIBUTING.md) — contribution guidelines
- [SDLC_PROCESS.md](docs/SDLC_PROCESS.md) — full SDLC process reference

### Quick start for contributors

```bash
# Clone and set up
git clone https://github.com/{org}/{project-name}.git
cd {project-name}
uv sync
uv run pre-commit install

# Verify setup
uv run pytest
uv run ruff check .
uv run mypy src/

# Start Claude Code
claude
```

---

## Changelog

See [CHANGELOG.md](CHANGELOG.md) for the full release history.

---

## License

MIT — see [LICENSE](LICENSE) for details.

---

## Author

{author-name} — [{author-email}](mailto:{author-email})
