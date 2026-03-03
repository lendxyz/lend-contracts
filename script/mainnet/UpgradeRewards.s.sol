// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "../common/Constants.s.sol";
import {LendRewards} from "../../src/Rewards.sol";

contract UpgradeRewards is Script, Constants {
    function run() external {
        vm.startBroadcast();

        Upgrades.upgradeProxy(
            address(0), // replace with deployed proxy address
            "Rewards.sol",
            ""
        );

        vm.stopBroadcast();
    }
}
