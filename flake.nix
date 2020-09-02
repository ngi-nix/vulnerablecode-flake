{
  description = "Vulnerablecode - A free and open vulnerabilities database and the packages they impact.";

  # Nixpkgs / NixOS version to use.
  #inputs.nixpkgs.url = "nixpkgs/nixos-20.03";
  inputs.nixpkgs = { type = "github"; owner = "NixOS"; repo = "nixpkgs"; ref = "d418434d127bd2423b9115768d9cbf80ed5da52a"; };

  # Upstream source tree(s).
  inputs.vulnerablecode-src = { type = "github"; owner = "nexB"; repo = "vulnerablecode"; rev =  "6a2a1b6b26be93948831b1be785d4d2875c93784"; flake = false; };

  outputs = { self, nixpkgs, vulnerablecode-src}:
    let

      # Generate a user-friendly version numer.
      version = builtins.substring 0 7 vulnerablecode-src.rev;

      # System types to support.
      supportedSystems = [ "x86_64-linux" ];

      # Helper function to generate an attrset '{ x86_64-linux = f "x86_64-linux"; ... }'.
      forAllSystems = f: nixpkgs.lib.genAttrs supportedSystems (system: f system);

      # Nixpkgs instantiated for supported system types.
      nixpkgsFor = forAllSystems (system: import nixpkgs { inherit system; overlays = [ self.overlay ]; });

    in

    {

      # A Nixpkgs overlay.
      overlay = final: prev: with final.pkgs; {

        pypi2nix = import ./requirements.nix { pkgs = final; };

        vulnerablecode = python38Packages.buildPythonApplication rec {
          inherit version;
          pname = "vulnerablecode";

          src = vulnerablecode-src;

          propagatedBuildInputs = builtins.attrValues pypi2nix.packages;

          dontBuild = true;

          doCheck = false;

          installPhase = ''
              mkdir -p $out
              cp -r $src/* $out
          '';

          meta = {
            homepage = "https://github.com/nexB/vulnerablecode";
            license = lib.licenses.asl20;
            description = "A free and open vulnerabilities database and the packages they impact. And the tools to aggregate and correlate these vulnerabilities.";
          };

        };

      };

      # Provide some binary packages for selected system types.
      packages = forAllSystems (system:
        {
          inherit (nixpkgsFor.${system}) vulnerablecode;
        });

      # The default package for 'nix build'. This makes sense if the
      # flake provides only one package or there is a clear "main"
      # package.
      defaultPackage = forAllSystems (system: self.packages.${system}.vulnerablecode);

      # Tests run by 'nix flake check' and by Hydra.
      checks = forAllSystems (system: {
        inherit (self.packages.${system}) vulnerablecode;

        # Additional tests, if applicable.
        vulnerablecode-pytest =
          with nixpkgsFor.${system};
          stdenv.mkDerivation {
            name = "vulnerablecode-test-${version}";

            buildInputs = [ wget postgresql vulnerablecode ];

            # Used by pygit2.
            # See https://github.com/NixOS/nixpkgs/pull/72544#issuecomment-582674047.
            SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

            unpackPhase = "true";

            # Setup postgres, run migrations, run pytset and test-run the webserver.
            # See ${vulnerablecode}/README.md for the original instructions.
            # Notes:
            # - $RUNDIR is used to prevent postgres from accessings its default run dir at /run/postgresql.
            #   See also https://github.com/NixOS/nixpkgs/issues/83770#issuecomment-607992517.
            # - pytest can only be run with an running postgres database server.
            buildPhase = ''
              DATADIR=$(pwd)/pgdata
              RUNDIR=$(pwd)/run
              ENCODING="UTF-8"
              mkdir -p $RUNDIR
              initdb -D $DATADIR -E $ENCODING
              pg_ctl -D $DATADIR -o "-k $RUNDIR" -l $DATADIR/logfile start
              createuser --host $RUNDIR --no-createrole --no-superuser --login --inherit --createdb --pwprompt vulnerablecode
              createdb   --host $RUNDIR -E $ENCODING --owner=vulnerablecode --user=vulnerablecode --password --port=5432 vulnerablecode
              (
                export DJANGO_DEV=1
                ${vulnerablecode}/manage.py migrate
                pytest ${vulnerablecode}
                ${vulnerablecode}/manage.py runserver &
                sleep 5
                ${wget}/bin/wget http://127.0.0.1:8000/api/
                kill %1 # kill webserver
              )
            '';

            installPhase = "mkdir -p $out";
          };
      });
    };
}
