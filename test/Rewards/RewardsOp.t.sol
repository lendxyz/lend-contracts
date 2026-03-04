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

contract RewardsOpTest is Test, RewardsTest {
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

    function test_DistributeAndClaimMultipleOpRewards() public {
        createMultipleOpDistribution();

        bytes32[] memory proofEpoch1 = getProof(rewardUsers, rewardAmounts, rewIndex);
        bytes32[] memory proofEpoch2 = getProof(rewardUsers, rewardAmounts, rewIndex);
        bytes32[] memory proofEpoch3 = getProof(rewardUsers, rewardAmounts, rewIndex);

        LendRewards.ClaimData[] memory proofs = new LendRewards.ClaimData[](3);
        proofs[0] = LendRewards.ClaimData(1, ra, proofEpoch1);
        proofs[1] = LendRewards.ClaimData(2, ra, proofEpoch2);
        proofs[2] = LendRewards.ClaimData(3, ra, proofEpoch3);

        vm.startPrank(ru);
        vm.expectEmit(address(rewards));
        emit LendRewards.Claimed(opId, ru, ra * 3);
        rewards.claimOpEpochs(opId, ru, proofs);
        vm.stopPrank();

        assertEq(rewards.opClaimed(opId, 1, ru), true);
        assertEq(rewards.opClaimed(opId, 2, ru), true);
        assertEq(rewards.opClaimed(opId, 3, ru), true);
        assertEq(usdc.balanceOf(ru), ra * 3);
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
}
