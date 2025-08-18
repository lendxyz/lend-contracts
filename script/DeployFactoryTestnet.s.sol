// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LendFactory} from "../src/Factory.sol";

contract DeployFactoryTestnet is Script {
    LendFactory public factory;

    // ETH Sepolia addresses:
    address EURUSDOracle = address(0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910);
    address lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    address usdc = address(0x73DC60bb3f14852fF727C6C67B187e61A7BB26E8);
    address backendSigner = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Backend signer to generate mint allowances
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Sepolia testnet deployer address

    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        factory = new LendFactory(admin, usdc, EURUSDOracle, lzEndpoint, backendSigner);

        vm.stopBroadcast();
    }
}
