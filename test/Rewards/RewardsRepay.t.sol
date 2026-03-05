// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {LendRewards} from "../../src/Rewards.sol";
import {RewardsTest} from "./Rewards.t.sol";

contract RewardsRepayTest is Test, RewardsTest {
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
        enableAaveModule();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        vm.startPrank(ru);
        vm.expectEmit(address(rewards));
        emit LendRewards.Claimed(opId, ru, ra);
        rewards.claimOpEpochAndRepay(opId, ru, epoch, ra, proof);
        vm.stopPrank();

        assertEq(rewards.opClaimed(opId, epoch, ru), true);
        assertEq(usdc.balanceOf(ru), ra);
    }

    function test_AaveRepayWithDebt() public {
        createOpDistribution();
        enableAaveModule();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        deal(address(usdc), ru, 500e6);

        vm.startPrank(ru);
        usdc.approve(address(aavePool), 500e6);

        aavePool.supply(address(usdc), 500e6, ru, 0);
        aavePool.borrow(address(usdc), ra, 2, 0, ru);

        require(usdc.transfer(address(admin), ra), "transfer failed"); // simulate invest

        vm.expectEmit(address(rewards));
        emit LendRewards.Claimed(opId, ru, ra);

        rewards.claimOpEpochAndRepay(opId, ru, epoch, ra, proof);

        (uint256 oa1, uint256 oa2) = rewards.getUsdcBalanceOwed(ru);
        uint256 owedAmountAfter = oa1 + oa2;

        vm.stopPrank();

        assertEq(rewards.opClaimed(opId, epoch, ru), true);
        assertApproxEqAbs(owedAmountAfter, 0, 5);
        assertEq(usdc.balanceOf(ru), 0);
    }

    function test_AaveRepayWithPartialDebt() public {
        createOpDistribution();
        enableAaveModule();

        bytes32[] memory proof = getProof(rewardUsers, rewardAmounts, rewIndex);

        deal(address(usdc), ru, 500e6);

        vm.startPrank(ru);
        usdc.approve(address(aavePool), 500e6);

        aavePool.supply(address(usdc), 500e6, ru, 0);
        aavePool.borrow(address(usdc), ra / 2, 2, 0, ru);

        require(usdc.transfer(address(admin), ra / 2), "transfer failed"); // simulate invest

        vm.expectEmit(address(rewards));
        emit LendRewards.Claimed(opId, ru, ra);

        rewards.claimOpEpochAndRepay(opId, ru, epoch, ra, proof);

        (uint256 oa1, uint256 oa2) = rewards.getUsdcBalanceOwed(ru);
        uint256 owedAmountAfter = oa1 + oa2;

        vm.stopPrank();

        assertEq(rewards.opClaimed(opId, epoch, ru), true);
        assertApproxEqAbs(owedAmountAfter, 0, 5);
        assertApproxEqAbs(usdc.balanceOf(ru), (ra / 2), 5);
    }
}
