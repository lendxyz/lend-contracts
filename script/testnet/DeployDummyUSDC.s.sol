// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {USDC} from "../../src/testnet/DummyUSDC.sol";

contract DeployDummyUSDC is Script {
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283);

    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        // vm.createSelectFork("arbitrum-sepolia");
        // vm.createSelectFork("bsc-testnet");
        // vm.createSelectFork("polygon-testnet");
        // vm.createSelectFork("base-sepolia");
        vm.startBroadcast();

        USDC usdc = new USDC();
        usdc.mint(admin, 1_000_000_000_000 * 10 ** 6);

        vm.stopBroadcast();
    }
}
