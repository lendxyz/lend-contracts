// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../common/Constants.s.sol";
import {USDC} from "../../src/testnet/DummyUSDC.sol";

contract DeployDummyUSDC is Script {
    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        // vm.createSelectFork("arbitrum-sepolia");
        // vm.createSelectFork("bsc-testnet");
        // vm.createSelectFork("polygon-testnet");
        // vm.createSelectFork("base-sepolia");
        vm.startBroadcast();

        USDC usdc = new USDC();
        usdc.mint(tnOwner, 1_000_000_000_000 * 10 ** 6);

        vm.stopBroadcast();
    }
}
