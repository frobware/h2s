# h2spec conformance test setup for OpenShift routes

Requires an OpenShift 4.4+ installation. Exposes a backend Go server
that supports H2 and H2C connections exposed via 3 TLS-enabled routes:
"edge", "passthrough" and "reencrypt".

## Test Setup

    $ oc apply -f https://github.com/frobware/h2s/raw/master/h2spec.yaml

## Verify routes exist

    $ oc get routes
    h2spec-goserver-edge          h2spec-goserver-edge...                 h2spec-goserver   8080   edge/Redirect          None
    h2spec-goserver-passthrough   h2spec-goserver-passthrough...          h2spec-goserver   8443   passthrough/Redirect   None
    h2spec-goserver-reencrypt     h2spec-goserver-reencrypt...            h2spec-goserver   8443   reencrypt/Redirect     None

## Run h2spec conformane tests

Make sure the pods are running and the routes are exposed before
starting the tests.
	
    $ ./test-route-type passthrough
    $ ./test-route-type edge
    $ ./test-route-type reencrypt

## How does this work?

This experiments with some inline-Go to build and execute server.go on
the fly when the pod is launched... because $REASONS.
