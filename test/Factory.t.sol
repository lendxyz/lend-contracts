// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {Factory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";
import {DummyUSDC} from "../src/DummyUSDC.sol";
import {LendOperation} from "../src/opLend.sol";

contract FactoryTest is Test {
    uint256 initialUSDCBalance = UINT256_MAX;
    DummyUSDC public usdc;
    Factory public factory;
    LendDebt public dLend;

    address admin = makeAddr("admin");
    address user = makeAddr("user");

    function beforeTestSetup(
        bytes4 testSelector
    ) public pure returns (bytes[] memory beforeTestCalldata) {
        if (testSelector != this.test_CreateOperation.selector) {
            beforeTestCalldata = new bytes[](2);
            beforeTestCalldata[0] = abi.encodePacked(this.mintUSDC.selector);
            beforeTestCalldata[1] = abi.encodePacked(this.createOperation.selector);
        }
    }

    function mintUSDC() public {
        vm.prank(admin);
        usdc.mint(address(user), initialUSDCBalance);
    }

    function createOperation() public returns(address) {
        vm.prank(admin);
        return factory.createOperation(
            "Test operation",
            1_000_000,
            1 * 10 ** 18
        );
    }

    function setUp() public {
        vm.deal(admin, 10 ether);
        vm.deal(user, 10 ether);
        vm.startPrank(admin);

        usdc = new DummyUSDC();
        factory = new Factory(address(usdc));
        dLend = LendDebt(factory.dLEND());

        vm.stopPrank();
    }

    function test_CreateOperation() public {
        address op = createOperation();
        LendOperation opLEND = LendOperation(op);

        Factory.Operation memory expectedReturn = Factory.Operation(op, 1_000_000, 1 * 10 ** 18, "Test operation");
        Factory.Operation memory actualReturn = factory.getOperation(1);

        assertEq(factory.operationCount(), 1);
        assertEq(abi.encode(actualReturn), abi.encode(expectedReturn));
        assertEq(opLEND.name(), "Lend Operation - Test operation");
        assertEq(opLEND.symbol(), "opLEND-1");
        assertEq(opLEND.MAX_SUPPLY(), 1_000_000 * 10 ** 18);
    }

    function test_InvestCost() public view {
        uint256 cost = factory.getAmountIn(1, 100);
        assertEq(cost, 100 * 10 ** 6);
    }

    function test_Invest() public {
        vm.prank(admin);
        factory.startOperation(1);

        vm.startPrank(user);

        usdc.approve(address(factory), 100 * 10 ** 6);
        factory.invest(1, 100);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(user)), initialUSDCBalance - (100 * 10 ** 6));
        assertEq(usdc.balanceOf(address(factory)), 100 * 10 ** 6);
        assertEq(dLend.balanceOf(address(user), 1), 100);
        assertEq(factory.fundingProgress(1), 100);
        assertEq(factory.operationStarted(1), true);
    }

    function test_OpFinished() public {
        assertEq(factory.isOperationFinished(1), false);
        assertEq(factory.operationStarted(1), false);

        vm.prank(admin);
        factory.startOperation(1);

        assertEq(factory.operationStarted(1), true);

        vm.startPrank(user);

        usdc.approve(address(factory), UINT256_MAX);
        factory.invest(1, 1_000_000);

        vm.stopPrank();

        assertEq(factory.fundingProgress(1), 1_000_000);
        assertEq(factory.operationStarted(1), true);
        assertEq(factory.isOperationFinished(1), true);
    }
}
