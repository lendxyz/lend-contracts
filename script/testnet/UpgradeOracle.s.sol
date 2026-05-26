// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "../common/Constants.s.sol";

contract UpgradeOracle is Script, Constants {
    function run() external {
        vm.startBroadcast();

        address proxyAddress = address(0); // TODO: replace with actual deploy here
        Upgrades.upgradeProxy(proxyAddress, "PriceOracle.sol:PriceOracle", "");

        vm.stopBroadcast();
    }
}
