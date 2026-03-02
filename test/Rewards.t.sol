// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {TestBase} from "./TestBase.t.sol";
import {MerkleHelper} from "./MerkleHelper.sol";

contract RewardsTest is Test, TestBase, MerkleHelper {
    function setUp() public override(TestBase) {
        super.setUp();
        deal(address(usdc), address(admin), initialUsdcBalance);
    }

    function test_DistributeAndClaimOpRewards() public {
        bytes32 root = getRoot(rewardUsers, rewardAmounts);
        uint256 totalAllocation = 600e6;
        uint256 epoch = 1;
        uint256 opId = 1;

        // Distribute
        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation);
        rewards.distributeOpRewards(opId, epoch, root, totalAllocation);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(rewards)), totalAllocation);

        // Claim [cite: 39]
        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, 2);

        address ru = rewardUsers[2];
        uint256 ra = rewardAmounts[2];

        vm.prank(ru);
        rewards.claimOpEpoch(opId, ru, epoch, ra, proof);

        assertEq(usdc.balanceOf(ru), ra);
    }
}
