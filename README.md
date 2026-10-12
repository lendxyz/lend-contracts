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
$ make upgrade-rewards-mainnet hd="m/44'/60'/0'/0/0"   # also upgrade-restitution-mainnet, upgrade-oracle-mainnet, upgrade-oplend-wallet-mainnet, upgrade-oplend-mainnet
```

### Upgradeable opLEND

opLEND are `BeaconProxy`s: upgrading a chain's beacon upgrades every opLEND of that chain at once. opLEND deployed before the beacons are standalone contracts (`src/legacy/opLend/LendOperationV1.sol`) and stay non-upgradeable.

- Ethereum: the factory owns the beacon. `createOperation` deploys a proxy, and `updateOpLendImplementation` (factory owner) deploys the beacon on its first call and upgrades it afterwards. `make deploy-facet-upgrade-mainnet` proposes both.
- Other chains: the LayerZero endpoint is an implementation immutable, so each chain has its own implementation and Safe-owned beacon. Deploy them once per chain with `make deploy-oplend-beacon-mainnet rpc=[your_rpc_url]`, add the beacon to `Constants.getOpLendBeaconAddress`, then `make deploy-oft-mainnet` deploys proxies behind it.
- Upgrade: give the new `LendOperation` an `@custom:oz-upgrades-from` annotation pointing at a copy of the current version in `src/legacy/opLend`, then run `make upgrade-oplend-mainnet` for each chain.

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
