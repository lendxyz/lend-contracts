// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {LendOperation} from "../../src/opLend.sol";
import {RestitutionTest} from "./Restitution.t.sol";

contract RestitutionViewTest is Test, RestitutionTest {
    uint256 otherId = 42;

    //********** getUsdcPerOpLend **********

    function test_GetUsdcPerOpLendUnknownId() public view {
        assertEq(restitution.getUsdcPerOpLend(otherId, 1e6), 0);
    }

    function test_GetUsdcPerOpLend() public {
        createOpRestitution();

        assertEq(restitution.getUsdcPerOpLend(opId, 1e6), 1e6);
        assertEq(restitution.getUsdcPerOpLend(opId, userShares), userShares);
        assertEq(restitution.getUsdcPerOpLend(opId, totalSharesAmount), restAmount);
        assertEq(restitution.getUsdcPerOpLend(opId, 0), 0);
    }

    function test_GetUsdcPerOpLendRoundsDown() public {
        LendOperation op = newOpLend(3);
        fundRestitution(otherId, address(op), 10);

        assertEq(restitution.getUsdcPerOpLend(otherId, 1), 3); // 10/3
        assertEq(restitution.getUsdcPerOpLend(otherId, 2), 6); // 20/3
        assertEq(restitution.getUsdcPerOpLend(otherId, 3), 10);
    }

    function test_GetUsdcPerOpLendIsUnaffectedByClaims() public {
        createOpRestitution();

        vm.prank(user);
        restitution.claimRestitution(opId, 250_000e6);

        assertEq(restitution.getUsdcPerOpLend(opId, 1e6), 1e6);
    }

    function testFuzz_GetUsdcPerOpLendNeverExceedsFunding(uint256 _amount) public {
        createOpRestitution();
        uint256 amount = bound(_amount, 0, totalSharesAmount);

        assertLe(restitution.getUsdcPerOpLend(opId, amount), restAmount);
    }

    //********** availableRestitution **********

    function test_AvailableRestitution() public {
        createOpRestitution();

        assertEq(restitution.availableRestitution(opId, user), userShares);
        assertEq(restitution.availableRestitution(opId, user2), userShares);
    }

    function test_AvailableRestitutionUnknownId() public view {
        assertEq(restitution.availableRestitution(otherId, user), 0);
    }

    function test_AvailableRestitutionZeroBalanceUser() public {
        createOpRestitution();

        assertEq(restitution.availableRestitution(opId, user3), 0);
    }

    function test_AvailableRestitutionAfterPartialClaim() public {
        createOpRestitution();

        vm.prank(user);
        restitution.claimRestitution(opId, 200_000e6);

        assertEq(restitution.availableRestitution(opId, user), userShares - 200_000e6);
        assertEq(restitution.availableRestitution(opId, user2), userShares);
    }

    function test_AvailableRestitutionZeroWhenFinished() public {
        createOpRestitution();

        vm.prank(user);
        restitution.claimRestitution(opId, userShares);
        vm.prank(user2);
        restitution.claimRestitution(opId, userShares);

        assertEq(restitution.availableRestitution(opId, user), 0);
        assertEq(restitution.availableRestitution(opId, user2), 0);
        assertEq(restitution.availableRestitution(opId, user3), 0);
    }

    function test_AvailableRestitutionZeroAfterWithdraw() public {
        createOpRestitution();

        vm.prank(admin);
        restitution.withdrawRestitution(opId, user3);

        assertEq(restitution.availableRestitution(opId, user), 0);
        assertEq(restitution.availableRestitution(opId, user2), 0);
    }

    /// @dev The quote is derived from the live share balance, not snapshotted at funding time.
    function test_AvailableRestitutionFollowsShareTransfers() public {
        createOpRestitution();

        vm.prank(user);
        restOpLend.transfer(user2, userShares / 2);

        assertEq(restitution.availableRestitution(opId, user), userShares / 2);
        assertEq(restitution.availableRestitution(opId, user2), userShares + userShares / 2);
    }

    //********** restitutions accessor **********

    function test_RestitutionsStructIsEmptyForUnknownId() public view {
        assertEq(restitutionOpLend(otherId), address(0));
        assertEq(restitutionShares(otherId), 0);
        assertEq(restitutionUsdc(otherId), 0);
    }
}
