// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {OneInchAdapter} from "../../src/OneInchAdapter.sol";

contract Deploy1InchAdapter is Script {
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283);
    address aggregatorRouterV6 = address(0x111111125421cA6dc452d289314280a0f8842A65);

    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        new OneInchAdapter(admin, aggregatorRouterV6);

        vm.stopBroadcast();
    }
}
