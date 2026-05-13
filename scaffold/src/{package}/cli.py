import click

__version__ = "0.0.0"


@click.group()
@click.version_option(__version__)
def main() -> None:
    """{project-description}"""


if __name__ == "__main__":
    main()
