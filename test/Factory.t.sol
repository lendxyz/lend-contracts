// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {LendFactory} from "../src/Factory.sol";
import {USDC} from "../src/testnet/DummyUSDC.sol";
import {LendOperation} from "../src/opLend.sol";
import {TestBase} from "./TestBase.sol";

contract FactoryTest is Test, TestBase {
    function beforeTestSetup(bytes4 testSelector) public pure returns (bytes[] memory beforeTestCalldata) {
        if (testSelector != this.test_CreateOperation.selector) {
            beforeTestCalldata = new bytes[](2);
            beforeTestCalldata[0] = abi.encodePacked(this.mintUsdc.selector);
            beforeTestCalldata[1] = abi.encodePacked(this.createOperation.selector);
        }
    }

    function test_CreateOperation() public {
        address op = createOperation();
        LendOperation opLend = LendOperation(op);

        LendFactory.Operation memory expectedReturn =
            LendFactory.Operation(op, totalSharesAmount, sharePriceEur, "Test operation");
        LendFactory.Operation memory actualReturn = factory.getOperation(1);

        assertEq(factory.operationCount(), 1);
        assertEq(abi.encode(actualReturn), abi.encode(expectedReturn));
        assertEq(opLend.name(), "Lend Operation - Test operation");
        assertEq(opLend.symbol(), "opLEND-1");
        assertEq(opLend.MAX_SUPPLY(), totalSharesAmount);
    }

    function test_InvestCost() public view {
        uint256 computedCost = factory.getAmountIn(1, sharesToBuy);
        uint256 sharesDecimalConverted = 10 ** sharesDecimal;
        uint256 sharesAmount = sharesToBuy / sharesDecimalConverted;
        assertLt(computedCost, sharesAmount * eurAmountPerShare * maxEurUsdcRange * 10 ** (usdc.decimals() - 1));
        assertGt(computedCost, sharesAmount * eurAmountPerShare * minEurUsdcRange * 10 ** (usdc.decimals() - 1));
    }

    function test_SharesAmount() public view {
        uint256 cost = factory.getAmountIn(1, sharesToBuy);
        uint256 calculatedSharesAmount = factory.getAmountOut(1, cost);
        assertEq(sharesToBuy, calculatedSharesAmount);
    }

    function test_Invest() public {
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);

        vm.startPrank(user);

        uint256 cost = factory.getAmountIn(1, sharesToBuy);
        usdc.approve(address(factory), cost);
        factory.invest(1, sharesToBuy, testNonce, signature);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance - cost);
        assertEq(usdc.balanceOf(address(factory)), cost);
        assertEq(opLend.balanceOf(address(user)), sharesToBuy);
        assertEq(factory.fundingProgress(1), sharesToBuy);
        assertEq(factory.operationStarted(1), true);
        assertEq(factory.usdcRaisedPerClient(1, address(user)), cost);
    }

    function test_InvestAndBridge() public {
        LendOperation opToken = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);

        vm.prank(admin);
        factory.setOpLendPeer(1, 42161, 30110, bytes32(uint256(uint160(address(opToken)))));

        vm.deal(user, 10 ether);
        vm.startPrank(user);

        uint256 cost = factory.getAmountIn(1, sharesToBuy);
        usdc.approve(address(factory), cost);

        SendParam memory sendParam = SendParam(
            30110,
            bytes32(uint256(uint160(msg.sender))),
            sharesToBuy,
            sharesToBuy,
            hex"0003010011010000000000000000000000000000ea60",
            new bytes(0),
            new bytes(0)
        );

        MessagingFee memory fees = opToken.quoteSend(sendParam, false);

        factory.investAndBridge{value: fees.nativeFee}(1, sharesToBuy, testNonce, signature, 30110);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance - cost);
        assertEq(usdc.balanceOf(address(factory)), cost);
        assertEq(factory.fundingProgress(1), sharesToBuy);
        assertEq(factory.usdcRaisedPerClient(1, address(user)), cost);
    }

    function test_CannotReuseSignature() public {
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);

        vm.startPrank(user);
        uint256 cost = factory.getAmountIn(1, sharesToBuy);
        usdc.approve(address(factory), cost);
        factory.invest(1, sharesToBuy, testNonce, signature);
        vm.expectRevert();
        factory.invest(1, sharesToBuy, testNonce, signature);
        vm.stopPrank();
    }

    function test_Refund() public {
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);

        vm.startPrank(user);

        uint256 cost = factory.getAmountIn(1, sharesToBuy);
        usdc.approve(address(factory), cost);
        factory.invest(1, sharesToBuy, testNonce, signature);

        vm.stopPrank();

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance - cost);
        assertEq(usdc.balanceOf(address(factory)), cost);
        assertEq(opLend.balanceOf(address(user)), sharesToBuy);
        assertEq(factory.fundingProgress(1), sharesToBuy);
        assertEq(factory.usdcRaisedPerClient(1, address(user)), cost);

        vm.prank(admin);
        factory.refundUser(1, address(user));

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(usdc.balanceOf(address(factory)), 0);
        assertEq(opLend.balanceOf(address(user)), 0);
        assertEq(factory.fundingProgress(1), 0);
        assertEq(factory.usdcRaisedPerClient(1, address(user)), 0);
    }

    function test_OpFinished() public {
        assertEq(factory.isOperationFinished(1), false);

        bytes memory signature = getMintSignature(address(user), 1, totalSharesAmount, testNonce);

        vm.startPrank(user);

        usdc.approve(address(factory), UINT256_MAX);
        factory.invest(1, totalSharesAmount, testNonce, signature);

        vm.stopPrank();

        assertEq(factory.fundingProgress(1), totalSharesAmount);
        assertEq(factory.operationStarted(1), true);
        assertEq(factory.isOperationFinished(1), true);
    }

    function test_AddLZPeer() public {
        bytes32 peer = bytes32(uint256(uint160(address(admin))));
        vm.startPrank(admin);

        vm.expectEmit(address(factory));
        emit LendFactory.OpLendPeerAdded(1, 42161, 30110, peer);

        factory.setOpLendPeer(1, 42161, 30110, peer);

        vm.stopPrank();
    }
}
