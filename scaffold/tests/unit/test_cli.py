from click.testing import CliRunner

from {package}.cli import main


def test_version() -> None:
    result = CliRunner().invoke(main, ["--version"])
    assert result.exit_code == 0
    assert "0.0.0" in result.output


def test_help() -> None:
    result = CliRunner().invoke(main, ["--help"])
    assert result.exit_code == 0


def test_default_greeting() -> None:
    result = CliRunner().invoke(main, [])
    assert result.exit_code == 0
    assert result.output.strip() == "hello world"


def test_named_greeting() -> None:
    result = CliRunner().invoke(main, ["--name", "alice"])
    assert result.exit_code == 0
    assert result.output.strip() == "hello alice"
