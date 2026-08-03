// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {LendRestitution} from "../../src/Restitution.sol";
import {LendOperation} from "../../src/opLend.sol";
import {USDC} from "../../src/testnet/DummyUSDC.sol";
import {RestitutionTest} from "./Restitution.t.sol";

/// @dev Payable-less contract, used to force the ETH branch of `emergencyWithdraw` to fail.
contract EtherRejector {}

/// @dev Deterministic ETH sink. The `makeAddr` EOAs cannot be used: on a mainnet fork some of them
///      land on addresses that already carry code and forward the value on.
contract EtherReceiver {
    receive() external payable {}
}

contract RestitutionAdminTest is Test, RestitutionTest {
    uint256 otherId = 42;

    function unauthorized(address _caller) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _caller);
    }

    //********** initialize **********

    function test_InitializeSetsOwnerAndUsdc() public view {
        assertEq(restitution.owner(), admin);
        assertEq(address(restitution.usdc()), address(usdc));
    }

    function test_RevertWhen_InitializeCalledTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        restitution.initialize(user, address(usdc));
    }

    function test_RevertWhen_InitializingImplementation() public {
        LendRestitution implementation = new LendRestitution();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(admin, address(usdc));
    }

    //********** setUsdcAddress **********

    function test_SetUsdcAddress() public {
        USDC other = new USDC();

        vm.prank(admin);
        restitution.setUsdcAddress(address(other));

        assertEq(address(restitution.usdc()), address(other));
    }

    function test_RevertWhen_SetUsdcAddressNotOwner() public {
        vm.prank(user);
        vm.expectRevert(unauthorized(user));
        restitution.setUsdcAddress(user);
    }

    //********** restituteFunds **********

    function test_RestituteFunds() public {
        restOpLend = LendOperation(createOperation());

        vm.startPrank(admin);
        usdc.approve(address(restitution), type(uint256).max);

        vm.expectEmit(address(restitution));
        emit LendRestitution.RestitutionDistributed(opId, restAmount, 1e6);
        restitution.restituteFunds(opId, address(restOpLend), restAmount);
        vm.stopPrank();

        assertEq(restitutionOpLend(opId), address(restOpLend));
        assertEq(restitutionShares(opId), restOpLend.MAX_SUPPLY());
        assertEq(restitutionUsdc(opId), restAmount);
        assertEq(restitution.claimedAmount(opId), 0);
        assertEq(restitution.opLendReturned(opId), 0);

        assertEq(usdc.balanceOf(address(restitution)), restAmount);
        assertEq(usdc.balanceOf(admin), 0);
    }

    /// @dev sharesAmount is read from MAX_SUPPLY, not from the circulating supply.
    function test_RestituteFundsUsesMaxSupplyNotTotalSupply() public {
        LendOperation op = newOpLend(totalSharesAmount);
        giveShares(op, user, totalSharesAmount / 4);

        fundRestitution(otherId, address(op), restAmount);

        assertEq(op.totalSupply(), totalSharesAmount / 4);
        assertEq(restitutionShares(otherId), totalSharesAmount);
    }

    function test_RestituteFundsMultipleIds() public {
        createOpRestitution();

        LendOperation op = newOpLend(totalSharesAmount * 2);
        fundRestitution(otherId, address(op), restAmount / 2);

        assertEq(restitutionOpLend(opId), address(restOpLend));
        assertEq(restitutionUsdc(opId), restAmount);
        assertEq(restitutionShares(opId), totalSharesAmount);

        assertEq(restitutionOpLend(otherId), address(op));
        assertEq(restitutionUsdc(otherId), restAmount / 2);
        assertEq(restitutionShares(otherId), totalSharesAmount * 2);

        assertEq(usdc.balanceOf(address(restitution)), restAmount + restAmount / 2);
    }

    function test_RevertWhen_RestituteFundsOverwritesExistingId() public {
        createOpRestitution();

        LendOperation op = newOpLend(totalSharesAmount);
        deal(address(usdc), admin, restAmount);

        vm.prank(admin);
        vm.expectRevert(bytes("Cannot overwrite previous restitution"));
        restitution.restituteFunds(opId, address(op), restAmount);
    }

    function test_RevertWhen_RestituteFundsZeroOpLend() public {
        vm.startPrank(admin);
        usdc.approve(address(restitution), type(uint256).max);
        vm.expectRevert(bytes("OpLend cannot be address(0)"));
        restitution.restituteFunds(opId, address(0), restAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_RestituteFundsZeroAmount() public {
        LendOperation op = newOpLend(totalSharesAmount);

        vm.startPrank(admin);
        usdc.approve(address(restitution), type(uint256).max);
        vm.expectRevert(bytes("USDC amount cannot be zero"));
        restitution.restituteFunds(opId, address(op), 0);
        vm.stopPrank();
    }

    function test_RevertWhen_RestituteFundsNotOwner() public {
        LendOperation op = newOpLend(totalSharesAmount);
        deal(address(usdc), user, restAmount);

        vm.startPrank(user);
        usdc.approve(address(restitution), type(uint256).max);
        vm.expectRevert(unauthorized(user));
        restitution.restituteFunds(opId, address(op), restAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_RestituteFundsWithoutApproval() public {
        LendOperation op = newOpLend(totalSharesAmount);

        vm.startPrank(admin);
        usdc.approve(address(restitution), 0);
        vm.expectRevert();
        restitution.restituteFunds(opId, address(op), restAmount);
        vm.stopPrank();
    }

    function test_RevertWhen_RestituteFundsWithoutBalance() public {
        LendOperation op = newOpLend(totalSharesAmount);
        deal(address(usdc), admin, restAmount - 1);

        vm.startPrank(admin);
        usdc.approve(address(restitution), type(uint256).max);
        vm.expectRevert();
        restitution.restituteFunds(opId, address(op), restAmount);
        vm.stopPrank();
    }

    //********** withdrawRestitution **********

    function test_WithdrawRestitution() public {
        createOpRestitution();

        vm.expectEmit(address(restitution));
        emit LendRestitution.RestitutionFinished(opId);
        vm.prank(admin);
        restitution.withdrawRestitution(opId, user3);

        assertEq(usdc.balanceOf(user3), restAmount);
        assertEq(usdc.balanceOf(address(restitution)), 0);
        assertEq(restitution.claimedAmount(opId), restAmount);
        assertEq(restitution.opLendReturned(opId), totalSharesAmount);
        assertEq(restitution.availableRestitution(opId, user), 0);
    }

    function test_WithdrawRestitutionOnlyTakesTheRemainder() public {
        createOpRestitution();

        uint256 claimed = 100_000e6;
        vm.prank(user);
        restitution.claimRestitution(opId, claimed);

        vm.prank(admin);
        restitution.withdrawRestitution(opId, user3);

        assertEq(usdc.balanceOf(user3), restAmount - claimed);
        assertEq(usdc.balanceOf(address(restitution)), 0);
        assertEq(restitution.claimedAmount(opId), restAmount);
    }

    function test_RevertWhen_WithdrawRestitutionTwice() public {
        createOpRestitution();

        vm.startPrank(admin);
        restitution.withdrawRestitution(opId, user3);

        vm.expectRevert(bytes("Already claimed all"));
        restitution.withdrawRestitution(opId, user3);
        vm.stopPrank();
    }

    function test_RevertWhen_WithdrawRestitutionUnknownId() public {
        vm.prank(admin);
        vm.expectRevert(bytes("Already claimed all"));
        restitution.withdrawRestitution(otherId, user3);
    }

    function test_RevertWhen_WithdrawRestitutionNotOwner() public {
        createOpRestitution();

        vm.prank(user);
        vm.expectRevert(unauthorized(user));
        restitution.withdrawRestitution(opId, user);
    }

    function test_ClaimIsBlockedAfterWithdraw() public {
        createOpRestitution();

        vm.prank(admin);
        restitution.withdrawRestitution(opId, user3);

        vm.prank(user);
        vm.expectRevert(bytes("Restitution period ended"));
        restitution.claimRestitution(opId, userShares);
    }

    /// @dev Withdrawing one id must not disturb another id's accounting.
    function test_WithdrawRestitutionIsScopedToOneId() public {
        createOpRestitution();

        LendOperation op = newOpLend(totalSharesAmount);
        giveShares(op, user, totalSharesAmount);
        fundRestitution(otherId, address(op), restAmount);

        vm.prank(admin);
        restitution.withdrawRestitution(opId, user3);

        assertEq(restitution.claimedAmount(otherId), 0);
        assertEq(restitution.opLendReturned(otherId), 0);
        assertEq(restitution.availableRestitution(otherId, user), restAmount);
        assertEq(usdc.balanceOf(address(restitution)), restAmount);
    }

    //********** emergencyWithdraw **********

    function test_RevertWhen_EmergencyWithdrawUsdc() public {
        createOpRestitution();

        vm.prank(admin);
        vm.expectRevert(bytes("Cannot withdraw USDC, use withdrawRestitution instead"));
        restitution.emergencyWithdraw(address(usdc), user3);
    }

    function test_EmergencyWithdrawEth() public {
        address receiver = address(new EtherReceiver());
        vm.deal(receiver, 0); // the CREATE address can collide with a funded account on the fork
        vm.deal(address(restitution), 3 ether);

        vm.prank(admin);
        restitution.emergencyWithdraw(address(0), receiver);

        assertEq(address(restitution).balance, 0);
        assertEq(receiver.balance, 3 ether);
    }

    function test_RevertWhen_EmergencyWithdrawEthToRejectingReceiver() public {
        vm.deal(address(restitution), 1 ether);
        address rejector = address(new EtherRejector());

        vm.prank(admin);
        vm.expectRevert(bytes("Failed to send Ether"));
        restitution.emergencyWithdraw(address(0), rejector);
    }

    function test_EmergencyWithdrawErc20() public {
        USDC other = new USDC();
        other.mint(address(restitution), 1_234e6);

        vm.prank(admin);
        restitution.emergencyWithdraw(address(other), user3);

        assertEq(other.balanceOf(address(restitution)), 0);
        assertEq(other.balanceOf(user3), 1_234e6);
    }

    /// @dev The returned opLend shares sit in the contract and are recoverable by the admin.
    function test_EmergencyWithdrawReturnedShares() public {
        createOpRestitution();

        vm.prank(user);
        restitution.claimRestitution(opId, userShares);
        assertEq(restOpLend.balanceOf(address(restitution)), userShares);

        vm.startPrank(admin);
        factory.opLendWhitelistUser(opId, user3, true);
        restitution.emergencyWithdraw(address(restOpLend), user3);
        vm.stopPrank();

        assertEq(restOpLend.balanceOf(address(restitution)), 0);
        assertEq(restOpLend.balanceOf(user3), userShares);
    }

    /// @dev The USDC guard tracks the configured token, so repointing `usdc` unlocks the old one.
    function test_EmergencyWithdrawGuardFollowsUsdcAddress() public {
        createOpRestitution();
        USDC other = new USDC();

        vm.startPrank(admin);
        restitution.setUsdcAddress(address(other));
        restitution.emergencyWithdraw(address(usdc), user3);
        vm.stopPrank();

        assertEq(usdc.balanceOf(user3), restAmount);
    }

    function test_RevertWhen_EmergencyWithdrawNotOwner() public {
        vm.deal(address(restitution), 1 ether);

        vm.prank(user);
        vm.expectRevert(unauthorized(user));
        restitution.emergencyWithdraw(address(0), user);
    }

    //********** receive / fallback **********

    function test_ReceiveEth() public {
        vm.deal(address(this), 1 ether);

        (bool sent,) = address(restitution).call{value: 1 ether}("");

        assertTrue(sent);
        assertEq(address(restitution).balance, 1 ether);
    }

    function test_FallbackAcceptsEthWithCalldata() public {
        vm.deal(address(this), 1 ether);

        (bool sent,) = address(restitution).call{value: 1 ether}(hex"deadbeef");

        assertTrue(sent);
        assertEq(address(restitution).balance, 1 ether);
    }
}
