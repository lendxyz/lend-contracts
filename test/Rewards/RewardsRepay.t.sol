// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {LendRewards} from "src/Rewards.sol";
import {RewardsTest} from "test/Rewards/Rewards.t.sol";

contract RewardsRepayTest is Test, RewardsTest {
    /// @dev Aave v3 Ethereum collateral: USDC has a 0 LTV, it cannot back a borrow.
    address constant WETH = 0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2;

    /// @dev Borrows `amount` USDC against WETH as `ru` (prank active), then spends it.
    function borrowUsdc(uint256 amount) internal {
        deal(WETH, ru, 1 ether);
        IERC20(WETH).approve(address(aavePool), 1 ether);

        aavePool.supply(WETH, 1 ether, ru, 0);
        aavePool.borrow(address(usdc), amount, 2, 0, ru);

        require(usdc.transfer(address(admin), amount), "transfer failed"); // simulate invest
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

        vm.startPrank(ru);
        borrowUsdc(ra);

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

        vm.startPrank(ru);
        borrowUsdc(ra / 2);

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
