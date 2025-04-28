// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";
import {DummyUSDC} from "../src/DummyUSDC.sol";

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
        factory.createOperation(
            "Test operation",
            1_000_000,
            1 * 10 ** usdc.decimals()
        );

        assertEq(factory.operationCount(), 1);
    }
}
