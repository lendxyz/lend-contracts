# Legacy contracts

These are reference contracts used to evaluate storage layout safety during upgrades.

For every new upgrade, we need to keep a copy of the latest deployed implementation prior to the upgrade to check for storage collision.

More details [here](https://docs.openzeppelin.com/upgrades-plugins/foundry/foundry-upgrades#upgrade-a-proxy-or-beacon)
