// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {Factory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";

contract DeployScript is Script {
    LendDebt public dLend;
    Factory public factory;

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        dLend = new LendDebt();
        factory = new Factory(address(dLend));

        dLend.transferOwnership(address(factory));

        vm.stopBroadcast();
    }
}
