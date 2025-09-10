help:
	@echo 'Usage: make [TARGET] [EXTRA_ARGUMENTS]'
	@echo 'Targets:'
	@echo 'make install: installs required dependencies'
	@echo 'make install-toolbox: installs forge required toolchain'
	@echo 'make fmt: format code'
	@echo 'make tests: run tests'
	@echo 'make gas-report: get gas reports'
	@echo 'make coverage: show tests coverage'
	@echo 'make build: compile contracts'
	@echo 'make clean: clean build cache and forge cache'
	@echo 'make remappings: generate remappings links for dependencies'
	@echo 'make deploy-factory-mainnet rpc=[your_rpc_url] pk=[your_private_key]: deploy factory on mainnet'
	@echo 'make deploy-factory-testnet rpc=[your_rpc_url] pk=[your_private_key]: deploy factory on sepolia testnet'
	@echo 'make deploy-oft-mainnet rpc=[your_rpc_url] pk=[your_private_key]: deploy opLend OFT'
	@echo 'make deploy-oft-testnet rpc=[your_rpc_url] pk=[your_private_key]: deploy opLend OFT on sepolia testnet'
	@echo 'make deploy-rewards-mainnet rpc=[your_rpc_url] pk=[your_private_key]: deploy rewards contract'
	@echo 'make deploy-rewards-testnet rpc=[your_rpc_url] pk=[your_private_key]: deploy rewards contract on sepolia testnet'
	@echo 'make abi: generate contract abis in the `abis` folder'

install:
	forge install && npm i

install-toolbox:
	curl -L https://foundry.paradigm.xyz | bash

fmt:
	forge fmt

tests:
	forge test -vvv --fork-url https://ethereum-rpc.publicnode.com

gas-report:
	forge test --fork-url https://ethereum-rpc.publicnode.com --gas-report

coverage:
	forge coverage -vvv --fork-url https://ethereum-rpc.publicnode.com

build:
	forge compile

clean:
	forge cache clean && forge clean

remappings:
	forge remappings > remappings.txt

deploy-factory-mainnet:
	forge script script/mainnet/DeployFactory.s.sol:DeployFactory --slow --broadcast --private-key $(pk) --verify

deploy-diamond-testnet:
	forge script script/testnet/DeployFactory.s.sol:DeployFactoryTestnet --slow --broadcast --private-key $(pk) --verify

deploy-oft-mainnet:
	forge script script/mainnet/DeployOFT.s.sol:DeployOFT --slow --broadcast --private-key $(pk) --verify

deploy-oft-testnet:
	forge script script/testnet/DeployOFT.s.sol:DeployOFTTestnet --slow --broadcast --private-key $(pk) --verify

deploy-rewards-mainnet:
	forge script script/mainnet/DeployRewards.s.sol:DeployRewards --slow --broadcast --private-key $(pk) --verify

deploy-rewards-testnet:
	forge script script/testnet/DeployRewards.s.sol:DeployRewardsTestnet --slow --broadcast --private-key $(pk) --verify

set-peer-factory:
	forge script script/SetOpLendPeerFactory.s.sol:SetOpLendPeerFactory --slow --broadcast --private-key $(pk)

set-peer-oft:
	forge script script/SetOpLendPeerOft.s.sol:SetOpLendPeerOft --slow --broadcast --private-key $(pk)

deploy-faucet:
	forge script script/testnet/DeployFaucet.s.sol:DeployFaucet --slow --broadcast --private-key $(pk) --verify

deploy-usdc:
	forge script script/testnet/DeployDummyUSDC.s.sol:DeployDummyUSDC --slow --broadcast --private-key $(pk) --verify

abi:
	mkdir -p abis
	forge inspect ILendFactory abi --json > ./abis/IFactory.json
	forge inspect LendOperation abi --json > ./abis/opLend.json
	forge inspect LendRewards abi --json > ./abis/Rewards.json
	forge inspect LendFaucet abi --json > ./abis/Faucet.json
