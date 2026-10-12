// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {OpLendWallet} from "src/OpLendWallet.sol";
import {LendOperation} from "src/opLend.sol";
import {OpLendWalletTest} from "test/OpLendWallet/OpLendWallet.t.sol";

contract OpLendWalletAdminTest is Test, OpLendWalletTest {
    function unauthorized(address _caller) internal pure returns (bytes memory) {
        return abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, _caller);
    }

    //********** initialize **********

    function test_InitializeSetsOwner() public view {
        assertEq(opLendWallet.owner(), admin);
    }

    function test_RevertWhen_InitializeCalledTwice() public {
        vm.expectRevert(Initializable.InvalidInitialization.selector);
        opLendWallet.initialize(user, backendSigner);
    }

    function test_RevertWhen_InitializingImplementation() public {
        OpLendWallet implementation = new OpLendWallet();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(admin, backendSigner);
    }

    /// @dev `initialize` has no zero check while `setBackendSigner` does. A zero signer makes every
    ///      malformed signature valid, because `ecrecover` returns address(0) for those.
    function test_InitializeWithZeroSignerValidatesForgedSignatures() public {
        OpLendWallet implementation = new OpLendWallet();
        OpLendWallet wallet = OpLendWallet(
            payable(
                new ERC1967Proxy(address(implementation), abi.encodeCall(OpLendWallet.initialize, (admin, address(0))))
            )
        );

        (uint256 id, LendOperation op) = newFactoryOp();
        fiatFund(id, address(wallet), user, walletShares, testNonce);

        vm.prank(admin);
        wallet.registerOpLendAddress(id, address(op));

        bytes memory forged = abi.encodePacked(bytes32(0), bytes32(0), uint8(27));

        vm.prank(user2);
        wallet.redeem(id, user, redeemAmount, testNonce2, forged);

        assertEq(op.balanceOf(user), redeemAmount);
    }

    //********** setBackendSigner **********

    function test_SetBackendSignerAcceptsTheNewSigner() public {
        LendOperation op = fundedWallet();
        (address newSigner, uint256 newSignerPk) = makeAddrAndKey("new-backend");

        bytes memory signature = signRedeem(newSignerPk, block.chainid, opId, user, redeemAmount, testNonce2);

        vm.expectRevert();
        opLendWallet.redeem(opId, user, redeemAmount, testNonce2, signature);

        vm.prank(admin);
        opLendWallet.setBackendSigner(newSigner);

        opLendWallet.redeem(opId, user, redeemAmount, testNonce2, signature);

        assertEq(op.balanceOf(user), redeemAmount);
    }

    function test_SetBackendSignerRejectsThePreviousSigner() public {
        fundedWallet();
        (address newSigner,) = makeAddrAndKey("new-backend");

        bytes memory signature = getRedeemSignature(opId, user, redeemAmount, testNonce2);

        vm.prank(admin);
        opLendWallet.setBackendSigner(newSigner);

        vm.expectRevert();
        opLendWallet.redeem(opId, user, redeemAmount, testNonce2, signature);
    }

    function test_RevertWhen_SetBackendSignerZero() public {
        vm.prank(admin);
        vm.expectRevert(bytes("Signer cannot be zero address"));
        opLendWallet.setBackendSigner(address(0));
    }

    function test_RevertWhen_SetBackendSignerNotOwner() public {
        vm.prank(user);
        vm.expectRevert(unauthorized(user));
        opLendWallet.setBackendSigner(user);
    }

    //********** registerOpLendAddress **********

    function test_RegisterOpLendAddressEnablesRedeem() public {
        (uint256 id, LendOperation op) = newFactoryOp();
        fiatFund(id, address(opLendWallet), user, walletShares, testNonce);

        vm.prank(admin);
        vm.expectRevert(bytes("Invalid opId"));
        opLendWallet.adminRedeem(id, user, redeemAmount);

        registerOp(id, address(op));

        vm.prank(admin);
        opLendWallet.adminRedeem(id, user, redeemAmount);

        assertEq(op.balanceOf(user), redeemAmount);
    }

    function test_RegisterOpLendAddressOverwritesPreviousMapping() public {
        LendOperation first = fundedWallet();
        (uint256 secondId, LendOperation second) = newFactoryOp();
        fiatFund(secondId, address(opLendWallet), user2, walletShares, testNonce2);

        registerOp(opId, address(second));

        vm.prank(admin);
        opLendWallet.adminRedeem(opId, user2, redeemAmount);

        assertEq(second.balanceOf(user2), redeemAmount);
        assertEq(second.balanceOf(address(opLendWallet)), walletShares - redeemAmount);
        assertEq(first.balanceOf(address(opLendWallet)), walletShares);
    }

    function test_RevertWhen_RegisterOpLendAddressIsNotAContract() public {
        address noCode = makeAddr("no-code");
        assertEq(noCode.code.length, 0);

        vm.startPrank(admin);

        vm.expectRevert(bytes("Provided address is not a contract"));
        opLendWallet.registerOpLendAddress(opId, noCode);

        vm.expectRevert(bytes("Provided address is not a contract"));
        opLendWallet.registerOpLendAddress(opId, address(0));

        vm.stopPrank();
    }

    function test_RevertWhen_RegisterOpLendAddressNotOwner() public {
        (, LendOperation op) = newFactoryOp();

        vm.prank(user);
        vm.expectRevert(unauthorized(user));
        opLendWallet.registerOpLendAddress(opId, address(op));
    }

    //********** registerOpLendAddresses **********

    function test_RegisterOpLendAddressesRegistersEveryId() public {
        (uint256 firstId, LendOperation first) = newFactoryOp();
        (uint256 secondId, LendOperation second) = newFactoryOp();

        fiatFund(firstId, address(opLendWallet), user, walletShares, testNonce);
        fiatFund(secondId, address(opLendWallet), user2, walletShares, testNonce2);

        uint256[] memory ids = new uint256[](2);
        address[] memory ops = new address[](2);
        ids[0] = firstId;
        ids[1] = secondId;
        ops[0] = address(first);
        ops[1] = address(second);

        vm.startPrank(admin);
        opLendWallet.registerOpLendAddresses(ids, ops);

        opLendWallet.adminRedeem(firstId, user, redeemAmount);
        opLendWallet.adminRedeem(secondId, user2, redeemAmount);
        vm.stopPrank();

        assertEq(first.balanceOf(user), redeemAmount);
        assertEq(second.balanceOf(user2), redeemAmount);
    }

    function test_RegisterOpLendAddressesOverwritesPreviousMapping() public {
        LendOperation first = fundedWallet();
        (uint256 secondId, LendOperation second) = newFactoryOp();
        fiatFund(secondId, address(opLendWallet), user2, walletShares, testNonce2);

        uint256[] memory ids = new uint256[](1);
        address[] memory ops = new address[](1);
        ids[0] = opId;
        ops[0] = address(second);

        vm.startPrank(admin);
        opLendWallet.registerOpLendAddresses(ids, ops);
        opLendWallet.adminRedeem(opId, user2, redeemAmount);
        vm.stopPrank();

        assertEq(second.balanceOf(user2), redeemAmount);
        assertEq(first.balanceOf(address(opLendWallet)), walletShares);
    }

    function test_RevertWhen_RegisterOpLendAddressesLengthMismatch() public {
        (, LendOperation op) = newFactoryOp();

        uint256[] memory ids = new uint256[](2);
        address[] memory ops = new address[](1);
        ids[0] = opId;
        ids[1] = otherOpId;
        ops[0] = address(op);

        vm.prank(admin);
        vm.expectRevert(bytes("Length missmatch"));
        opLendWallet.registerOpLendAddresses(ids, ops);
    }

    function test_RevertWhen_RegisterOpLendAddressesNotOwner() public {
        (, LendOperation op) = newFactoryOp();

        uint256[] memory ids = new uint256[](1);
        address[] memory ops = new address[](1);
        ids[0] = opId;
        ops[0] = address(op);

        vm.prank(user);
        vm.expectRevert(unauthorized(user));
        opLendWallet.registerOpLendAddresses(ids, ops);
    }

    //********** adminRedeem **********

    function test_AdminRedeem() public {
        LendOperation op = fundedWallet();

        vm.expectEmit(address(opLendWallet));
        emit OpLendWallet.AdminRedeemed(opId, user, redeemAmount);
        vm.prank(admin);
        opLendWallet.adminRedeem(opId, user, redeemAmount);

        assertEq(op.balanceOf(user), redeemAmount);
        assertEq(op.balanceOf(address(opLendWallet)), walletShares - redeemAmount);
    }

    function test_AdminRedeemWholeBalance() public {
        LendOperation op = fundedWallet();

        vm.prank(admin);
        opLendWallet.adminRedeem(opId, user, walletShares);

        assertEq(op.balanceOf(user), walletShares);
        assertEq(op.balanceOf(address(opLendWallet)), 0);
    }

    /// @dev `adminRedeem` bypasses the backend signature, not the opLend nonce namespace: a redeem
    ///      signature stays usable afterwards.
    function test_AdminRedeemDoesNotConsumeRedeemNonces() public {
        LendOperation op = fundedWallet();
        bytes memory signature = getRedeemSignature(opId, user, redeemAmount, testNonce2);

        vm.prank(admin);
        opLendWallet.adminRedeem(opId, user, redeemAmount);

        opLendWallet.redeem(opId, user, redeemAmount, testNonce2, signature);

        assertEq(op.balanceOf(user), redeemAmount * 2);
    }

    function test_RevertWhen_AdminRedeemUnregisteredOpId() public {
        fundedWallet();

        vm.prank(admin);
        vm.expectRevert(bytes("Invalid opId"));
        opLendWallet.adminRedeem(unknownOpId, user, redeemAmount);
    }

    function test_RevertWhen_AdminRedeemMoreThanBalance() public {
        fundedWallet();

        vm.prank(admin);
        vm.expectRevert(bytes("Not enough opLend"));
        opLendWallet.adminRedeem(opId, user, walletShares + 1);
    }

    function test_RevertWhen_AdminRedeemNotOwner() public {
        fundedWallet();

        vm.prank(user);
        vm.expectRevert(unauthorized(user));
        opLendWallet.adminRedeem(opId, user, redeemAmount);
    }

    /// @dev `adminRedeem` has no whitelisting step, the destination must already be whitelisted.
    function test_RevertWhen_AdminRedeemDestinationNotWhitelisted() public {
        LendOperation op = fundedWallet();
        assertFalse(op.whitelisted(user3));

        vm.prank(admin);
        vm.expectRevert(bytes("Destination address is not whitelisted"));
        opLendWallet.adminRedeem(opId, user3, redeemAmount);
    }

    /// @dev Shares reaching the wallet outside of `mint` (bridge-in aside) leave it un-whitelisted,
    ///      and the wallet cannot move them.
    function test_RevertWhen_AdminRedeemWalletNotWhitelisted() public {
        LendOperation op = standaloneOpLend();

        deal(address(op), address(opLendWallet), walletShares);
        registerOp(opId, address(op));

        vm.prank(admin);
        op.whitelistUserAdmin(user, true);

        vm.prank(admin);
        vm.expectRevert(bytes("Source address is not whitelisted"));
        opLendWallet.adminRedeem(opId, user, redeemAmount);
    }

    //********** receive / fallback **********

    function test_ReceiveEth() public {
        uint256 before = address(opLendWallet).balance;

        vm.prank(user);
        (bool ok,) = address(opLendWallet).call{value: 1 ether}("");

        assertTrue(ok);
        assertEq(address(opLendWallet).balance, before + 1 ether);
    }

    function test_FallbackAcceptsUnknownSelectorWithValue() public {
        uint256 before = address(opLendWallet).balance;

        vm.prank(user);
        (bool ok,) = address(opLendWallet).call{value: 1 ether}(abi.encodeWithSignature("notAFunction(uint256)", 1));

        assertTrue(ok);
        assertEq(address(opLendWallet).balance, before + 1 ether);
    }
}
