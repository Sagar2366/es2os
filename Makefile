BINARY=es2os
VERSION=0.1.0
BUILD_TIME=$(shell date -u +"%Y-%m-%dT%H:%M:%SZ")
LDFLAGS=-ldflags "-X main.version=$(VERSION) -X main.buildTime=$(BUILD_TIME)"

.PHONY: build run clean demo install tidy

# Build the binary
build: tidy
	go build $(LDFLAGS) -o $(BINARY) .

# Run go mod tidy to resolve dependencies
tidy:
	go mod tidy

# Run the demo (the stage command)
demo: build
	@./$(BINARY) report --file testdata/es7_full_cluster.json --source-version 7.17.27 --target-version 2.19.5

# Quick run without explicit build
run:
	go run . report --file testdata/es7_full_cluster.json --source-version 7.17.27 --target-version 2.19.5

# Generate HTML report
html: build
	@./$(BINARY) report --file testdata/es7_full_cluster.json --source-version 7.17.27 --target-version 2.19.5 -o html --html-file report.html
	@echo "Report written to report.html"

# Run individual commands
scan: build
	@./$(BINARY) scan --file testdata/es7_full_cluster.json --source-version 7.17.27 --target-version 2.19.5

analyze: build
	@./$(BINARY) analyze --file testdata/es7_full_cluster.json --source-version 7.17.27 --target-version 2.19.5

transform: build
	@./$(BINARY) transform --file testdata/es7_full_cluster.json --source-version 7.17.27 --target-version 2.19.5

# Install globally
install: tidy
	go install $(LDFLAGS) .

# Clean build artifacts
clean:
	rm -f $(BINARY) report.html
