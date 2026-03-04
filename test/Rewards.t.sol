// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {TestBase} from "./TestBase.t.sol";
import {MerkleHelper} from "./MerkleHelper.sol";
import {LendRewards} from "../src/Rewards.sol";
import {IPoolDataProvider, IPoolAddressesProvider, IPool} from "../src/interfaces/AaveInterfaces.sol";

contract RewardsTest is Test, TestBase, MerkleHelper {
    address aaveAddressProvider = address(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IPool aavePool = IPool(IPoolAddressesProvider(aaveAddressProvider).getPool());

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

    function createMultipleOpDistribution() public {
        bytes32 rootEpoch1 = getRoot(rewardUsers, rewardAmounts);
        bytes32 rootEpoch2 = getRoot(rewardUsers, rewardAmounts);
        bytes32 rootEpoch3 = getRoot(rewardUsers, rewardAmounts);

        deal(address(usdc), address(admin), totalAllocation * 3);

        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation * 3);
        rewards.distributeOpRewards(opId, 1, rootEpoch1, totalAllocation);
        rewards.distributeOpRewards(opId, 2, rootEpoch2, totalAllocation);
        rewards.distributeOpRewards(opId, 3, rootEpoch3, totalAllocation);
        vm.stopPrank();
    }

    function createMultipleRefDistribution() public {
        bytes32 rootEpoch1 = getRoot(rewardUsers, rewardAmounts);
        bytes32 rootEpoch2 = getRoot(rewardUsers, rewardAmounts);
        bytes32 rootEpoch3 = getRoot(rewardUsers, rewardAmounts);

        deal(address(usdc), address(admin), totalAllocation * 3);

        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation * 3);
        rewards.distributeRefRewards(1, rootEpoch1, totalAllocation);
        rewards.distributeRefRewards(2, rootEpoch2, totalAllocation);
        rewards.distributeRefRewards(3, rootEpoch3, totalAllocation);
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
        rewards.setAaveAddressProvider(aaveAddressProvider);
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
