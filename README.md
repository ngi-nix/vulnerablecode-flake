# VulnerableCode

Links:

* [ngi-nix issue](https://github.com/ngi-nix/ngi/issues/73)
* [project website](https://github.com/nexB/vulnerablecode)
* [Hydra](https://hydra.ngi0.nixos.org/project/vulnerablecode)

## Implementation

``poetry2nix`` was used in order to setup the Python dependencies of the project.

```bash
# Launch shell with necessary dependencies.
nix-shell -p poetry -p libxml2 -p libxslt 
# Setup poetry project.
poetry init
# Convert requirements.txt entries to pyproject.toml entries.
# https://github.com/python-poetry/poetry/issues/663
> cat ~/src/vulnerablecode/requirements.txt | perl -pe 's/([<=>]+)/:$1/' | xargs -t -n 1 -I {} poetry add '{}'
```

A test db can be populated using ``./import.sh``.
The flake attribute ``devShell`` was specifically designed to allow access to ``vulnerablecode`` within a ``nix-shell`` environment.
The latter is used by ``import.sh``.
Note that importing may fail due to issues from vulnerablecode's upstream projects ([example](https://github.com/nexB/vulnerablecode/issues/244)).

```bash
./import.sh --all
```
