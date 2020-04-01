#!/usr/bin/env bash

go_mod="$(sed -e 's/^/        /' go.mod    | sed '/^[[:space:]]*$/d')"
go_sum="$(sed -e 's/^/        /' go.sum    | sed '/^[[:space:]]*$/d')"

go_server="$(sed -e 's/^/        /' server/server.go | sed '/^[[:space:]]*$/d')"
go_client="$(sed -e 's/^/        /' client/client.go | sed '/^[[:space:]]*$/d')"

cat <<EOF
apiVersion: v1
kind: List
items:
- apiVersion: v1
  kind: Service
  metadata:
    name: grpc-interop
    annotations:
      service.beta.openshift.io/serving-cert-secret-name: service-certs
  spec:
    selector:
      app: grpc-interop
    ports:
      - port: 443
        name: https
        targetPort: 443
        protocol: TCP
      - port: 1010
        name: h2c
        targetPort: 1010
        protocol: TCP
- apiVersion: v1
  kind: ConfigMap
  labels:
    app: grpc-interop
  metadata:
    name: src-config
  data:
    go.mod: |
$go_mod
    go.sum: |
$go_sum
    server.go: |
$go_server
    client.go: |
$go_client
- apiVersion: v1
  kind: ConfigMap
  metadata:
    annotations:
      service.beta.openshift.io/inject-cabundle: "true"
    labels:
      app: grpc-interop
    name: service-ca
- apiVersion: v1
  kind: Pod
  metadata:
    name: grpc-interop
    labels:
      app: grpc-interop
  spec:
    containers:
    - image: golang:1.14
      name: server
      command: ["/workdir/grpc-server"]
      env:
      - name: GRPC_GO_LOG_VERBOSITY_LEVEL
        value: "99"
      - name: GRPC_GO_LOG_SEVERITY_LEVEL
        value: "info"
      ports:
      - containerPort: 443
        protocol: TCP
      - containerPort: 1010
        protocol: TCP
      volumeMounts:
      - name: service-certs
        mountPath: /etc/service-certs
      - name: tmp
        mountPath: /var/run
      - name: workdir
        mountPath: /workdir
      readOnly: true
    - image: golang:1.14
      name: client-shell
      command: ["/bin/bash"]
      args: ["-c", "sleep 100000"]
      env:
      - name: GRPC_GO_LOG_VERBOSITY_LEVEL
        value: "99"
      - name: GRPC_GO_LOG_SEVERITY_LEVEL
        value: "info"
      volumeMounts:
      - name: service-certs
        secret:
          secretName: service-certs
        mountPath: /etc/service-certs
      - name: tmp
        mountPath: /var/run
      - name: workdir
        mountPath: /workdir
      - name: service-ca
        mountPath: /etc/service-ca
    initContainers:
    - image: golang:1.14
      name: builder
      command: ["/bin/bash", "-c"]
      args:
        - set -e;
          cd /go/src;
          go build -v -mod=readonly -o /workdir/grpc-server server.go;
          go build -v -mod=readonly -o /workdir/grpc-client client.go;
      env:
      - name: GO111MODULE
        value: "auto"
      volumeMounts:
      - name: src-volume
        mountPath: /go/src
      - name: tmp
        mountPath: /var/run
      - name: workdir
        mountPath: /workdir
    volumes:
    - name: src-volume
      configMap:
        name: src-config
    - name: service-certs
      secret:
        secretName: service-certs
    - name: tmp
      emptyDir: {}
    - name: workdir
      emptyDir: {}
    - configMap:
        items:
        - key: service-ca.crt
          path: service-ca.crt
        name: service-ca
      name: service-ca
  labels:
    app: grpc-interop
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    annotations:
      haproxy.router.openshift.io/enable-h2c: "true"
    labels:
      app: grpc-interop
    name: grpc-interop-edge
  spec:
    port:
      targetPort: 1010
    tls:
      termination: edge
      insecureEdgeTerminationPolicy: Redirect
    to:
      kind: Service
      name: grpc-interop
      weight: 100
    wildcardPolicy: None
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    labels:
      app: grpc-interop
    name: grpc-interop-reencrypt
  spec:
    port:
      targetPort: 443
    tls:
      termination: reencrypt
      insecureEdgeTerminationPolicy: Redirect
    to:
      kind: Service
      name: grpc-interop
      weight: 100
    wildcardPolicy: None
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    labels:
      app: grpc-interop
    name: grpc-interop-passthrough
  spec:
    port:
      targetPort: 443
    tls:
      termination: passthrough
      insecureEdgeTerminationPolicy: Redirect
    to:
      kind: Service
      name: grpc-interop
      weight: 100
    wildcardPolicy: None
EOF
