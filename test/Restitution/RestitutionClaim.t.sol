// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {IERC20Errors} from "@openzeppelin/contracts/interfaces/draft-IERC6093.sol";
import {LendRestitution} from "../../src/Restitution.sol";
import {LendOperation} from "../../src/opLend.sol";
import {RestitutionTest} from "./Restitution.t.sol";

contract RestitutionClaimTest is Test, RestitutionTest {
    uint256 otherId = 42;

    //********** Happy paths **********

    function test_ClaimPartial() public {
        createOpRestitution();

        uint256 amount = 100_000e6;

        vm.expectEmit(address(restitution));
        emit LendRestitution.RestitutionClaimed(opId, user, amount, amount);
        vm.prank(user);
        restitution.claimRestitution(opId, amount);

        assertEq(usdc.balanceOf(user), amount);
        assertEq(usdc.balanceOf(address(restitution)), restAmount - amount);
        assertEq(restOpLend.balanceOf(user), userShares - amount);
        assertEq(restOpLend.balanceOf(address(restitution)), amount);
        assertEq(restitution.claimedAmount(opId), amount);
        assertEq(restitution.opLendReturned(opId), amount);
    }

    function test_ClaimAccumulatesAcrossCalls() public {
        createOpRestitution();

        vm.startPrank(user);
        restitution.claimRestitution(opId, 1e6);
        restitution.claimRestitution(opId, 2e6);
        restitution.claimRestitution(opId, 3e6);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user), 6e6);
        assertEq(restitution.claimedAmount(opId), 6e6);
        assertEq(restitution.opLendReturned(opId), 6e6);
        assertEq(restitution.availableRestitution(opId, user), userShares - 6e6);
    }

    /// @dev Draining the last share must settle the restitution instead of bricking the final claimer.
    function test_ClaimFullDrainEmitsFinished() public {
        createOpRestitution();

        vm.prank(user);
        restitution.claimRestitution(opId, userShares);

        vm.expectEmit(address(restitution));
        emit LendRestitution.RestitutionClaimed(opId, user2, userShares, userShares);
        vm.expectEmit(address(restitution));
        emit LendRestitution.RestitutionFinished(opId);
        vm.prank(user2);
        restitution.claimRestitution(opId, userShares);

        assertEq(restitution.claimedAmount(opId), restAmount);
        assertEq(restitution.opLendReturned(opId), totalSharesAmount);
        assertEq(usdc.balanceOf(address(restitution)), 0);
        assertEq(usdc.balanceOf(user), userShares);
        assertEq(usdc.balanceOf(user2), userShares);
        assertEq(restOpLend.balanceOf(address(restitution)), totalSharesAmount);
        assertEq(restitution.availableRestitution(opId, user), 0);
    }

    function test_ClaimAtNonUnityRate() public {
        LendOperation op = newOpLend(totalSharesAmount);
        giveShares(op, user, 400_000e6);
        fundRestitution(otherId, address(op), 250_000e6);

        vm.prank(user);
        restitution.claimRestitution(otherId, 400_000e6);

        // 250_000 USDC over 1_000_000 shares => 0.25 USDC per share.
        assertEq(usdc.balanceOf(user), 100_000e6);
        assertEq(restitution.claimedAmount(otherId), 100_000e6);
        assertEq(restitution.opLendReturned(otherId), 400_000e6);
    }

    /// @dev Smallest share amount that still prices above zero at a 1e-6 USDC/share rate.
    function test_ClaimSmallestNonZeroAmount() public {
        LendOperation op = newOpLend(totalSharesAmount);
        giveShares(op, user, 1e6);
        fundRestitution(otherId, address(op), 1e6);

        vm.prank(user);
        restitution.claimRestitution(otherId, 1e6);

        assertEq(usdc.balanceOf(user), 1);
        assertEq(restitution.claimedAmount(otherId), 1);
    }

    function test_ClaimIsScopedToOneId() public {
        createOpRestitution();

        LendOperation op = newOpLend(totalSharesAmount);
        giveShares(op, user, totalSharesAmount);
        fundRestitution(otherId, address(op), restAmount);

        vm.prank(user);
        restitution.claimRestitution(otherId, totalSharesAmount);

        assertEq(restitution.claimedAmount(otherId), restAmount);
        assertEq(restitution.opLendReturned(otherId), totalSharesAmount);
        assertEq(restitution.claimedAmount(opId), 0);
        assertEq(restitution.opLendReturned(opId), 0);
        assertEq(restitution.availableRestitution(opId, user), userShares);
    }

    function testFuzz_Claim(uint256 _amount) public {
        createOpRestitution();
        uint256 amount = bound(_amount, 1, userShares);

        vm.prank(user);
        restitution.claimRestitution(opId, amount);

        // The canonical fixture is funded 1:1, so USDC out always equals shares in.
        assertEq(usdc.balanceOf(user), amount);
        assertEq(restOpLend.balanceOf(user), userShares - amount);
        assertEq(restitution.claimedAmount(opId), amount);
        assertLe(restitution.claimedAmount(opId), restitutionUsdc(opId));
        assertLe(restitution.opLendReturned(opId), restitutionShares(opId));
    }

    function testFuzz_ClaimNeverOverpays(uint256 _usdcAmount, uint256 _shares, uint256 _amount) public {
        uint256 maxSupply = bound(_shares, 1e6, 1_000_000_000e6);
        uint256 usdcAmount = bound(_usdcAmount, 1e6, 10_000_000e6);
        uint256 amount = bound(_amount, 1, maxSupply);

        LendOperation op = newOpLend(maxSupply);
        giveShares(op, user, maxSupply);
        fundRestitution(otherId, address(op), usdcAmount);

        uint256 claimable = restitution.getUsdcPerOpLend(otherId, amount);
        vm.assume(claimable > 0);

        vm.prank(user);
        restitution.claimRestitution(otherId, amount);

        assertEq(usdc.balanceOf(user), claimable);
        assertLe(restitution.claimedAmount(otherId), usdcAmount);
    }

    //********** Reverts **********

    function test_RevertWhen_ClaimUnrestitutedOp() public {
        createOpRestitution();

        vm.prank(user);
        vm.expectRevert(bytes("Operation has not been restitued yet"));
        restitution.claimRestitution(otherId, 1e6);
    }

    function test_RevertWhen_ClaimExceedsBalance() public {
        createOpRestitution();

        vm.prank(user);
        vm.expectRevert(bytes("Not enough balance"));
        restitution.claimRestitution(opId, userShares + 1);
    }

    function test_RevertWhen_ClaimWithoutShares() public {
        createOpRestitution();

        vm.prank(user3);
        vm.expectRevert(bytes("Not enough balance"));
        restitution.claimRestitution(opId, 1e6);
    }

    function test_RevertWhen_ClaimZeroAmount() public {
        createOpRestitution();

        vm.prank(user);
        vm.expectRevert(bytes("Nothing to claim for this address"));
        restitution.claimRestitution(opId, 0);
    }

    /// @dev A share amount that prices below 1 USDC wei is rejected rather than burning the shares.
    function test_RevertWhen_ClaimRoundsToZero() public {
        LendOperation op = newOpLend(totalSharesAmount);
        giveShares(op, user, 1e6);
        fundRestitution(otherId, address(op), 1e6);

        assertEq(restitution.getUsdcPerOpLend(otherId, 1e6 - 1), 0);

        vm.prank(user);
        vm.expectRevert(bytes("Nothing to claim for this address"));
        restitution.claimRestitution(otherId, 1e6 - 1);
    }

    function test_RevertWhen_ClaimerNotWhitelisted() public {
        createOpRestitution();

        deal(address(restOpLend), user3, userShares);
        vm.prank(user3);
        restOpLend.approve(address(restitution), type(uint256).max);

        vm.prank(user3);
        vm.expectRevert(bytes("Source address is not whitelisted"));
        restitution.claimRestitution(opId, 1e6);
    }

    function test_RevertWhen_RestitutionContractNotWhitelisted() public {
        LendOperation op = newOpLend(totalSharesAmount);
        giveShares(op, user, totalSharesAmount);
        fundRestitution(otherId, address(op), restAmount);

        vm.prank(admin);
        op.whitelistUserAdmin(address(restitution), false);

        vm.prank(user);
        vm.expectRevert(bytes("Destination address is not whitelisted"));
        restitution.claimRestitution(otherId, 1e6);
    }

    function test_RevertWhen_ClaimWithoutApproval() public {
        createOpRestitution();

        vm.startPrank(admin);
        factory.opLendWhitelistUser(opId, user3, true);
        vm.stopPrank();
        deal(address(restOpLend), user3, userShares);

        vm.prank(user3);
        vm.expectRevert(
            abi.encodeWithSelector(IERC20Errors.ERC20InsufficientAllowance.selector, address(restitution), 0, 1e6)
        );
        restitution.claimRestitution(opId, 1e6);
    }

    function test_RevertWhen_ClaimAfterFinished() public {
        createOpRestitution();

        vm.prank(user);
        restitution.claimRestitution(opId, userShares);
        vm.prank(user2);
        restitution.claimRestitution(opId, userShares);

        vm.startPrank(admin);
        factory.opLendWhitelistUser(opId, user3, true);
        vm.stopPrank();
        deal(address(restOpLend), user3, userShares);

        vm.startPrank(user3);
        restOpLend.approve(address(restitution), type(uint256).max);
        vm.expectRevert(bytes("Restitution period ended"));
        restitution.claimRestitution(opId, 1e6);
        vm.stopPrank();
    }
}
