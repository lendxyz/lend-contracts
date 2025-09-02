// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LendFactory} from "../src/Factory.sol";

contract DeployFactory is Script {
    LendFactory public factory;

    // ETH Mainnet addresses:
    address usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address eurUsdOracle = address(0xb49f677943BC038e9857d61E7d053CaA2C1734C1);
    address lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c);
    address backendSigner = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Backend signer to generate mint allowances
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // System owner - should be replaced with Lend multisig

    function setUp() public {}

    function run() public {
        vm.createSelectFork("mainnet");
        vm.startBroadcast();

        factory = new LendFactory(admin, usdc, eurUsdOracle, lzEndpoint, backendSigner);

        vm.stopBroadcast();
    }
}
