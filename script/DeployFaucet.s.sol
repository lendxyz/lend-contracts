// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LendFaucet} from "../src/Faucet.sol";
import {USDC} from "../src/DummyUSDC.sol";

contract DeployFaucet is Script {
    address usdcAddress = address(0x73DC60bb3f14852fF727C6C67B187e61A7BB26E8);
    USDC usdc = USDC(usdcAddress);
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283);

    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        LendFaucet faucet = new LendFaucet(admin, usdcAddress);
        usdc.mint(address(faucet), 100_000_000_000 * 10 ** 6);

        faucet.transferOwnership(address(0xE162c57907B2718F99af9b7bc7677a0b3285A7b1));

        vm.stopBroadcast();
    }
}
