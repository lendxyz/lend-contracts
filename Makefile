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
	@echo 'make deploy-factory rpc=[your_rpc_url] pk=[your_private_key]: deploy factory'
	@echo 'make upgrade-factory rpc=[your_rpc_url] pk=[your_private_key]: upgrade factory'
	@echo 'make deploy-oft-mainnet pk=[your_private_key]: deploy opLend OFT'
	@echo 'make deploy-oft-testnet pk=[your_private_key]: deploy opLend OFT on sepolia testnet'
	@echo 'make deploy-rewards-mainnet pk=[your_private_key]: deploy rewards contract'
	@echo 'make deploy-rewards-testnet pk=[your_private_key]: deploy rewards contract on sepolia testnet'
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
	forge script script/DeployFactory.s.sol:DeployFactory -vvvv --slow --broadcast --ledger --hd-paths "m/44'/60'/5'/0/0" --rpc-url https://ethereum-rpc.publicnode.com --verify

deploy-factory-testnet:
	forge script script/DeployFactory.s.sol:DeployFactory -vvvv --slow --broadcast --private-key $(pk) --rpc-url https://ethereum-sepolia-rpc.publicnode.com --verify

deploy-facet-upgrade-mainnet:
	forge script script/mainnet/DeployFacetUpgrade.s.sol:DeployFacetUpgrade -vvvv --slow --broadcast --ledger --hd-paths "m/44'/60'/5'/0/0" --rpc-url https://ethereum-rpc.publicnode.com --verify --ffi

upgrade-factory-testnet:
	forge script script/testnet/UpgradeFactory.s.sol:UpgradeFactoryTestnet -vvvv --slow --broadcast --private-key $(pk) --rpc-url https://ethereum-sepolia-rpc.publicnode.com --verify

deploy-oft-mainnet:
	# forge script script/mainnet/DeployOFT.s.sol:DeployOFT --slow --broadcast --ledger --hd-paths "m/44'/60'/5'/0/0" --rpc-url https://linea-rpc.publicnode.com --verify
    # If deploying on plume/blockscout setup
	forge script script/mainnet/DeployOFT.s.sol:DeployOFT --slow --broadcast --ledger --hd-paths "m/44'/60'/5'/0/0" --rpc-url https://rpc.plume.org --verify --verifier blockscout --verifier-url https://explorer.plume.org/api

deploy-oft-testnet:
	forge script script/testnet/DeployOFT.s.sol:DeployOFTTestnet --slow --broadcast --private-key $(pk) --verify

deploy-rewards-mainnet:
	forge script script/mainnet/DeployRewards.s.sol:DeployRewards --slow --broadcast --ledger --hd-paths "m/44'/60'/5'/0/0" --rpc-url https://base-rpc.publicnode.com --verify
    # If deploying on plume/blockscout setup
	# forge script script/mainnet/DeployRewards.s.sol:DeployRewards --slow --broadcast --ledger --hd-paths "m/44'/60'/5'/0/0" --rpc-url https://rpc.plume.org --verify --verifier blockscout --verifier-url https://explorer.plume.org/api

deploy-rewards-testnet:
	forge script script/testnet/DeployRewards.s.sol:DeployRewardsTestnet --slow --broadcast --private-key $(pk) --verify

set-peer-factory:
	forge script script/SetOpLendPeerFactory.s.sol:SetOpLendPeerFactory --slow --broadcast --private-key $(pk)

set-peer-oft-mainnet:
	forge script script/SetOpLendPeerOft.s.sol:SetOpLendPeerOft --slow --broadcast --ledger --hd-paths "m/44'/60'/5'/0/0" --rpc-url https://rpc.plume.org

set-peer-oft:
	forge script script/SetOpLendPeerOft.s.sol:SetOpLendPeerOft --slow --broadcast --private-key $(pk)

deploy-faucet:
	forge script script/testnet/DeployFaucet.s.sol:DeployFaucet --slow --broadcast --private-key $(pk) --verify

deploy-usdc:
	forge script script/testnet/DeployDummyUSDC.s.sol:DeployDummyUSDC --slow --broadcast --private-key $(pk) --verify

deploy-adapter-mainnet:
	forge script script/mainnet/Deploy1InchAdapter.s.sol:Deploy1InchAdapter --slow --broadcast --ledger --hd-paths "m/44'/60'/5'/0/0" --rpc-url https://ethereum-rpc.publicnode.com --verify

deploy-adapter-testnet:
	forge script script/testnet/Deploy1InchAdapter.s.sol:Deploy1InchAdapter --slow --broadcast --private-key $(pk) --verify

playground:
	forge script script/pg.s.sol:Playground

abi:
	mkdir -p abis
	forge inspect ILendFactory abi --json > ./abis/IFactory.json
	forge inspect LendOperation abi --json > ./abis/opLend.json
	forge inspect LendOperation bytecode > ./abis/opLend-bytecode.txt
	forge inspect LendRewards abi --json > ./abis/Rewards.json
	forge inspect LendFaucet abi --json > ./abis/Faucet.json
