// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LendFaucet} from "../src/Faucet.sol";

contract DeployFaucet is Script {
    address usdc = address(0x54585517BBA619F74107581D0aF828EA40C25A7F);
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283);

    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        new LendFaucet(admin, usdc);

        vm.stopBroadcast();
    }
}
