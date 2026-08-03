// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {LendRestitution} from "../../src/Restitution.sol";
import {RestitutionTest} from "./Restitution.t.sol";

contract RestitutionProxyTest is Test, RestitutionTest {
    function test_UpgradeProxy() public {
        Options memory opts;
        Upgrades.validateUpgrade("Restitution.sol:LendRestitution", opts);
    }

    function test_ProxyPointsAtASeparateImplementation() public view {
        address implementation = Upgrades.getImplementationAddress(address(restitution));

        assertTrue(implementation != address(0));
        assertTrue(implementation != address(restitution));
    }

    function test_UpgradeByOwnerPreservesState() public {
        createOpRestitution();

        vm.prank(user);
        restitution.claimRestitution(opId, 100_000e6);

        address newImplementation = address(new LendRestitution());

        vm.prank(admin);
        restitution.upgradeToAndCall(newImplementation, "");

        assertEq(Upgrades.getImplementationAddress(address(restitution)), newImplementation);
        assertEq(restitution.owner(), admin);
        assertEq(address(restitution.usdc()), address(usdc));
        assertEq(restitutionOpLend(opId), address(restOpLend));
        assertEq(restitutionShares(opId), totalSharesAmount);
        assertEq(restitutionUsdc(opId), restAmount);
        assertEq(restitution.claimedAmount(opId), 100_000e6);
        assertEq(restitution.opLendReturned(opId), 100_000e6);

        vm.prank(user2);
        restitution.claimRestitution(opId, 100_000e6);

        assertEq(restitution.claimedAmount(opId), 200_000e6);
    }

    function test_RevertWhen_UpgradeNotOwner() public {
        address newImplementation = address(new LendRestitution());

        vm.prank(user);
        vm.expectRevert(abi.encodeWithSelector(OwnableUpgradeable.OwnableUnauthorizedAccount.selector, user));
        restitution.upgradeToAndCall(newImplementation, "");
    }

    function test_RevertWhen_UpgradingImplementationDirectly() public {
        LendRestitution implementation = new LendRestitution();
        address newImplementation = address(new LendRestitution());

        vm.expectRevert(UUPSUpgradeable.UUPSUnauthorizedCallContext.selector);
        implementation.upgradeToAndCall(newImplementation, "");
    }
}
