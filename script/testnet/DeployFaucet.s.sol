// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../common/Constants.s.sol";
import {LendFaucet} from "../../src/testnet/Faucet.sol";
import {USDC} from "../../src/testnet/DummyUSDC.sol";

contract DeployFaucet is Script, Constants {
    USDC usdc = USDC(dummyUsdc);

    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        LendFaucet faucet = new LendFaucet(testnetOwner, dummyUsdc);
        usdc.mint(address(faucet), 100_000_000_000 * 10 ** 6);

        faucet.transferOwnership(address(0xE162c57907B2718F99af9b7bc7677a0b3285A7b1));

        vm.stopBroadcast();
    }
}
