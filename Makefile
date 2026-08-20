.PHONY: test test-verbose install clean

test:
	@bats tests/

test-verbose:
	@bats -t tests/

install:
	@./install.sh

clean:
	@rm -rf /tmp/tmux-ws-test-*
