// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {FactoryUpgrade} from "script/common/FactoryUpgrade.s.sol";
import {FactoryUpgradeManifest} from "script/common/FactoryUpgradeManifest.s.sol";
import {IDiamondCut} from "src/Factory/interfaces/IDiamondCut.sol";

/// @notice Upgrades the Sepolia factory to the build, from its owner. Aborts before broadcasting unless the computed cut
///         matches `FactoryUpgradeManifest` and passes the fork simulation.
contract UpgradeFactoryTestnet is Script, FactoryUpgradeManifest {
    function run() public {
        require(block.chainid == 11155111, "Run on Sepolia");

        FactoryUpgrade.Facet[] memory facets = FactoryUpgrade.facets();
        FactoryUpgrade.Manifest memory m = manifest();
        FactoryUpgrade.Plan memory p = FactoryUpgrade.plan(TESTNET_FACTORY, facets, m);
        FactoryUpgrade.describe(p, m);
        if (FactoryUpgrade.isEmpty(p)) return;

        FactoryUpgrade.checkManifest(p, m);
        FactoryUpgrade.checkStorageLayout();
        FactoryUpgrade.simulate(p, m, facets);

        vm.startBroadcast();
        FactoryUpgrade.deploy(p);
        IDiamondCut(TESTNET_FACTORY).diamondCut(p.cut, p.init, p.initCalldata);
        vm.stopBroadcast();
    }
}
