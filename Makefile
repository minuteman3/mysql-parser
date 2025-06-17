build:
	CGO_ENABLED=1 GOOS=$(or $(GOOS),linux) GOARCH=$(or $(GOARCH),amd64) go build \
		-buildmode=c-shared \
		-ldflags="-s -w" \
		-trimpath \
		-o libmysql_parser.so ./parser.go
	@echo "Binary size: $$(ls -lh libmysql_parser.so | awk '{print $$5}') ($$(ls -l libmysql_parser.so | awk '{print $$5}') bytes)"

clean:
	rm -f libmysql_parser.so libmysql_parser.h

.PHONY: build clean