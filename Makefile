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
	@echo 'make deploy-factory rpc=[your_rpc_url] pk=[your_private_key]: deploy factory and dlend'
	@echo 'make deploy-factory-testnet rpc=[your_rpc_url] pk=[your_private_key]: deploy factory and dlend on sepolia testnet'
	@echo 'make deploy-oft rpc=[your_rpc_url] pk=[your_private_key]: deploy opLend OFT'
	@echo 'make deploy-oft-testnet rpc=[your_rpc_url] pk=[your_private_key]: deploy opLend OFT on sepolia testnet'
	@echo 'make deploy-rewards rpc=[your_rpc_url] pk=[your_private_key]: deploy rewards contract'
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

deploy-diamond:
	forge script script/DeployDiamond.s.sol:DeployDiamond --slow --broadcast --private-key $(pk) --verify

deploy-factory:
	forge script script/DeployFactory.s.sol:DeployFactory --slow --broadcast --private-key $(pk) --verify

deploy-factory-testnet:
	forge script script/DeployFactoryTestnet.s.sol:DeployFactoryTestnet --broadcast --slow --private-key $(pk) --verify

deploy-oft:
	forge script script/DeployOFT.s.sol:DeployOFT --slow --broadcast --private-key $(pk) --verify

deploy-oft-testnet:
	forge script script/DeployOFTTestnet.s.sol:DeployOFTTestnet --slow --broadcast --private-key $(pk) --verify

deploy-rewards:
	forge script script/DeployRewards.s.sol:DeployRewards --slow --broadcast --private-key $(pk) --verify

deploy-rewards-testnet:
	forge script script/DeployRewardsTestnet.s.sol:DeployRewardsTestnet --slow --broadcast --private-key $(pk) --verify

set-peer-factory:
	forge script script/SetOpLendPeerFactory.s.sol:SetOpLendPeerFactory --slow --broadcast --private-key $(pk)

set-peer-oft:
	forge script script/SetOpLendPeerOft.s.sol:SetOpLendPeerOft --slow --broadcast --private-key $(pk)

deploy-faucet:
	forge script script/DeployFaucet.s.sol:DeployFaucet --slow --broadcast --private-key $(pk) --verify

deploy-usdc:
	forge script script/DeployDummyUSDC.s.sol:DeployDummyUSDC --slow --broadcast --private-key $(pk) --verify

distribute-rewards-testnet:
	forge script script/DistributeRewardsTestnet.s.sol:DistributeRewardsTestnet --slow --broadcast --private-key $(pk)

abi:
	mkdir -p abis
	forge inspect ILendFactory abi --json > ./abis/IFactory.json
	forge inspect LendFactory abi --json > ./abis/Factory.json
	forge inspect LendOperation abi --json > ./abis/opLend.json
	forge inspect LendRewards abi --json > ./abis/Rewards.json
	forge inspect LendFaucet abi --json > ./abis/Faucet.json
