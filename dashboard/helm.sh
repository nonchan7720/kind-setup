#!/bin/bash

SCRIPT_DIR=$(cd $(dirname $0); pwd)
MANIFEST="${SCRIPT_DIR}/manifest.yaml"
rm -rf "$MANIFEST"

echo "# yamllint disable" >> "${MANIFEST}"
helmfile --environment ${ENV:-local} --file "${SCRIPT_DIR}/helmfile.yaml" template > "${MANIFEST}"
sed -i "" '/replicas: 1/d' "${MANIFEST}"
