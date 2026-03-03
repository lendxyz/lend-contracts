// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {TestBase} from "./TestBase.t.sol";
import {MerkleHelper} from "./MerkleHelper.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {LendRewards} from "../src/Rewards.sol";

contract RewardsTest is Test, TestBase, MerkleHelper {
    uint256 totalAllocation = 600e6;
    uint256 epoch = 1;
    uint256 opId = 2;
    uint256 rewIndex = 2;
    address ru;
    uint256 ra;

    function createOpDistribution() public {
        bytes32 root = getRoot(rewardUsers, rewardAmounts);

        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation);
        rewards.distributeOpRewards(opId, epoch, root, totalAllocation);
        vm.stopPrank();
    }

    function createRefDistribution() public {
        bytes32 root = getRoot(rewardUsers, rewardAmounts);

        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation);
        rewards.distributeRefRewards(epoch, root, totalAllocation);
        vm.stopPrank();
    }

    function enableAaveModule() public {
        vm.prank(admin);
        rewards.setAaveAddressProvider(address(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e));
    }

    function setUp() public override(TestBase) {
        super.setUp();
        deal(address(usdc), address(admin), totalAllocation);

        ru = rewardUsers[rewIndex];
        ra = rewardAmounts[rewIndex];
    }

    function test_UpgradeProxy() public {
        Options memory opts;
        Upgrades.validateUpgrade("Rewards.sol:LendRewards", opts);
    }

    function test_DistributeAndClaimOpRewards() public {
        bytes32 root = getRoot(rewardUsers, rewardAmounts);

        // Distribute
        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation);
        vm.expectEmit(address(rewards));
        emit LendRewards.RewardsDistributed(opId, epoch, totalAllocation);
        rewards.distributeOpRewards(opId, epoch, root, totalAllocation);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(rewards)), totalAllocation);

        // Claim
        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

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

        // Distribute
        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation);
        vm.expectEmit(address(rewards));
        emit LendRewards.RefRewardsDistributed(epoch, totalAllocation);
        rewards.distributeRefRewards(epoch, root, totalAllocation);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(rewards)), totalAllocation);

        // Claim
        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        vm.expectEmit(address(rewards));
        emit LendRewards.ClaimedRef(ru, ra);
        rewards.claimRefEpoch(ru, epoch, ra, proof);
        vm.stopPrank();

        assertEq(rewards.refClaimed(epoch, ru), true);
        assertEq(usdc.balanceOf(ru), ra);
    }

    function test_CannotClaimMoreOpRewards() public {
        createOpDistribution();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        vm.expectRevert(bytes("Incorrect merkle proof"));
        rewards.claimOpEpoch(2, ru, 1, ra + 1, proof);
        vm.stopPrank();
    }

    function test_CannotClaimLessOpRewards() public {
        createOpDistribution();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        vm.expectRevert(bytes("Incorrect merkle proof"));
        rewards.claimOpEpoch(opId, ru, epoch, ra - 1, proof);
        vm.stopPrank();
    }

    function test_CannotClaimOpRewardsTwice() public {
        createOpDistribution();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        rewards.claimOpEpoch(opId, ru, epoch, ra, proof);
        vm.expectRevert(bytes("epoch already claimed for this user"));
        rewards.claimOpEpoch(opId, ru, epoch, ra, proof);
        vm.stopPrank();
    }

    function test_CannotClaimMoreRefRewards() public {
        createRefDistribution();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        vm.expectRevert(bytes("Incorrect merkle proof"));
        rewards.claimRefEpoch(ru, epoch, ra + 1, proof);
        vm.stopPrank();
    }

    function test_CannotClaimLessRefRewards() public {
        createRefDistribution();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        vm.expectRevert(bytes("Incorrect merkle proof"));
        rewards.claimRefEpoch(ru, epoch, ra - 1, proof);
        vm.stopPrank();
    }

    function test_CannotClaimRefRewardsTwice() public {
        createRefDistribution();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        rewards.claimRefEpoch(ru, epoch, ra, proof);
        vm.expectRevert(bytes("epoch already claimed for this user"));
        rewards.claimRefEpoch(ru, epoch, ra, proof);
        vm.stopPrank();
    }

    function test_AaveRepayNotInitialized() public {
        createOpDistribution();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        vm.expectRevert(bytes("AAVE module not initialized"));
        rewards.claimOpEpochAndRepay(opId, ru, epoch, ra, proof);
        vm.stopPrank();
    }

    function test_AaveRepayWithoutDebt() public {
        createOpDistribution();

        vm.prank(admin);
        rewards.setAaveAddressProvider(address(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e));
        
        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        vm.expectEmit(address(rewards));
        emit LendRewards.Claimed(opId, ru, ra);
        rewards.claimOpEpochAndRepay(opId, ru, epoch, ra, proof);
        vm.stopPrank();

        assertEq(rewards.opClaimed(opId, epoch, ru), true);
        assertEq(usdc.balanceOf(ru), ra);
    }
}
