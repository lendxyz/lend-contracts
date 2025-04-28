// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";
import {DummyUSDC} from "../src/DummyUSDC.sol";
import {LendOperation} from "../src/opLend.sol";

contract FactoryTest is Test {
    DummyUSDC public usdc;
    Factory public factory;
    LendDebt public dLend;

    function setUp() public {
        usdc = new DummyUSDC();

        usdc.mint(msg.sender, 1_000_000 * 10 ** 6);

        factory = new Factory(address(usdc));
        dLend = LendDebt(factory.dLEND());
    }

    function test_CreateOperation() public {
        address op = factory.createOperation(
            "Test operation",
            1_000_000,
            1 * 10 ** 18
        );

        LendOperation opLEND = LendOperation(op);

        Factory.Operation memory expectedReturn = Factory.Operation(op, 1_000_000, 1 * 10 ** 18, "Test operation");
        Factory.Operation memory actualReturn = factory.getOperation(1);

        assertEq(factory.operationCount(), 1);
        assertEq(abi.encode(actualReturn), abi.encode(expectedReturn));
        assertEq(opLEND.name(), "Lend Operation - Test operation");
        assertEq(opLEND.symbol(), "opLEND-1");
        assertEq(opLEND.MAX_SUPPLY(), 1_000_000 * 10 ** 18);
    }
}
