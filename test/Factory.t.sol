// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";

contract FactoryTest is Test {
    Factory public factory;
    LendDebt public dLend;

    function setUp() public {
        dLend = new LendDebt();
        factory = new Factory(address(dLend));
        dLend.transferOwnership(address(factory));
    }

    function test_CreateOperation() public {
        factory.createOperation(
            "Test operation",
            1_000_000,
            10,
            1
        );

        assertEq(factory.operationCount(), 1);
    }
}
