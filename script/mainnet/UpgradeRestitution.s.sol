// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "script/common/Constants.s.sol";
import {UUPSSafeUpgrade} from "script/common/UUPSSafeUpgrade.s.sol";

abstract contract RestitutionProxyResolver is Script, Constants {
    function restitutionProxy() internal view returns (address) {
        address proxy = vm.envOr("RESTITUTION_PROXY", getMainnetRestitutionAddress());
        require(proxy != address(0), "Set RESTITUTION_PROXY or record the proxy in Constants.s.sol");
        return proxy;
    }
}

contract UpgradeRestitution is RestitutionProxyResolver {
    function run() external {
        vm.startBroadcast();

        Upgrades.upgradeProxy(restitutionProxy(), "Restitution.sol:LendRestitution", "");

        vm.stopBroadcast();
    }
}

/// @notice Step 1 of the Safe upgrade: run with `--ledger`.
contract DeployUUPSImplementation is UUPSSafeUpgrade {
    function run() external {
        _deployImplementation("Restitution.sol:LendRestitution");
    }
}

/// @notice Step 2 of the Safe upgrade: run without `--ledger`, with `LEDGER_HD_PATH` set.
contract ProposeUUPSUpgrade is UUPSSafeUpgrade, RestitutionProxyResolver {
    function run() external {
        _proposeUpgrade("UpgradeRestitution.s.sol", "Restitution.sol:LendRestitution", restitutionProxy());
    }
}
