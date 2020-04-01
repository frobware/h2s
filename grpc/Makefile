grpc.yaml: check-client-build check-server-build
	./grpc.sh > $@

check-client-build:
	go build -o /dev/null ./client

check-server-build:
	go build -o /dev/null ./server

.PHONY: \
	grpc.yaml \
	check-client-build \
	check-server-build \
