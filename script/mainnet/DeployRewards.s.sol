// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendRewards} from "../../src/Rewards.sol";
import {Constants} from "../common/Constants.s.sol";

contract DeployRewards is Script, Constants {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new LendRewards(mnFactArgs.admin, mnFactArgs.usdc);

        vm.stopBroadcast();
    }
}
