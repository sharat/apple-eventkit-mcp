PREFIX ?= /usr/local
BINDIR ?= $(PREFIX)/bin

.PHONY: all build test conformance check install uninstall clean

all: build

# The package targets Apple Silicon only, and every supported host is arm64,
# so a plain build already produces an arm64 binary in .build/release.
build:
	swift build -c release

test:
	swift test

# Same stdio conformance check CI runs (.github/workflows/ci.yml).
conformance: build
	scripts/protocol-conformance.sh

check: test conformance

install: build
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 .build/release/apple-eventkit-mcp $(DESTDIR)$(BINDIR)/apple-eventkit-mcp

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/apple-eventkit-mcp

clean:
	swift package clean
