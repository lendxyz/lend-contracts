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

        usdc.transfer(address(admin), ra); // simulate invest

        (uint256 ob1, uint256 ob2) = rewards.getUSDCBalanceOwed(ru);
        uint256 owedAmountBefore = ob1 + ob2;

        vm.expectEmit(address(rewards));
        emit LendRewards.Claimed(opId, ru, ra);

        rewards.claimOpEpochAndRepay(opId, ru, epoch, ra, proof);

        (uint256 oa1, uint256 oa2) = rewards.getUSDCBalanceOwed(ru);
        uint256 owedAmountAfter = oa1 + oa2;

        vm.stopPrank();

        assertEq(rewards.opClaimed(opId, epoch, ru), true);
        assertGt(owedAmountBefore, owedAmountAfter);
        assertGt(ra, owedAmountAfter);
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

        usdc.transfer(address(admin), ra / 2); // simulate invest

        (uint256 ob1, uint256 ob2) = rewards.getUSDCBalanceOwed(ru);
        uint256 owedAmountBefore = ob1 + ob2;

        vm.expectEmit(address(rewards));
        emit LendRewards.Claimed(opId, ru, ra);

        rewards.claimOpEpochAndRepay(opId, ru, epoch, ra, proof);

        (uint256 oa1, uint256 oa2) = rewards.getUSDCBalanceOwed(ru);
        uint256 owedAmountAfter = oa1 + oa2;

        vm.stopPrank();

        assertEq(rewards.opClaimed(opId, epoch, ru), true);
        assertGt(owedAmountBefore, owedAmountAfter);
        assertGt(ra / 2, owedAmountAfter);
        assertEq(usdc.balanceOf(ru), (ra / 2) - 1); // -1 is because of the AAVE interest rate
    }
}
