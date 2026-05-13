import click

__version__ = "0.0.0"


@click.command()
@click.version_option(__version__)
@click.option("--name", default="world", show_default=True, help="Name to greet.")
def main(name: str) -> None:
    """{project-description}"""
    click.echo(f"hello {name}")


if __name__ == "__main__":
    main()
