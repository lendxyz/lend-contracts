// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LendFactory} from "../src/Factory.sol";
import {USDC} from "../src/DummyUSDC.sol";

contract DeployFactoryTestnet is Script {
    LendFactory public factory;

    // ETH Sepolia addresses:
    address EURUSDOracle = address(0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910);
    address lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    address usdc = address(0x54585517BBA619F74107581D0aF828EA40C25A7F);

    address backendSigner = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Backend signer to generate mint allowances
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Sepolia testnet deployer address

    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        factory = new LendFactory(admin, usdc, EURUSDOracle, lzEndpoint, backendSigner);

        factory.createOperation("Villa Al Arima", 1000000000000, 1875000);
        factory.createOperation("Apartment Beluga", 1000000000000, 1875000);

        factory.startOperation(1);
        factory.startOperation(2);

        vm.stopBroadcast();
    }
}
