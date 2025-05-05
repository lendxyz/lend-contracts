// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LendFactory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";

contract DeployScript is Script {
    LendDebt public dLend;
    LendFactory public factory;

    address USDC = 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48; // ETH mainnet address
    address EURUSDOracle = 0xb49f677943BC038e9857d61E7d053CaA2C1734C1; // ETH mainnet address
    address USDCUSDOracle = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6; // ETH mainnet address
    address admin = msg.sender; // System owner - should be replaced with Lend multisig

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        factory = new LendFactory(admin, USDC, EURUSDOracle, USDCUSDOracle);

        vm.stopBroadcast();
    }
}
