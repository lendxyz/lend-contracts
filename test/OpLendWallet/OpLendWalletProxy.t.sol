// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {OpLendWallet} from "../../src/OpLendWallet.sol";
import {LendOperation} from "../../src/opLend.sol";
import {OpLendWalletTest} from "./OpLendWallet.t.sol";

contract OpLendWalletProxyTest is Test, OpLendWalletTest {
    string upgradeNonce = "uN-8Hs21c";
    string upgradeNonce2 = "uN-4Tz90d";

    function test_UpgradeProxy() public {
        Options memory opts;
        Upgrades.validateUpgrade("OpLendWallet.sol:OpLendWallet", opts);
    }

    function test_ProxyPointsAtASeparateImplementation() public view {
        address implementation = Upgrades.getImplementationAddress(address(opLendWallet));

        assertTrue(implementation != address(0));
        assertTrue(implementation != address(opLendWallet));
    }

    function test_UpgradeByOwnerPreservesState() public {
        LendOperation op = fundedWallet();

        vm.prank(user);
        opLendWallet.redeem(
            opId, user, redeemAmount, upgradeNonce, getRedeemSignature(opId, user, redeemAmount, upgradeNonce)
        );

        address newImplementation = address(new OpLendWallet());

        vm.prank(admin);
        opLendWallet.upgradeToAndCall(newImplementation, "");

        assertEq(Upgrades.getImplementationAddress(address(opLendWallet)), newImplementation);
        assertEq(opLendWallet.owner(), admin);

        // The burnt nonce survives the upgrade.
        vm.prank(user);
        vm.expectRevert();
        opLendWallet.redeem(
            opId, user, redeemAmount, upgradeNonce, getRedeemSignature(opId, user, redeemAmount, upgradeNonce)
        );

        // So do the operation registry and the backend signer.
        vm.prank(user);
        opLendWallet.redeem(
            opId, user, redeemAmount, upgradeNonce2, getRedeemSignature(opId, user, redeemAmount, upgradeNonce2)
        );

        assertEq(op.balanceOf(user), redeemAmount * 2);
        assertEq(op.balanceOf(address(opLendWallet)), walletShares - redeemAmount * 2);
    }

    function test_RevertWhen_UpgradeNotOwner() public {
        address newImplementation = address(new OpLendWallet());

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        opLendWallet.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_UpgradingImplementationDirectly() public {
        OpLendWallet implementation = new OpLendWallet();
        address newImplementation = address(new OpLendWallet());

        vm.expectRevert(UUPSUpgradeable.UUPSUnauthorizedCallContext.selector);
        implementation.upgradeToAndCall(newImplementation, "");
    }
}
