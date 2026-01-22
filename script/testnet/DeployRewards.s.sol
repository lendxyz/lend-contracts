// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Constants} from "../common/Constants.s.sol";
import {LendRewards} from "../../src/Rewards.sol";
import {USDC} from "../../src/testnet/DummyUSDC.sol";

contract DeployRewardsTestnet is Script, Constants {
    function setUp() public {}

    function run() public {
        // vm.createSelectFork("arbitrum-sepolia");
        vm.createSelectFork("polygon-testnet");
        // vm.createSelectFork("sepolia");
        // vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("bsc-testnet");
        vm.startBroadcast();

        address usdcAddress = getTestnetUsdcAddress();

        // Deploy the implementation contract
        LendRewards implementation = new LendRewards();

        // Prepare initializer data
        bytes memory initData = abi.encodeCall(LendRewards.initialize, (tnOwner, usdcAddress));

        // Deploy the proxy and initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        USDC usdc = USDC(usdcAddress);
        usdc.approve(address(proxy), type(uint256).max);

        // DEMO DISTRIBUTION:
        // Mint mock usdc:
        // LendRewards rewards = LendRewards(payable(address(proxy)));
        // usdc.mint(admin, 112348592048);
        //
        // For operation:
        // Args: opId - epoch - merkle root - USDC amount
        // rewards.distributeOpRewards(1, 1, 0xa5a4433d1314c07de66b42825c90dfc7d26a8f8f3838ec0f3e63f7f811aecea9, 108232394698);
        // rewards.distributeOpRewards(2, 1, 0xc4a180aaa6528530a058f69760453d23df65cf383674ab7e28db7ef681db7c51, 4116197349);
        //
        // For referral rewards:
        // Args: epoch - merkle root - USDC amount
        // rewards.distributeRefRewards(1, 0xa5a4433d1314c07de66b42825c90dfc7d26a8f8f3838ec0f3e63f7f811aecea9, 108232394698);

        vm.stopBroadcast();
    }
}
