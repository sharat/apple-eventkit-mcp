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

# Local-only: .agents/ is gitignored, so a CI checkout never has it to compare.
skills-sync:
	@if [ -d .agents/skills/apple-reminders ]; then \
		diff -ru skills/apple-reminders .agents/skills/apple-reminders && echo "skills/ and .agents/ in sync"; \
	else \
		echo "skipping: .agents/skills/apple-reminders not present"; \
	fi

check: test conformance skills-sync

install: build
	install -d $(DESTDIR)$(BINDIR)
	install -m 755 .build/release/apple-eventkit-mcp $(DESTDIR)$(BINDIR)/apple-eventkit-mcp

uninstall:
	rm -f $(DESTDIR)$(BINDIR)/apple-eventkit-mcp

clean:
	swift package clean
