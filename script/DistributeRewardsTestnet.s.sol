// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LendRewards} from "../src/Rewards.sol";
import {USDC} from "../src/DummyUSDC.sol";

contract DistributeRewardsTestnet is Script {
    address ethUsdcAddr = address(0x73DC60bb3f14852fF727C6C67B187e61A7BB26E8); // mock USDC on ETH sepolia
    address baseUsdcAddr = address(0x8cE18070660B07e5392E6072463710BFEd16f92f); // mock USDC on Base sepolia
    address arbiUsdcAddr = address(0xd960fbD1217EF083bf1F56719515d5eDC89832E6); // mock USDC on Arbitrum sepolia

    address rewardsEth = address(0xCa4f269541dA4bd06f7a3e2a285942B4260db755);
    address rewardsBase = address(0x33658298Bcbc368078f2f6db968a9cD487645049);
    address rewardsArbi = address(0x7b74329c55686AdAf3dD51a611a46FC8B1A20A37);

    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Sepolia testnet deployer address

    function setUp() public {}

    function run() public {
        // vm.createSelectFork("sepolia");
        // vm.createSelectFork("base-sepolia");
        vm.createSelectFork("arbitrum-sepolia");
        vm.startBroadcast();

        // LendRewards rewards = LendRewards(payable(rewardsEth));
        // LendRewards rewards = LendRewards(payable(rewardsBase));
        LendRewards rewards = LendRewards(payable(rewardsArbi));

        // USDC usdc = USDC(ethUsdcAddr);
        // USDC usdc = USDC(baseUsdcAddr);
        USDC usdc = USDC(arbiUsdcAddr);

        if (usdc.allowance(admin, address(rewards)) < type(uint256).max) {
            usdc.approve(address(rewards), type(uint256).max);
        }

        usdc.mint(admin, 5360425102);
        rewards.distributeRewards(1, 2, 0x0cbe6415003ecb33da58fa24226bc19bb89880496730b825be77c1daf671d088, 1535491410);
        rewards.distributeRewards(2, 2, 0xb24080c5251c2fc92b189bcbf8f8d1efbe38ba4d5030aabbb5acf68bc5c32de0, 3824933692);

        vm.stopBroadcast();
    }
}
