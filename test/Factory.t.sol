// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LendFactory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";
import {DummyUSDC} from "../src/DummyUSDC.sol";
import {LendOperation} from "../src/opLend.sol";
import {TestBase} from "./TestBase.sol";

contract FactoryTest is Test, TestBase {
    function beforeTestSetup(bytes4 testSelector) public pure returns (bytes[] memory beforeTestCalldata) {
        if (testSelector != this.test_CreateOperation.selector) {
            beforeTestCalldata = new bytes[](2);
            beforeTestCalldata[0] = abi.encodePacked(this.mintUSDC.selector);
            beforeTestCalldata[1] = abi.encodePacked(this.createOperation.selector);
        }
    }

    function test_CreateOperation() public {
        address op = createOperation();
        LendOperation opLEND = LendOperation(op);

        LendFactory.Operation memory expectedReturn =
            LendFactory.Operation(op, totalSharesAmount, sharePriceEur, decimalsEur, "Test operation");
        LendFactory.Operation memory actualReturn = factory.getOperation(1);

        assertEq(factory.operationCount(), 1);
        assertEq(abi.encode(actualReturn), abi.encode(expectedReturn));
        assertEq(opLEND.name(), "Lend Operation - Test operation");
        assertEq(opLEND.symbol(), "opLEND-1");
        assertEq(opLEND.MAX_SUPPLY(), totalSharesAmount * 10 ** 18);
    }

    function test_InvestCost() public view {
        uint256 computedCost = factory.getAmountIn(1, sharesToBuy);
        assertLt(computedCost, sharesToBuy * maxEurUsdcRange * 10 ** (usdc.decimals() - 1));
        assertGt(computedCost, sharesToBuy * minEurUsdcRange * 10 ** (usdc.decimals() - 1));
    }

    function test_Invest() public {
        vm.prank(admin);
        factory.startOperation(1);

        vm.startPrank(user);

        uint256 cost = factory.getAmountIn(1, sharesToBuy);
        usdc.approve(address(factory), cost);
        factory.invest(1, sharesToBuy);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(user)), initialUSDCBalance - cost);
        assertEq(usdc.balanceOf(address(factory)), cost);
        assertEq(dLend.balanceOf(address(user), 1), sharesToBuy);
        assertEq(factory.fundingProgress(1), sharesToBuy);
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
        factory.invest(1, totalSharesAmount);

        vm.stopPrank();

        assertEq(factory.fundingProgress(1), totalSharesAmount);
        assertEq(factory.operationStarted(1), true);
        assertEq(factory.isOperationFinished(1), true);
    }
}
