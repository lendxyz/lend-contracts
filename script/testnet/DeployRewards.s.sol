// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendRewards} from "../../src/Rewards.sol";
import {USDC} from "../../src/testnet/DummyUSDC.sol";

contract DeployRewardsTestnet is Script {
    address ethUsdcAddr = address(0x73DC60bb3f14852fF727C6C67B187e61A7BB26E8); // mock USDC on ETH sepolia
    address baseUsdcAddr = address(0x8cE18070660B07e5392E6072463710BFEd16f92f); // mock USDC on Base sepolia
    address arbiUsdcAddr = address(0xd960fbD1217EF083bf1F56719515d5eDC89832E6); // mock USDC on Arbitrum sepolia
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Sepolia testnet deployer address

    function setUp() public {}

    function run() public {
        vm.createSelectFork("arbitrum-sepolia");
        // vm.createSelectFork("sepolia");
        // vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("bsc-sepolia");
        vm.startBroadcast();

        LendRewards rewards = new LendRewards(admin, arbiUsdcAddr);
        USDC usdc = USDC(arbiUsdcAddr);
        usdc.approve(address(rewards), type(uint256).max);

        // DEMO DISTRIBUTION:
        // ethUsdc.mint(admin, 112348592048);
        // Args: opId - epoch - merkle root - USDC amount
        // ethRewards.distributeRewards(1, 1, 0xa5a4433d1314c07de66b42825c90dfc7d26a8f8f3838ec0f3e63f7f811aecea9, 108232394698);
        // ethRewards.distributeRewards(2, 1, 0xc4a180aaa6528530a058f69760453d23df65cf383674ab7e28db7ef681db7c51, 4116197349);

        vm.stopBroadcast();
    }
}
