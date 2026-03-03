// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {TestBase} from "./TestBase.t.sol";
import {MerkleHelper} from "./MerkleHelper.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {LendRewards as LendRewardsLegacy} from "../src/legacy/Rewards/RewardsV1.sol";
import {LendRewards} from "../src/Rewards.sol";

contract RewardsTest is Test, TestBase, MerkleHelper {
    function setUp() public override(TestBase) {
        super.setUp();
        deal(address(usdc), address(admin), 600e6);
    }

    function test_UpgradeProxy() public {
        Options memory opts;
        Upgrades.validateUpgrade("Rewards.sol:LendRewards", opts);
    }

    function test_DistributeAndClaimOpRewards() public {
        bytes32 root = getRoot(rewardUsers, rewardAmounts);
        uint256 totalAllocation = 600e6;
        uint256 epoch = 1;
        uint256 opId = 2;

        // Distribute
        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation);
        vm.expectEmit(address(rewards));
        emit LendRewards.RewardsDistributed(opId, epoch, totalAllocation);
        rewards.distributeOpRewards(opId, epoch, root, totalAllocation);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(rewards)), totalAllocation);

        // Claim
        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, 2);

        address ru = rewardUsers[2];
        uint256 ra = rewardAmounts[2];

        vm.startPrank(ru);
        vm.expectEmit(address(rewards));
        emit LendRewards.Claimed(opId, ru, ra);
        rewards.claimOpEpoch(opId, ru, epoch, ra, proof);
        vm.stopPrank();

        assertEq(rewards.opClaimed(opId, epoch, ru), true);
        assertEq(usdc.balanceOf(ru), ra);
    }

    function test_DistributeAndClaimRefRewards() public {
        bytes32 root = getRoot(rewardUsers, rewardAmounts);
        uint256 totalAllocation = 600e6;
        uint256 epoch = 1;

        // Distribute
        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation);
        vm.expectEmit(address(rewards));
        emit LendRewards.RefRewardsDistributed(epoch, totalAllocation);
        rewards.distributeRefRewards(epoch, root, totalAllocation);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(rewards)), totalAllocation);

        // Claim
        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, 2);

        address ru = rewardUsers[2];
        uint256 ra = rewardAmounts[2];

        vm.startPrank(ru);
        vm.expectEmit(address(rewards));
        emit LendRewards.ClaimedRef(ru, ra);
        rewards.claimRefEpoch(ru, epoch, ra, proof);
        vm.stopPrank();

        assertEq(rewards.refClaimed(epoch, ru), true);
        assertEq(usdc.balanceOf(ru), ra);
    }
}
