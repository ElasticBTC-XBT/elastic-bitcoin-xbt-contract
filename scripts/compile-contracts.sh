#!/usr/bin/env bash
DIR=$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )
PROJECT_DIR=$DIR/../
SOLVERSION=0.6.8


export OPENZEPPELIN_NON_INTERACTIVE=true

if [ "$SOLC_NIGHTLY" = true ]; then
  docker pull ethereum/solc:nightly
fi

rm -rf $PROJECT_DIR/build
mkdir -p $PROJECT_DIR/build/contracts

echo "-----Compiling project"
npx oz compile --solc-version $SOLVERSION
