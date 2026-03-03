// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "../common/Constants.s.sol";

contract UpgradeRewards is Script, Constants {
    function run() external {
        vm.startBroadcast();

        Upgrades.upgradeProxy(getTestnetRewardsAddress(), "Rewards.sol", "");

        vm.stopBroadcast();
    }
}
