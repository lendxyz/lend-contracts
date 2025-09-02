// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendRewards} from "../src/Rewards.sol";

contract DeployRewards is Script {
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48); // USDC on ETH Mainnet
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // System owner - should be replaced with Lend multisig

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new LendRewards(admin, usdc);

        vm.stopBroadcast();
    }
}
