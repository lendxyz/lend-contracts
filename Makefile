help:
	@echo 'Usage: make [TARGET] [EXTRA_ARGUMENTS]'
	@echo 'Targets:'
	@echo 'make install: installs forge required toolchain'
	@echo 'make fmt: format code'
	@echo 'make tests: run tests'
	@echo 'make coverage: show tests coverage'
	@echo 'make build: compile contracts'
	@echo 'make clean: clean build cache and forge cache'
	@echo 'make remappings: generate remappings links for dependencies'
	@echo 'make deploy rpc=[your_rpc_url] pk=[your_private_key]: deploy contracts'

install:
	curl -L https://foundry.paradigm.xyz | bash

fmt:
	forge fmt

tests:
	forge test -vvv

coverage:
	forge coverage

build:
	forge compile

clean:
	forge cache clean && forge clean

remappings:
	forge remappings > remappings.txt

deploy:
	forge script script/Deploy.s.sol:DeployScript --rpc-url $(rpc) --private-key $(pk)


