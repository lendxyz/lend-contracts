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

[Factory](https://sepolia.etherscan.io/address/0x440C9415071A97be0fE2cE84522C3916907b638b)

- Contract Address: `0x440C9415071A97be0fE2cE84522C3916907b638b`

- Deploy block: `8748350`

[Rewards](https://sepolia.etherscan.io/address/0xca4f269541da4bd06f7a3e2a285942b4260db755)

- Contract Address: `0xca4f269541da4bd06f7a3e2a285942b4260db755`

- Deploy block: `8748171`

#### Base Sepolia

Chain id: 84532

LayerZero endpoint: 40245

[Rewards](https://sepolia.basescan.org/address/0x33658298Bcbc368078f2f6db968a9cD487645049)

- Contract Address: `0x33658298Bcbc368078f2f6db968a9cD487645049`

- Deploy block: `28278872`

#### Arbitrum Sepolia

- Chain id: 421614

- LayerZero endpoint: 40231

[Rewards](https://sepolia.arbiscan.io/address/0x7b74329c55686AdAf3dD51a611a46FC8B1A20A37)

- Contract Address: `0x7b74329c55686AdAf3dD51a611a46FC8B1A20A37`

- Deploy block: `172807420`
