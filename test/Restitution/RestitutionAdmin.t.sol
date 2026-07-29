// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {LendRestitution} from "../../src/Restitution.sol";
import {RestitutionTest} from "./Restitution.t.sol";

contract RestitutionAdminTest is Test, RestitutionTest {
    function test_createOpRestitution() public {
        createOpRestitution();

        assertEq(restitution.availableRestitution(1, address(user)), 500_000e6);
        assertEq(restitution.availableRestitution(1, address(user2)), 500_000e6);
        assertEq(restitution.getUsdcPerOpLend(1, 1e6), 1e6);
    }
}
