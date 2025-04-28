// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";

contract DeployScript is Script {
    LendDebt public dLend;
    Factory public factory;

    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // ETH mainnet address

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        factory = new Factory(USDC);

        vm.stopBroadcast();
    }
}
