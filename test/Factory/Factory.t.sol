// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ILendFactory} from "src/Factory/interfaces/IFactory.sol";
import {USDC} from "src/testnet/DummyUSDC.sol";
import {LendOperation} from "src/opLend.sol";
import {TestBase} from "test/TestBase.t.sol";

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

        ILendFactory.Operation memory expectedReturn =
            ILendFactory.Operation(op, totalSharesAmount, sharePriceEur, "Test operation");
        ILendFactory.Operation memory actualReturn = factory.getOperation(1);

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

    function test_InvestFiat() public {
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);
        bytes memory signatureFiat = getMintSignatureFiat(address(user2), address(user3), 1, sharesToBuy, testNonce2);

        vm.startPrank(user);
        uint256 cost = factory.getAmountIn(1, sharesToBuy);
        usdc.approve(address(factory), cost);
        factory.invest(1, sharesToBuy, testNonce, signature);
        vm.stopPrank();

        vm.startPrank(user2);
        factory.fiatInvest(1, sharesToBuy, address(user2), address(user3), testNonce2, signatureFiat);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance - cost);
        assertEq(usdc.balanceOf(address(factory)), cost);
        assertEq(opLend.balanceOf(address(user)), sharesToBuy);
        assertEq(opLend.balanceOf(address(user2)), 0);
        assertEq(opLend.balanceOf(address(user3)), sharesToBuy);
        assertEq(factory.fundingProgress(1), sharesToBuy * 2);
        assertEq(factory.operationStarted(1), true);
        assertEq(factory.usdcRaised(1), cost);
        assertEq(factory.usdcRaisedPerClient(1, address(user)), cost);
        assertEq(factory.usdcRaisedPerClient(1, address(user2)), 0);
        assertEq(factory.usdcRaisedPerClient(1, address(user3)), 0);
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
            hex"00030100110100000000000000000000000000013880", // 80k gas for lzReceive
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
        factory.refundUser(1, address(user), sharesToBuy, cost, 0);

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(usdc.balanceOf(address(factory)), 0);
        assertEq(opLend.balanceOf(address(user)), 0);
        assertEq(factory.fundingProgress(1), 0);
        assertEq(factory.usdcRaised(1), 0);
        // The per-client record keeps what was paid in.
        assertEq(factory.usdcRaisedPerClient(1, address(user)), cost);
    }

    function test_RefundAmountsAreDecidedByOwner() public {
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);

        vm.startPrank(user);
        uint256 cost = factory.getAmountIn(1, sharesToBuy);
        usdc.approve(address(factory), cost);
        factory.invest(1, sharesToBuy, testNonce, signature);
        vm.stopPrank();

        vm.prank(user);
        vm.expectRevert();
        factory.refundUser(1, address(user), sharesToBuy, cost, 0);

        vm.startPrank(admin);
        vm.expectRevert(ILendFactory.InputCannotBeZero.selector);
        factory.refundUser(1, address(user), 0, 0, 0);

        vm.expectRevert(ILendFactory.InsufficientShareBalance.selector);
        factory.refundUser(1, address(user), sharesToBuy + 1, 0, 0);

        // Shares only.
        vm.expectEmit(address(factory));
        emit ILendFactory.Refunded(address(user), 1, 0, sharesToBuy / 2);
        factory.refundUser(1, address(user), sharesToBuy / 2, 0, 0);

        assertEq(opLend.balanceOf(address(user)), sharesToBuy - sharesToBuy / 2);
        assertEq(factory.fundingProgress(1), sharesToBuy - sharesToBuy / 2);
        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance - cost);
        assertEq(factory.usdcRaised(1), cost);

        // USDC only.
        factory.refundUser(1, address(user), 0, cost, 0);
        vm.stopPrank();

        assertEq(opLend.balanceOf(address(user)), sharesToBuy - sharesToBuy / 2);
        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(factory.usdcRaised(1), 0);
        assertEq(factory.usdcRaisedPerClient(1, address(user)), cost);
    }

    function test_RefundPaidByOwnerWhenEscrowShort() public {
        address treasury = makeAddr("treasury");
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);
        bytes memory signature2 = getMintSignature(address(user2), 1, sharesToBuy, testNonce2);
        uint256 cost = factory.getAmountIn(1, sharesToBuy);

        vm.startPrank(user);
        usdc.approve(address(factory), UINT256_MAX);
        factory.invest(1, sharesToBuy, testNonce, signature);
        vm.stopPrank();

        vm.prank(admin);
        factory.withdrawUsdc(1, treasury);

        // The escrow is empty: the owner pays, which needs its allowance and balance.
        vm.startPrank(admin);
        vm.expectRevert(ILendFactory.InsufficientAllowance.selector);
        factory.refundUser(1, address(user), sharesToBuy, cost, 0);

        usdc.approve(address(factory), UINT256_MAX);
        vm.expectRevert(ILendFactory.InsufficientEscrow.selector);
        factory.refundUser(1, address(user), sharesToBuy, initialUsdcBalance + 1, 0);

        factory.refundUser(1, address(user), sharesToBuy, cost, 0);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(usdc.balanceOf(address(admin)), initialUsdcBalance - cost);
        assertEq(opLend.balanceOf(address(user)), 0);
        assertEq(factory.fundingProgress(1), 0);
        assertEq(factory.usdcRaised(1), cost);

        // The escrow holds less than the refund: the owner pays all of it, the escrow nothing.
        vm.startPrank(user2);
        usdc.approve(address(factory), UINT256_MAX);
        factory.invest(1, sharesToBuy, testNonce2, signature2);
        vm.stopPrank();

        vm.prank(admin);
        factory.refundUser(1, address(user2), sharesToBuy, cost + 1, 0);

        assertEq(usdc.balanceOf(address(user2)), initialUsdcBalance + 1);
        assertEq(usdc.balanceOf(address(admin)), initialUsdcBalance - 2 * cost - 1);
        assertEq(usdc.balanceOf(address(factory)), cost);
        assertEq(factory.usdcRaised(1), 2 * cost);

        // An escrow covering the refund pays it.
        vm.prank(admin);
        factory.refundUser(1, address(user2), 0, cost, 0);

        assertEq(usdc.balanceOf(address(admin)), initialUsdcBalance - 2 * cost - 1);
        assertEq(usdc.balanceOf(address(factory)), 0);
        assertEq(factory.usdcRaised(1), cost);
    }

    function test_BatchRefundUsers() public {
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);
        bytes memory signature2 = getMintSignature(address(user2), 1, sharesToBuy, testNonce2);
        uint256 cost = factory.getAmountIn(1, sharesToBuy);

        vm.startPrank(user);
        usdc.approve(address(factory), cost);
        factory.invest(1, sharesToBuy, testNonce, signature);
        vm.stopPrank();
        vm.startPrank(user2);
        usdc.approve(address(factory), cost);
        factory.invest(1, sharesToBuy, testNonce2, signature2);
        vm.stopPrank();

        ILendFactory.RefundEntry[] memory entries = new ILendFactory.RefundEntry[](2);
        entries[0] = ILendFactory.RefundEntry(address(user), sharesToBuy, cost, 0);
        entries[1] = ILendFactory.RefundEntry(address(user2), sharesToBuy + 1, cost, 0);

        // One failing entry reverts the whole batch.
        vm.prank(admin);
        vm.expectRevert(ILendFactory.InsufficientShareBalance.selector);
        factory.batchRefundUsers(1, entries);
        assertEq(opLend.balanceOf(address(user)), sharesToBuy);

        entries[1].sharesToBurn = sharesToBuy;
        vm.prank(admin);
        factory.batchRefundUsers(1, entries);

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(usdc.balanceOf(address(user2)), initialUsdcBalance);
        assertEq(opLend.balanceOf(address(user)), 0);
        assertEq(opLend.balanceOf(address(user2)), 0);
        assertEq(factory.fundingProgress(1), 0);
        assertEq(factory.usdcRaised(1), 0);
    }

    function test_FiatRefund() public {
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        uint256 bought = 2 * sharesToBuy;
        bytes memory signature = getMintSignatureFiat(address(user2), address(user3), 1, bought, testNonce);

        factory.fiatInvest(1, bought, address(user2), address(user3), testNonce, signature);

        vm.prank(user);
        vm.expectRevert();
        factory.fiatRefund(1, address(user2), address(user3), sharesToBuy);

        vm.startPrank(admin);
        vm.expectRevert(ILendFactory.ZeroShares.selector);
        factory.fiatRefund(1, address(user2), address(user3), 0);

        vm.expectRevert(ILendFactory.InsufficientShareBalance.selector);
        factory.fiatRefund(1, address(user2), address(user3), bought + 1);

        vm.expectEmit(address(factory));
        emit ILendFactory.Refunded(address(user2), 1, 0, sharesToBuy);
        vm.expectEmit(address(factory));
        emit ILendFactory.RefundedFiat(address(user2), address(user3), 1, sharesToBuy);
        factory.fiatRefund(1, address(user2), address(user3), sharesToBuy);
        vm.stopPrank();

        assertEq(opLend.balanceOf(address(user3)), bought - sharesToBuy);
        assertEq(factory.fundingProgress(1), bought - sharesToBuy);
        assertEq(usdc.balanceOf(address(factory)), 0);

        // The refunded shares are back on sale: selling the rest finishes the operation, which is then not refunded.
        uint256 rest = totalSharesAmount - (bought - sharesToBuy);
        bytes memory signature2 = getMintSignatureFiat(address(user2), address(user3), 1, rest, testNonce2);
        factory.fiatInvest(1, rest, address(user2), address(user3), testNonce2, signature2);
        assertEq(factory.isOperationFinished(1), true);

        vm.prank(admin);
        vm.expectRevert(ILendFactory.OpFinished.selector);
        factory.fiatRefund(1, address(user2), address(user3), sharesToBuy);
    }

    function test_FinishedOperationCannotBeRefundedOrCanceled() public {
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, totalSharesAmount, testNonce);
        uint256 cost = factory.getAmountIn(1, totalSharesAmount);

        vm.startPrank(user);
        usdc.approve(address(factory), cost);
        factory.invest(1, totalSharesAmount, testNonce, signature);
        vm.stopPrank();
        assertEq(factory.isOperationFinished(1), true);

        ILendFactory.RefundEntry[] memory entries = new ILendFactory.RefundEntry[](1);
        entries[0] = ILendFactory.RefundEntry(address(user), totalSharesAmount, cost, 0);

        vm.startPrank(admin);
        vm.expectRevert(ILendFactory.OpFinished.selector);
        factory.refundUser(1, address(user), totalSharesAmount, cost, 0);
        vm.expectRevert(ILendFactory.OpFinished.selector);
        factory.batchRefundUsers(1, entries);
        vm.expectRevert(ILendFactory.OpFinished.selector);
        factory.cancelOperation(1);
        vm.stopPrank();

        assertEq(factory.operationCanceled(1), false);
        assertEq(opLend.balanceOf(address(user)), totalSharesAmount);
        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance - cost);
        assertEq(factory.fundingProgress(1), totalSharesAmount);
        assertEq(factory.usdcRaised(1), cost);
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

    function test_VoidNonce() public {
        bytes memory voidSignature = getVoidNonceSignature(address(factory), testNonce);

        // Signed by the backend: anyone can relay it.
        vm.prank(user2);
        vm.expectEmit(address(factory));
        emit ILendFactory.NonceVoided(testNonce);
        factory.voidNonce(testNonce, voidSignature);

        vm.prank(user2);
        vm.expectRevert(ILendFactory.NonceAlreadyUsed.selector);
        factory.voidNonce(testNonce, voidSignature);

        // The invest signature carrying the voided nonce is refused.
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);
        vm.startPrank(user);
        usdc.approve(address(factory), UINT256_MAX);
        vm.expectRevert(ILendFactory.InvalidSignature.selector);
        factory.invest(1, sharesToBuy, testNonce, signature);
        vm.stopPrank();

        // Without a signature, only the owner; it voids fiat-invest nonces too.
        vm.prank(user);
        vm.expectRevert();
        factory.voidNonce(testNonce2, "");

        vm.prank(admin);
        factory.voidNonce(testNonce2, "");

        bytes memory fiatSignature = getMintSignatureFiat(address(user2), address(user3), 1, sharesToBuy, testNonce2);
        vm.expectRevert(ILendFactory.InvalidSignature.selector);
        factory.fiatInvest(1, sharesToBuy, address(user2), address(user3), testNonce2, fiatSignature);
    }

    function test_VoidNonceRejectsWrongSignatureAndSpentNonce() public {
        (, uint256 otherPk) = makeAddrAndKey("other-signer");
        bytes32 digest = keccak256(abi.encodePacked("VOID_NONCE", address(factory), block.chainid, testNonce2));
        (uint8 v, bytes32 r, bytes32 s) =
            vm.sign(otherPk, keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest)));

        vm.expectRevert(ILendFactory.InvalidSignature.selector);
        factory.voidNonce(testNonce2, abi.encodePacked(r, s, v));

        // A void signature for another contract does not apply to the factory.
        vm.expectRevert(ILendFactory.InvalidSignature.selector);
        factory.voidNonce(testNonce2, getVoidNonceSignature(address(opLendWallet), testNonce2));

        // A nonce already spent by an investment cannot be voided.
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);
        vm.startPrank(user);
        usdc.approve(address(factory), UINT256_MAX);
        factory.invest(1, sharesToBuy, testNonce, signature);
        vm.stopPrank();

        vm.prank(admin);
        vm.expectRevert(ILendFactory.NonceAlreadyUsed.selector);
        factory.voidNonce(testNonce, "");
    }

    function test_OpLendVoidNonce() public {
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);

        // The token's owner is the factory: the admin voids through `opLendVoidNonce`.
        vm.prank(admin);
        vm.expectRevert();
        opLend.voidNonce(testNonce, "");

        vm.prank(user);
        vm.expectRevert();
        factory.opLendVoidNonce(1, testNonce);

        vm.prank(admin);
        vm.expectEmit(address(opLend));
        emit LendOperation.NonceVoided(testNonce);
        factory.opLendVoidNonce(1, testNonce);

        bytes memory whitelistSignature = getTransferSignature(address(opLend), address(user2), testNonce);
        vm.expectRevert(LendOperation.InvalidSignature.selector);
        opLend.whitelistUser(address(user2), testNonce, whitelistSignature);

        // Signed by the backend over the token's address: anyone can relay it, once.
        bytes memory voidSignature = getVoidNonceSignature(address(opLend), testNonce2);
        vm.prank(user2);
        opLend.voidNonce(testNonce2, voidSignature);
        vm.expectRevert(LendOperation.NonceAlreadyUsed.selector);
        opLend.voidNonce(testNonce2, voidSignature);

        vm.expectRevert(LendOperation.InvalidSignature.selector);
        opLend.voidNonce("other", getVoidNonceSignature(address(factory), "other"));
    }

    function test_WithdrawUsdcBeforeAndAfterSaleEnd() public {
        address treasury = makeAddr("treasury");
        uint256 remainingShares = totalSharesAmount - sharesToBuy;
        bytes memory firstSignature = getMintSignature(address(user), 1, sharesToBuy, testNonce);
        bytes memory secondSignature = getMintSignature(address(user), 1, remainingShares, testNonce2);

        vm.startPrank(user);
        usdc.approve(address(factory), UINT256_MAX);
        factory.invest(1, sharesToBuy, testNonce, firstSignature);
        vm.stopPrank();

        uint256 firstRaise = factory.usdcRaised(1);
        assertEq(factory.isOperationFinished(1), false);

        vm.prank(admin);
        factory.withdrawUsdc(1, treasury);

        assertEq(usdc.balanceOf(treasury), firstRaise);
        assertEq(usdc.balanceOf(address(factory)), 0);
        assertEq(factory.usdcWithdrawn(1), false);

        vm.prank(admin);
        vm.expectRevert(ILendFactory.AlreadyWithdrawn.selector);
        factory.withdrawUsdc(1, treasury);

        vm.startPrank(user);
        factory.invest(1, remainingShares, testNonce2, secondSignature);
        vm.stopPrank();

        assertEq(factory.isOperationFinished(1), true);

        vm.prank(admin);
        factory.withdrawUsdc(1, treasury);

        assertEq(usdc.balanceOf(treasury), factory.usdcRaised(1));
        assertEq(usdc.balanceOf(address(factory)), 0);
        assertEq(factory.usdcWithdrawn(1), true);

        vm.prank(admin);
        vm.expectRevert(ILendFactory.AlreadyWithdrawn.selector);
        factory.withdrawUsdc(1, treasury);
    }

    function test_AddLZPeer() public {
        bytes32 peer = bytes32(uint256(uint160(address(admin))));
        vm.startPrank(admin);

        vm.expectEmit(address(factory));
        emit ILendFactory.OpLendPeerAdded(1, 42161, 30110, peer);

        factory.setOpLendPeer(1, 42161, 30110, peer);

        vm.stopPrank();
    }

    function test_InvestEurChargesEurPriceAndEmitsUsdValue() public {
        mintEurc();
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);

        // EURC is charged the EUR price with no oracle conversion; the event reports the oracle USD value.
        uint256 eurcCost = factory.getAmountInEur(1, sharesToBuy);
        uint256 usdValue = factory.getAmountIn(1, sharesToBuy);
        assertEq(eurcCost, sharesToBuy * sharePriceEur / 10 ** sharesDecimal);

        vm.startPrank(user);
        eurc.approve(address(factory), eurcCost);

        vm.expectEmit(address(factory));
        emit ILendFactory.Invested(address(user), 1, usdValue, sharesToBuy);
        factory.investEur(1, sharesToBuy, testNonce, signature);
        vm.stopPrank();

        assertEq(eurc.balanceOf(address(user)), initialUsdcBalance - eurcCost);
        assertEq(eurc.balanceOf(address(factory)), eurcCost);
        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(opLend.balanceOf(address(user)), sharesToBuy);
        assertEq(factory.fundingProgress(1), sharesToBuy);
        assertEq(factory.eurcRaised(1), eurcCost);
        assertEq(factory.eurcRaisedPerClient(1, address(user)), eurcCost);
        assertEq(factory.usdcRaised(1), 0);
        assertEq(factory.usdcRaisedPerClient(1, address(user)), 0);
    }

    function test_InvestEurAndBridge() public {
        mintEurc();
        LendOperation opToken = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);

        vm.prank(admin);
        factory.setOpLendPeer(1, 42161, 30110, bytes32(uint256(uint160(address(opToken)))));

        vm.startPrank(user);

        uint256 eurcCost = factory.getAmountInEur(1, sharesToBuy);
        eurc.approve(address(factory), eurcCost);

        SendParam memory sendParam = SendParam(
            30110,
            bytes32(uint256(uint160(msg.sender))),
            sharesToBuy,
            sharesToBuy,
            hex"00030100110100000000000000000000000000013880", // 80k gas for lzReceive
            new bytes(0),
            new bytes(0)
        );

        MessagingFee memory fees = opToken.quoteSend(sendParam, false);

        uint256 usdValue = factory.getAmountIn(1, sharesToBuy);
        vm.expectEmit(address(factory));
        emit ILendFactory.Invested(address(user), 1, usdValue, sharesToBuy);
        factory.investEurAndBridge{value: fees.nativeFee}(1, sharesToBuy, testNonce, signature, 30110);

        vm.stopPrank();

        assertEq(eurc.balanceOf(address(user)), initialUsdcBalance - eurcCost);
        assertEq(eurc.balanceOf(address(factory)), eurcCost);
        assertEq(opToken.balanceOf(address(user)), 0);
        assertEq(factory.fundingProgress(1), sharesToBuy);
        assertEq(factory.eurcRaisedPerClient(1, address(user)), eurcCost);
    }

    function test_RefundMixedUsdcAndEurc() public {
        mintEurc();
        LendOperation opLend = LendOperation(factory.getOperation(1).opToken);
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);
        bytes memory signature2 = getMintSignature(address(user), 1, sharesToBuy, testNonce2);

        vm.startPrank(user);
        uint256 usdcCost = factory.getAmountIn(1, sharesToBuy);
        uint256 eurcCost = factory.getAmountInEur(1, sharesToBuy);
        usdc.approve(address(factory), usdcCost);
        eurc.approve(address(factory), eurcCost);
        factory.invest(1, sharesToBuy, testNonce, signature);
        factory.investEur(1, sharesToBuy, testNonce2, signature2);
        vm.stopPrank();

        assertEq(factory.fundingProgress(1), sharesToBuy * 2);

        // Each token is refunded in kind; the event reports the total in USD.
        uint256 eurcUsdValue = factory.getAmountIn(1, sharesToBuy);
        vm.prank(admin);
        vm.expectEmit(address(factory));
        emit ILendFactory.Refunded(address(user), 1, usdcCost + eurcUsdValue, sharesToBuy * 2);
        factory.refundUser(1, address(user), sharesToBuy * 2, usdcCost, eurcCost);

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(eurc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(usdc.balanceOf(address(factory)), 0);
        assertEq(eurc.balanceOf(address(factory)), 0);
        assertEq(opLend.balanceOf(address(user)), 0);
        assertEq(factory.fundingProgress(1), 0);
        assertEq(factory.usdcRaised(1), 0);
        assertEq(factory.eurcRaised(1), 0);
        assertEq(factory.usdcRaisedPerClient(1, address(user)), usdcCost);
        assertEq(factory.eurcRaisedPerClient(1, address(user)), eurcCost);
    }

    function test_RefundEachCoinFromEscrowOrOwner() public {
        mintEurc();
        bytes memory signature = getMintSignature(address(user), 1, sharesToBuy, testNonce);
        bytes memory signature2 = getMintSignature(address(user), 1, sharesToBuy, testNonce2);
        uint256 usdcCost = factory.getAmountIn(1, sharesToBuy);
        uint256 eurcCost = factory.getAmountInEur(1, sharesToBuy);

        vm.startPrank(user);
        usdc.approve(address(factory), UINT256_MAX);
        factory.invest(1, sharesToBuy, testNonce, signature);
        vm.stopPrank();

        vm.prank(admin);
        factory.withdrawUsdc(1, makeAddr("treasury"));

        // EURC raised after the withdrawal is still in escrow; the withdrawn USDC is paid by the owner.
        vm.startPrank(user);
        eurc.approve(address(factory), UINT256_MAX);
        factory.investEur(1, sharesToBuy, testNonce2, signature2);
        vm.stopPrank();

        vm.startPrank(admin);
        usdc.approve(address(factory), UINT256_MAX);
        factory.refundUser(1, address(user), sharesToBuy * 2, usdcCost, eurcCost);
        vm.stopPrank();

        assertEq(usdc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(eurc.balanceOf(address(user)), initialUsdcBalance);
        assertEq(usdc.balanceOf(address(admin)), initialUsdcBalance - usdcCost);
        assertEq(eurc.balanceOf(address(admin)), initialUsdcBalance);
        assertEq(eurc.balanceOf(address(factory)), 0);
        assertEq(factory.usdcRaised(1), usdcCost);
        assertEq(factory.eurcRaised(1), 0);
    }

    function test_WithdrawMixedRaiseBeforeAndAfterSaleEnd() public {
        mintEurc();
        address treasury = makeAddr("treasury");
        uint256 remainingShares = totalSharesAmount - 2 * sharesToBuy;
        bytes memory usdcSignature = getMintSignature(address(user), 1, sharesToBuy, testNonce);
        bytes memory eurcSignature = getMintSignature(address(user2), 1, sharesToBuy, testNonce2);
        bytes memory lastSignature = getMintSignature(address(user2), 1, remainingShares, "last");

        vm.prank(user);
        usdc.approve(address(factory), UINT256_MAX);
        vm.prank(user);
        factory.invest(1, sharesToBuy, testNonce, usdcSignature);

        vm.startPrank(user2);
        eurc.approve(address(factory), UINT256_MAX);
        factory.investEur(1, sharesToBuy, testNonce2, eurcSignature);
        vm.stopPrank();

        uint256 usdcRaise = factory.usdcRaised(1);
        uint256 firstEurcRaise = factory.eurcRaised(1);

        vm.prank(admin);
        factory.withdrawUsdc(1, treasury);

        assertEq(usdc.balanceOf(treasury), usdcRaise);
        assertEq(eurc.balanceOf(treasury), firstEurcRaise);
        assertEq(usdc.balanceOf(address(factory)), 0);
        assertEq(eurc.balanceOf(address(factory)), 0);
        assertEq(factory.usdcWithdrawn(1), false);

        vm.prank(admin);
        vm.expectRevert(ILendFactory.AlreadyWithdrawn.selector);
        factory.withdrawUsdc(1, treasury);

        // An EURC-only remainder must still be withdrawable and close the operation.
        vm.prank(user2);
        factory.investEur(1, remainingShares, "last", lastSignature);

        assertEq(factory.isOperationFinished(1), true);

        vm.prank(admin);
        factory.withdrawUsdc(1, treasury);

        assertEq(usdc.balanceOf(treasury), usdcRaise);
        assertEq(eurc.balanceOf(treasury), factory.eurcRaised(1));
        assertEq(eurc.balanceOf(address(factory)), 0);
        assertEq(factory.usdcWithdrawn(1), true);

        vm.prank(admin);
        vm.expectRevert(ILendFactory.AlreadyWithdrawn.selector);
        factory.withdrawUsdc(1, treasury);
    }

    function test_EurcAddressIsSetOnce() public {
        vm.prank(admin);
        vm.expectRevert("EURC already set");
        factory.setEurcAddress(address(usdc));

        assertEq(factory.eurc(), address(eurc));
    }
}
