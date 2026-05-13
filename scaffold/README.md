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
