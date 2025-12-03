// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {OneInchAdapter} from "../../src/OneInchAdapter.sol";
import {Constants} from "../common/Constants.s.sol";

contract Deploy1InchAdapter is Script, Constants {
    address aggregatorRouterV6 = address(0x111111125421cA6dc452d289314280a0f8842A65);

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new OneInchAdapter(multisigAddress, aggregatorRouterV6);

        vm.stopBroadcast();
    }
}
