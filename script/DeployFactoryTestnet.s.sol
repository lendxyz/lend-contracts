// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LendFactory} from "../src/Factory.sol";
import {DummyUSDC} from "../src/DummyUSDC.sol";

contract DeployFactoryTestnet is Script {
    LendFactory public factory;

    // ETH Sepolia addresses:
    address EURUSDOracle = address(0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910);
    address lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    address usdc = 0x54585517BBA619F74107581D0aF828EA40C25A7F;

    address admin = msg.sender; // System owner - should be replaced with Lend multisig

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        factory = new LendFactory(admin, usdc, EURUSDOracle, lzEndpoint);

        vm.stopBroadcast();
    }
}
