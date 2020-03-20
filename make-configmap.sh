#!/usr/bin/env bash

go_mod="$(sed -e 's/^/        /' go.mod | sed '/^[[:space:]]*$/d')"
go_sum="$(sed -e 's/^/        /' go.sum | sed '/^[[:space:]]*$/d')"
go_src="$(sed -e 's/^/        /' server.go | sed '/^[[:space:]]*$/d')"

cat <<EOF
apiVersion: v1
data:
  go.mod: |
$go_mod
  go.sum: |
$go_sum
  server.go: |
$go_src
kind: ConfigMap
metadata:
  name: src-config
EOF
