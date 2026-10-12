# Lend smart contracts

Smart contracts for lend.xyz using Foundry

## Deployed contracts

See the [DEPLOYMENTS.md](DEPLOYMENTS.md) file

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

### Propose a multisig transaction

Call `LendMultisig.proposeTransaction(target, callData)` (`script/common/LendMultisig.s.sol`) inside `vm.startBroadcast()` to propose a call from the Lend Safe, signed with your Ledger. Run the script **without** `--ledger` (forge would hold the device that `cast` needs to sign), with your owner address as `--sender` and your derivation path in `LEDGER_HD_PATH`:

```shell
$ LEDGER_HD_PATH="m/44'/60'/0'/0/0" forge script [script] --sender [your_owner_address] --rpc-url [your_rpc_url] --broadcast
```

Without `--broadcast` the transaction is only logged. Scripts that also deploy contracts with the Ledger must do so in a separate run.

The mainnet upgrades do both runs: the first deploys with the Ledger, the second proposes the upgrade from the first run's broadcast, signed by the same account. Pass your derivation path with `hd` (default `m/44'/60'/5'/0/0` - aym's multisig signer):

```shell
$ make deploy-facet-upgrade-mainnet hd="m/44'/60'/0'/0/0"
$ make upgrade-rewards-mainnet hd="m/44'/60'/0'/0/0"   # also upgrade-restitution-mainnet, upgrade-oracle-mainnet, upgrade-oplend-wallet-mainnet
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
