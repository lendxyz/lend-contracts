# Lend smart contracts

Smart contracts for lend.xyz using Foundry

## Documentation

https://book.getfoundry.sh/

## Usage

### Install forge if not already installed

```shell
$ make install
```

### Compile contracts

```shell
$ make build
```

### Test and tests coverage

```shell
$ make tests
$ make coverage
```

### Format

```shell
$ make fmt
```

### Deploy

```shell
$ make deploy rpc=[your_rpc_url] pk=[your_private_key]
```

### Sync dependencies

```shell
$ make remappings
```

### Clean cache

```shell
$ make clean
```

### Help

```shell
$ make help
```

## Deployed contracts

### Testnet

#### Ethereum Sepolia

Chain id: 11155111
LayerZero endpoint: 40161

- [https://sepolia.etherscan.io/address/0x749ff163c2B32FF018D3c2a8213BDEbe86161A33](Factory):

Contract Address: `0xcC90663A4f20A41492e9e014f2012F9F48f73EF1`
Deploy block: `8518596`

- [https://sepolia.etherscan.io/address/0x749ff163c2B32FF018D3c2a8213BDEbe86161A33](Rewards):

Contract Address: `0x749ff163c2B32FF018D3c2a8213BDEbe86161A33`
Deploy block: `8661486`

#### Base Sepolia

Chain id: 84532
LayerZero endpoint: 40245

- [https://sepolia.basescan.org/address/0x7D8FC44B9D6562A5a1DBc76Bf693D0DF679028f6](Rewards):

Contract Address: `0x7D8FC44B9D6562A5a1DBc76Bf693D0DF679028f6`
Deploy block: `27757471`

#### Arbitrum Sepolia

Chain id: 421614
LayerZero endpoint: 40231

- [https://sepolia.arbiscan.io/address/0x7101aE81F8EBfa0ecAA806033aae64BdC0817c35](Rewards):

Contract Address: `0x7101aE81F8EBfa0ecAA806033aae64BdC0817c35`
Deploy block: `171526449`
