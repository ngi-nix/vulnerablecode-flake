#!/usr/bin/env nix-shell
#!nix-shell -i bash

export DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
export TEMPDIR=$(mktemp -d -p "$DIR")
export DATADIR="${TEMPDIR}/pgdata"
export RUNDIR="${TEMPDIR}/run"

cleanup() {
  pg_ctl -D "$DATADIR" stop
  rm -rf "$TEMPDIR"
}

trap cleanup EXIT

ENCODING="UTF-8"
mkdir -p "$RUNDIR"
initdb -D "$DATADIR" -E $ENCODING
pg_ctl -D "$DATADIR" -o "-k $RUNDIR" -l "$DATADIR/logfile" start
createuser --host "$RUNDIR" --no-createrole --no-superuser --login --inherit --createdb vulnerablecode
createdb   --host "$RUNDIR" -E $ENCODING --owner=vulnerablecode --user=vulnerablecode --port=5432 vulnerablecode
(
  export DJANGO_DEV=1
  ${vulnerablecode}/manage.py migrate
  ${vulnerablecode}/manage.py import "$@"
)
