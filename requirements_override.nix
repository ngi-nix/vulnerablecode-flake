{ pkgs, python }:

self: super: {

  "pytest-mock" = python.overrideDerivation super."pytest-mock" (old: {
    buildInputs = old.buildInputs ++ [ self."setuptools-scm" ];
  });
}
