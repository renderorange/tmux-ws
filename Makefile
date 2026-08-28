.PHONY: test install clean

test:
	@bats -t tests/

install:
	@./install.sh

clean:
	@rm -rf /tmp/tmux-ws-test-*
