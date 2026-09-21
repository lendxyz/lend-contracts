// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {OpLendWallet} from "../../src/OpLendWallet.sol";
import {LendOperation} from "../../src/opLend.sol";
import {OpLendWalletTest} from "./OpLendWallet.t.sol";

contract OpLendWalletRedeemTest is Test, OpLendWalletTest {
    string redeemNonce = "rN-6Vv2qP";
    string redeemNonce2 = "rN-Kd91mZ";
    string transferNonce = "tN-Lp03sX";
    string transferNonce2 = "tN-Qa77bJ";

    function signTransfer(uint256 _pk, address _opLend, address _destination, string memory _nonce)
        public
        view
        returns (bytes memory)
    {
        bytes32 digest = keccak256(abi.encodePacked(_opLend, block.chainid, _destination, _nonce));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, hash);

        return abi.encodePacked(r, s, v);
    }

    //********** redeem **********

    function test_Redeem() public {
        LendOperation op = fundedWallet();
        bytes memory signature = getRedeemSignature(opId, user, redeemAmount, redeemNonce);

        vm.expectEmit(address(opLendWallet));
        emit OpLendWallet.Redeemed(opId, user, redeemAmount);
        vm.prank(user);
        opLendWallet.redeem(opId, user, redeemAmount, redeemNonce, signature);

        assertEq(op.balanceOf(user), redeemAmount);
        assertEq(op.balanceOf(address(opLendWallet)), walletShares - redeemAmount);
    }

    /// @dev The backend signature authorises the payout, not the caller: anybody can relay it.
    function test_RedeemIsPermissionless() public {
        LendOperation op = fundedWallet();
        bytes memory signature = getRedeemSignature(opId, user, redeemAmount, redeemNonce);

        vm.prank(user2);
        opLendWallet.redeem(opId, user, redeemAmount, redeemNonce, signature);

        assertEq(op.balanceOf(user), redeemAmount);
        assertEq(op.balanceOf(user2), 0);
    }

    function test_RedeemPartialThenRemainder() public {
        LendOperation op = fundedWallet();
        uint256 remainder = walletShares - redeemAmount;

        vm.startPrank(user);
        opLendWallet.redeem(
            opId, user, redeemAmount, redeemNonce, getRedeemSignature(opId, user, redeemAmount, redeemNonce)
        );
        opLendWallet.redeem(
            opId, user, remainder, redeemNonce2, getRedeemSignature(opId, user, remainder, redeemNonce2)
        );
        vm.stopPrank();

        assertEq(op.balanceOf(user), walletShares);
        assertEq(op.balanceOf(address(opLendWallet)), 0);
    }

    function test_RedeemWholeBalance() public {
        LendOperation op = fundedWallet();
        bytes memory signature = getRedeemSignature(opId, user, walletShares, redeemNonce);

        vm.prank(user);
        opLendWallet.redeem(opId, user, walletShares, redeemNonce, signature);

        assertEq(op.balanceOf(user), walletShares);
        assertEq(op.balanceOf(address(opLendWallet)), 0);
    }

    function test_RedeemOnlyTouchesTheRequestedOperation() public {
        LendOperation first = fundedWallet();
        LendOperation second = fundedOtherOp();

        bytes memory signature = getRedeemSignature(otherOpId, user2, redeemAmount, redeemNonce);

        vm.prank(user2);
        opLendWallet.redeem(otherOpId, user2, redeemAmount, redeemNonce, signature);

        assertEq(second.balanceOf(user2), redeemAmount);
        assertEq(second.balanceOf(address(opLendWallet)), walletShares - redeemAmount);
        assertEq(first.balanceOf(address(opLendWallet)), walletShares);
    }

    function test_RevertWhen_RedeemReplaysTheSameSignature() public {
        LendOperation op = fundedWallet();
        bytes memory signature = getRedeemSignature(opId, user, redeemAmount, redeemNonce);

        vm.startPrank(user);
        opLendWallet.redeem(opId, user, redeemAmount, redeemNonce, signature);

        vm.expectRevert();
        opLendWallet.redeem(opId, user, redeemAmount, redeemNonce, signature);
        vm.stopPrank();

        assertEq(op.balanceOf(user), redeemAmount);
    }

    /// @dev The nonce is burnt on use, a freshly signed payload cannot resurrect it.
    function test_RevertWhen_RedeemReusesNonceWithANewSignature() public {
        fundedWallet();

        vm.startPrank(user);
        opLendWallet.redeem(
            opId, user, redeemAmount, redeemNonce, getRedeemSignature(opId, user, redeemAmount, redeemNonce)
        );

        vm.expectRevert();
        opLendWallet.redeem(
            opId, user, redeemAmount * 2, redeemNonce, getRedeemSignature(opId, user, redeemAmount * 2, redeemNonce)
        );
        vm.stopPrank();
    }

    /// @dev Nonces are global to the wallet, they are not scoped per operation or per destination.
    function test_RevertWhen_RedeemReusesNonceOnAnotherOperation() public {
        fundedWallet();
        LendOperation second = fundedOtherOp();

        vm.prank(user);
        opLendWallet.redeem(
            opId, user, redeemAmount, redeemNonce, getRedeemSignature(opId, user, redeemAmount, redeemNonce)
        );

        vm.prank(user2);
        vm.expectRevert();
        opLendWallet.redeem(
            otherOpId, user2, redeemAmount, redeemNonce, getRedeemSignature(otherOpId, user2, redeemAmount, redeemNonce)
        );

        assertEq(second.balanceOf(user2), 0);
    }

    function test_RevertWhen_RedeemSignerIsNotTheBackend() public {
        fundedWallet();
        (, uint256 roguePk) = makeAddrAndKey("rogue");

        bytes memory signature = signRedeem(roguePk, block.chainid, opId, user, redeemAmount, redeemNonce);

        vm.prank(user);
        vm.expectRevert();
        opLendWallet.redeem(opId, user, redeemAmount, redeemNonce, signature);
    }

    function test_RevertWhen_RedeemAmountIsTampered() public {
        fundedWallet();
        bytes memory signature = getRedeemSignature(opId, user, redeemAmount, redeemNonce);

        vm.prank(user);
        vm.expectRevert();
        opLendWallet.redeem(opId, user, redeemAmount + 1, redeemNonce, signature);
    }

    function test_RevertWhen_RedeemDestinationIsTampered() public {
        fundedWallet();
        bytes memory signature = getRedeemSignature(opId, user, redeemAmount, redeemNonce);

        vm.prank(user2);
        vm.expectRevert();
        opLendWallet.redeem(opId, user2, redeemAmount, redeemNonce, signature);
    }

    function test_RevertWhen_RedeemOpIdIsTampered() public {
        fundedWallet();
        fundedOtherOp();

        bytes memory signature = getRedeemSignature(opId, user2, redeemAmount, redeemNonce);

        vm.prank(user2);
        vm.expectRevert();
        opLendWallet.redeem(otherOpId, user2, redeemAmount, redeemNonce, signature);
    }

    function test_RevertWhen_RedeemSignatureIsForAnotherChain() public {
        fundedWallet();
        bytes memory signature = signRedeem(backendSignerPk, block.chainid + 1, opId, user, redeemAmount, redeemNonce);

        vm.prank(user);
        vm.expectRevert();
        opLendWallet.redeem(opId, user, redeemAmount, redeemNonce, signature);
    }

    function test_RevertWhen_RedeemSignatureLengthIsInvalid() public {
        fundedWallet();
        bytes memory signature = getRedeemSignature(opId, user, redeemAmount, redeemNonce);

        vm.startPrank(user);

        vm.expectRevert(OpLendWallet.InvalidSignature.selector);
        opLendWallet.redeem(opId, user, redeemAmount, redeemNonce, new bytes(64));

        vm.expectRevert(OpLendWallet.InvalidSignature.selector);
        opLendWallet.redeem(opId, user, redeemAmount, redeemNonce, abi.encodePacked(signature, hex"00"));

        vm.stopPrank();
    }

    function test_RevertWhen_RedeemUnregisteredOpId() public {
        fundedWallet();
        bytes memory signature = getRedeemSignature(unknownOpId, user, redeemAmount, redeemNonce);

        vm.prank(user);
        vm.expectRevert(bytes("Invalid opId"));
        opLendWallet.redeem(unknownOpId, user, redeemAmount, redeemNonce, signature);
    }

    function test_RevertWhen_RedeemMoreThanBalance() public {
        fundedWallet();
        uint256 amount = walletShares + 1;
        bytes memory signature = getRedeemSignature(opId, user, amount, redeemNonce);

        vm.prank(user);
        vm.expectRevert(bytes("Not enough opLend"));
        opLendWallet.redeem(opId, user, amount, redeemNonce, signature);
    }

    /// @dev Plain `redeem` never whitelists: unknown destinations must go through `whitelistAndRedeem`.
    function test_RevertWhen_RedeemDestinationNotWhitelisted() public {
        LendOperation op = fundedWallet();
        assertFalse(op.whitelisted(user3));

        bytes memory signature = getRedeemSignature(opId, user3, redeemAmount, redeemNonce);

        vm.prank(user3);
        vm.expectRevert(bytes("Destination address is not whitelisted"));
        opLendWallet.redeem(opId, user3, redeemAmount, redeemNonce, signature);
    }

    //********** whitelistAndRedeem **********

    function test_WhitelistAndRedeem() public {
        LendOperation op = fundedWallet();
        assertFalse(op.whitelisted(user3));

        bytes memory tSignature = getTransferSignature(address(op), user3, transferNonce);
        bytes memory rSignature = getRedeemSignature(opId, user3, redeemAmount, redeemNonce);

        vm.expectEmit(address(opLendWallet));
        emit OpLendWallet.Redeemed(opId, user3, redeemAmount);
        vm.prank(user3);
        opLendWallet.whitelistAndRedeem(opId, user3, redeemAmount, transferNonce, tSignature, redeemNonce, rSignature);

        assertTrue(op.whitelisted(user3));
        assertEq(op.balanceOf(user3), redeemAmount);
        assertEq(op.balanceOf(address(opLendWallet)), walletShares - redeemAmount);
    }

    /// @dev Wallet and opLend keep separate nonce namespaces, the same string works for both signatures.
    function test_WhitelistAndRedeemAcceptsTheSameNonceForBothSignatures() public {
        LendOperation op = fundedWallet();

        bytes memory tSignature = getTransferSignature(address(op), user3, redeemNonce);
        bytes memory rSignature = getRedeemSignature(opId, user3, redeemAmount, redeemNonce);

        vm.prank(user3);
        opLendWallet.whitelistAndRedeem(opId, user3, redeemAmount, redeemNonce, tSignature, redeemNonce, rSignature);

        assertEq(op.balanceOf(user3), redeemAmount);
    }

    function test_WhitelistAndRedeemForAnAlreadyWhitelistedDestination() public {
        LendOperation op = fundedWallet();
        assertTrue(op.whitelisted(user));

        bytes memory tSignature = getTransferSignature(address(op), user, transferNonce);
        bytes memory rSignature = getRedeemSignature(opId, user, redeemAmount, redeemNonce);

        vm.prank(user);
        opLendWallet.whitelistAndRedeem(opId, user, redeemAmount, transferNonce, tSignature, redeemNonce, rSignature);

        assertTrue(op.whitelisted(user));
        assertEq(op.balanceOf(user), redeemAmount);
    }

    function test_WhitelistAndRedeemLeavesTheDestinationWhitelistedForLaterRedeems() public {
        LendOperation op = fundedWallet();

        bytes memory tSignature = getTransferSignature(address(op), user3, transferNonce);
        bytes memory rSignature = getRedeemSignature(opId, user3, redeemAmount, redeemNonce);

        vm.prank(user3);
        opLendWallet.whitelistAndRedeem(opId, user3, redeemAmount, transferNonce, tSignature, redeemNonce, rSignature);

        vm.prank(user3);
        opLendWallet.redeem(
            opId, user3, redeemAmount, redeemNonce2, getRedeemSignature(opId, user3, redeemAmount, redeemNonce2)
        );

        assertEq(op.balanceOf(user3), redeemAmount * 2);
    }

    function test_RevertWhen_WhitelistAndRedeemTransferSignerIsNotTheBackend() public {
        LendOperation op = fundedWallet();
        (, uint256 roguePk) = makeAddrAndKey("rogue");

        bytes memory tSignature = signTransfer(roguePk, address(op), user3, transferNonce);
        bytes memory rSignature = getRedeemSignature(opId, user3, redeemAmount, redeemNonce);

        vm.prank(user3);
        vm.expectRevert(LendOperation.InvalidSignature.selector);
        opLendWallet.whitelistAndRedeem(opId, user3, redeemAmount, transferNonce, tSignature, redeemNonce, rSignature);
    }

    function test_RevertWhen_WhitelistAndRedeemTransferSignatureIsForAnotherOpLend() public {
        LendOperation op = fundedWallet();
        LendOperation other = standaloneOpLend();

        bytes memory tSignature = getTransferSignature(address(other), user3, transferNonce);
        bytes memory rSignature = getRedeemSignature(opId, user3, redeemAmount, redeemNonce);

        vm.prank(user3);
        vm.expectRevert(LendOperation.InvalidSignature.selector);
        opLendWallet.whitelistAndRedeem(opId, user3, redeemAmount, transferNonce, tSignature, redeemNonce, rSignature);

        assertFalse(op.whitelisted(user3));
    }

    function test_RevertWhen_WhitelistAndRedeemTransferSignatureIsForAnotherDestination() public {
        LendOperation op = fundedWallet();

        bytes memory tSignature = getTransferSignature(address(op), user2, transferNonce);
        bytes memory rSignature = getRedeemSignature(opId, user3, redeemAmount, redeemNonce);

        vm.prank(user3);
        vm.expectRevert(LendOperation.InvalidSignature.selector);
        opLendWallet.whitelistAndRedeem(opId, user3, redeemAmount, transferNonce, tSignature, redeemNonce, rSignature);
    }

    function test_RevertWhen_WhitelistAndRedeemReusesTheTransferNonce() public {
        LendOperation op = fundedWallet();

        bytes memory tSignature = getTransferSignature(address(op), user3, transferNonce);
        bytes memory rSignature = getRedeemSignature(opId, user3, redeemAmount, redeemNonce);

        vm.prank(user3);
        opLendWallet.whitelistAndRedeem(opId, user3, redeemAmount, transferNonce, tSignature, redeemNonce, rSignature);

        bytes memory replayedTSignature = getTransferSignature(address(op), user2, transferNonce);
        bytes memory secondRSignature = getRedeemSignature(opId, user2, redeemAmount, redeemNonce2);

        vm.prank(user2);
        vm.expectRevert(LendOperation.InvalidSignature.selector);
        opLendWallet.whitelistAndRedeem(
            opId, user2, redeemAmount, transferNonce, replayedTSignature, redeemNonce2, secondRSignature
        );
    }

    function test_RevertWhen_WhitelistAndRedeemRedeemSignerIsNotTheBackend() public {
        LendOperation op = fundedWallet();
        (, uint256 roguePk) = makeAddrAndKey("rogue");

        bytes memory tSignature = getTransferSignature(address(op), user3, transferNonce);
        bytes memory rSignature = signRedeem(roguePk, block.chainid, opId, user3, redeemAmount, redeemNonce);

        vm.prank(user3);
        vm.expectRevert();
        opLendWallet.whitelistAndRedeem(opId, user3, redeemAmount, transferNonce, tSignature, redeemNonce, rSignature);

        assertFalse(op.whitelisted(user3));
    }

    /// @dev Signature checks run before the whitelisting call, a rejected redeem leaves no trace.
    function test_RevertWhen_WhitelistAndRedeemMoreThanBalance() public {
        LendOperation op = fundedWallet();
        uint256 amount = walletShares + 1;

        bytes memory tSignature = getTransferSignature(address(op), user3, transferNonce);
        bytes memory rSignature = getRedeemSignature(opId, user3, amount, redeemNonce);

        vm.prank(user3);
        vm.expectRevert(bytes("Not enough opLend"));
        opLendWallet.whitelistAndRedeem(opId, user3, amount, transferNonce, tSignature, redeemNonce, rSignature);

        assertFalse(op.whitelisted(user3));
    }

    function test_RevertWhen_WhitelistAndRedeemUnregisteredOpId() public {
        LendOperation op = fundedWallet();

        bytes memory tSignature = getTransferSignature(address(op), user3, transferNonce2);
        bytes memory rSignature = getRedeemSignature(unknownOpId, user3, redeemAmount, redeemNonce);

        vm.prank(user3);
        vm.expectRevert(bytes("Invalid opId"));
        opLendWallet.whitelistAndRedeem(
            unknownOpId, user3, redeemAmount, transferNonce2, tSignature, redeemNonce, rSignature
        );
    }
}
