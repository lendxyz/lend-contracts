help:
	@echo 'Usage: make [TARGET] [EXTRA_ARGUMENTS]'
	@echo 'Targets:'
	@echo 'make install: installs required dependencies'
	@echo 'make install-toolbox: installs forge required toolchain'
	@echo 'make fmt: format code'
	@echo 'make tests: run tests'
	@echo 'make coverage: show tests coverage'
	@echo 'make build: compile contracts'
	@echo 'make clean: clean build cache and forge cache'
	@echo 'make remappings: generate remappings links for dependencies'
	@echo 'make deploy rpc=[your_rpc_url] pk=[your_private_key]: deploy contracts'
	@echo 'make abi: generate contract abis in the `abis` folder'

install:
	forge install && npm i

install-toolbox:
	curl -L https://foundry.paradigm.xyz | bash

fmt:
	forge fmt

tests:
	forge test -vvv --fork-url https://eth.meowrpc.com

coverage:
	forge coverage -vvv --fork-url https://eth.meowrpc.com

build:
	forge compile

clean:
	forge cache clean && forge clean

remappings:
	forge remappings > remappings.txt

deploy-factory:
	forge script script/DeployFactory.s.sol:DeployFactory --slow --broadcast --private-key $(pk) --verify

abi:
	rm -rf abis
	mkdir -p abis
	forge inspect LendFactory abi > ./abis/Factory.json
	forge inspect LendOperation abi > ./abis/opLend.json
	forge inspect LendDebt abi > ./abis/dLend.json
