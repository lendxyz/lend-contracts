// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {FactoryUpgrade} from "script/common/FactoryUpgrade.s.sol";
import {FactoryUpgradeManifest} from "script/common/FactoryUpgradeManifest.s.sol";
import {LendMultisig} from "script/common/LendMultisig.s.sol";
import {IDiamondCut} from "src/Factory/interfaces/IDiamondCut.sol";
import {IERC173} from "src/Factory/interfaces/IERC173.sol";

/// @notice Upgrades the mainnet factory through the Lend Safe, one forge run each:
///         1. `DeployFacetUpgrade` (run with `--ledger`) deploys the facets and the init contract of the upgrade.
///         2. `ProposeFacetUpgrade` (run WITHOUT `--ledger`, `LEDGER_HD_PATH` set, `--sender` the Safe owner) proposes
///            the diamond cut, init included, as a single Safe transaction.
///         The cut is computed from the build (`FactoryUpgrade`); both runs abort before broadcasting unless it matches
///         `FactoryUpgradeManifest` and passes the fork simulation.
abstract contract MainnetFactoryUpgrade is Script, FactoryUpgradeManifest {
    /// @dev Plan of the upgrade, checked against the manifest, the storage layout and the fork simulation.
    function _checkedPlan()
        internal
        returns (FactoryUpgrade.Plan memory p, FactoryUpgrade.Manifest memory m, bool empty)
    {
        require(block.chainid == 1, "Run on Ethereum mainnet");

        FactoryUpgrade.Facet[] memory facets = FactoryUpgrade.facets();
        m = manifest();
        p = FactoryUpgrade.plan(MAINNET_FACTORY, facets, m);
        FactoryUpgrade.describe(p, m);
        if (FactoryUpgrade.isEmpty(p)) return (p, m, true);

        FactoryUpgrade.checkManifest(p, m);
        FactoryUpgrade.checkStorageLayout();
        if (!vm.envOr("SKIP_TESTNET_CHECK", false)) {
            FactoryUpgrade.requireMatchesBuild("sepolia", TESTNET_FACTORY, facets);
        }
        FactoryUpgrade.simulate(p, m, facets);
    }
}

contract DeployFacetUpgrade is MainnetFactoryUpgrade {
    function run() public {
        (FactoryUpgrade.Plan memory p,, bool empty) = _checkedPlan();
        if (empty) return;

        if (!FactoryUpgrade.hasPendingDeployments(p)) {
            console.log("Nothing to deploy: run ProposeFacetUpgrade");
            return;
        }

        vm.startBroadcast();
        FactoryUpgrade.deploy(p);
        vm.stopBroadcast();
    }
}

contract ProposeFacetUpgrade is MainnetFactoryUpgrade {
    function run() public {
        (FactoryUpgrade.Plan memory p,, bool empty) = _checkedPlan();
        if (empty) return;

        require(!FactoryUpgrade.hasPendingDeployments(p), "Facets or init not deployed: run DeployFacetUpgrade first");
        require(IERC173(MAINNET_FACTORY).owner() == LendMultisig.SAFE, "Factory is not owned by the Lend Safe");

        vm.startBroadcast();
        LendMultisig.proposeTransaction(
            MAINNET_FACTORY, abi.encodeCall(IDiamondCut.diamondCut, (p.cut, p.init, p.initCalldata))
        );
        vm.stopBroadcast();
    }
}
