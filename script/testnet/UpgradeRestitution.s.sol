// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "../common/Constants.s.sol";

contract UpgradeRestitution is Script, Constants {
    function run() external {
        address proxy = vm.envOr("RESTITUTION_PROXY", getTestnetRestitutionAddress());
        require(proxy != address(0), "Set RESTITUTION_PROXY or record the proxy in Constants.s.sol");

        vm.startBroadcast();
        Upgrades.upgradeProxy(proxy, "Restitution.sol:LendRestitution", "");
        vm.stopBroadcast();
    }
}
