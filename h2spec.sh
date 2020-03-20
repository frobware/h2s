#!/usr/bin/env bash

go_mod="$(sed -e 's/^/        /' go.mod    | sed '/^[[:space:]]*$/d')"
go_sum="$(sed -e 's/^/        /' go.sum    | sed '/^[[:space:]]*$/d')"
go_src="$(sed -e 's/^/        /' server.go | sed '/^[[:space:]]*$/d')"

cat <<EOF
apiVersion: v1
kind: List
items:
- apiVersion: v1
  kind: Service
  metadata:
    name: h2spec-goserver
    annotations:
      service.beta.openshift.io/serving-cert-secret-name: service-certs
  spec:
    selector:
      app: h2spec-goserver
    ports:
      - port: 443
        name: https
        targetPort: 8443
        protocol: TCP
      - port: 80
        name: http
        targetPort: 8080
        protocol: TCP
- apiVersion: v1
  kind: ConfigMap
  metadata:
    name: src-config
  data:
    go.mod: |
$go_mod
    go.sum: |
$go_sum
    server.go: |
$go_src
- apiVersion: v1
  kind: Pod
  metadata:
    name: h2spec-goserver
    labels:
      app: h2spec-goserver
  spec:
    containers:
    - image: golang:1.14
      name: serve
      command: ["/bin/bash"]
      args: ["-c", "cd /go/src && GODEBUG=http2debug=0 go build -x -mod=readonly -o /tmp/server server.go && /tmp/server"]
      env:
      - name: GO111MODULE
        value: "auto"
      - name: GODEBUG
        value: "http2debug=1"
      ports:
      - containerPort: 8443
        protocol: TCP
      - containerPort: 8080
        protocol: TCP
      volumeMounts:
      - name: src-volume
        mountPath: /go/src
      - name: service-certs
        mountPath: /etc/service-certs
      - name: tmp
        mountPath: /var/run
    volumes:
    - name: src-volume
      configMap:
        name: src-config
    - name: conf
      configMap:
        name: h2spec-goserver
    - name: service-certs
      secret:
        secretName: service-certs
    - name: tmp
      emptyDir: {}
    - name: tmp2
      emptyDir: {}
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    annotations:
      haproxy.router.openshift.io/enable-h2c: "true"
    labels:
      app: h2spec-goserver
    name: h2spec-goserver-edge
  spec:
    port:
      targetPort: 8080
    tls:
      termination: edge
      insecureEdgeTerminationPolicy: Redirect
    to:
      kind: Service
      name: h2spec-goserver
      weight: 100
    wildcardPolicy: None
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    labels:
      app: h2spec-goserver
    name: h2spec-goserver-reencrypt
  spec:
    port:
      targetPort: 8443
    tls:
      termination: reencrypt
      insecureEdgeTerminationPolicy: Redirect
    to:
      kind: Service
      name: h2spec-goserver
      weight: 100
    wildcardPolicy: None
- apiVersion: route.openshift.io/v1
  kind: Route
  metadata:
    labels:
      app: h2spec-goserver
    name: h2spec-goserver-passthrough
  spec:
    port:
      targetPort: 8443
    tls:
      termination: passthrough
      insecureEdgeTerminationPolicy: Redirect
    to:
      kind: Service
      name: h2spec-goserver
      weight: 100
    wildcardPolicy: None
- apiVersion: v1
  kind: Pod
  metadata:
    name: h2spec
    labels:
      app: h2spec
  spec:
    containers:
    - name: h2spec
      image: docker.io/summerwind/h2spec:2.4.0
      command: ["/bin/bash"]
      args: ["-c", "while true; do echo -n 'heartbeat: '; date; sleep 60; done"]
    terminationGracePeriodSeconds: 1
EOF
