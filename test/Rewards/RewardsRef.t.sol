// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {TestBase} from "../TestBase.t.sol";
import {MerkleHelper} from "../MerkleHelper.sol";
import {LendRewards} from "../../src/Rewards.sol";
import {IPoolDataProvider, IPoolAddressesProvider, IPool} from "../../src/interfaces/AaveInterfaces.sol";

import {RewardsTest} from "./Rewards.t.sol";

contract RewardsRefTest is Test, RewardsTest {
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

    function test_DistributeAndClaimMultipleRefRewards() public {
        createMultipleRefDistribution();

        bytes32[] memory proofEpoch1 = getProof(rewardUsers, rewardAmounts, rewIndex);
        bytes32[] memory proofEpoch2 = getProof(rewardUsers, rewardAmounts, rewIndex);
        bytes32[] memory proofEpoch3 = getProof(rewardUsers, rewardAmounts, rewIndex);

        LendRewards.ClaimData[] memory proofs = new LendRewards.ClaimData[](3);
        proofs[0] = LendRewards.ClaimData(1, ra, proofEpoch1);
        proofs[1] = LendRewards.ClaimData(2, ra, proofEpoch2);
        proofs[2] = LendRewards.ClaimData(3, ra, proofEpoch3);

        vm.startPrank(ru);
        vm.expectEmit(address(rewards));
        emit LendRewards.ClaimedRef(ru, ra * 3);
        rewards.claimRefEpochs(ru, proofs);
        vm.stopPrank();

        assertEq(rewards.refClaimed(1, ru), true);
        assertEq(rewards.refClaimed(2, ru), true);
        assertEq(rewards.refClaimed(3, ru), true);
        assertEq(usdc.balanceOf(ru), ra * 3);
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
}
