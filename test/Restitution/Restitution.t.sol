// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {TestBase} from "../TestBase.t.sol";
import {LendOperation} from "../../src/opLend.sol";

contract RestitutionTest is Test, TestBase {
    uint256 restAmount = 1_000_000e6;
    LendOperation restOpLend;

    function createDummyOpLend() public {}

    function createOpRestitution() public {
        restOpLend = LendOperation(createOperation());

        vm.startPrank(admin);
        usdc.approve(address(restitution), type(uint256).max);

        deal(address(usdc), address(admin), restAmount);
        deal(address(restOpLend), address(user), 500_000 * 10 ** sharesDecimal);
        deal(address(restOpLend), address(user2), 500_000 * 10 ** sharesDecimal);

        restitution.restituteFunds(1, address(restOpLend), restAmount);

        factory.opLendWhitelistUser(1, address(user), true);
        factory.opLendWhitelistUser(1, address(user2), true);
        vm.stopPrank();

        vm.prank(user);
        restOpLend.approve(address(restitution), type(uint256).max);

        vm.prank(user2);
        restOpLend.approve(address(restitution), type(uint256).max);
    }

    function setUp() public override(TestBase) {
        super.setUp();
    }
}
