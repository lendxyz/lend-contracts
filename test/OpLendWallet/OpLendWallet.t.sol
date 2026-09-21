// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {TestBase} from "../TestBase.t.sol";
import {LendOperation} from "../../src/opLend.sol";

contract OpLendWalletTest is Test, TestBase {
    uint256 opId = 1;
    uint256 otherOpId = 2;
    uint256 unknownOpId = 42;

    uint256 walletShares;
    uint256 redeemAmount;

    LendOperation walletOpLend;

    function setUp() public virtual override(TestBase) {
        super.setUp();

        walletShares = 10_000 * 10 ** sharesDecimal;
        redeemAmount = 1_000 * 10 ** sharesDecimal;
    }

    //********** Fixtures **********

    /// @dev Creates and starts a factory operation. Ids are sequential, the first one is `opId`.
    function newFactoryOp() public returns (uint256 id, LendOperation op) {
        vm.startPrank(admin);

        op = LendOperation(factory.createOperation("Test operation", totalSharesAmount, sharePriceEur));
        id = factory.operationCount();
        factory.startOperation(id);

        vm.stopPrank();
    }

    /// @dev Production funding path: `fiatInvest` mints the shares to `_holder` and whitelists `_buyer`.
    function fiatFund(uint256 _id, address _holder, address _buyer, uint256 _amount, string memory _nonce) public {
        bytes memory signature = getMintSignatureFiat(_buyer, _holder, _id, _amount, _nonce);

        vm.prank(_buyer);
        factory.fiatInvest(_id, _amount, _buyer, _holder, _nonce, signature);
    }

    function registerOp(uint256 _id, address _opLend) public {
        vm.prank(admin);
        opLendWallet.registerOpLendAddress(_id, _opLend);
    }

    /// @dev `opId` created and registered, wallet holding `walletShares` bought by `user` (whitelisted).
    function fundedWallet() public returns (LendOperation op) {
        (uint256 id, LendOperation created) = newFactoryOp();

        fiatFund(id, address(opLendWallet), user, walletShares, testNonce);
        registerOp(id, address(created));

        walletOpLend = created;
        return created;
    }

    /// @dev A second registered and funded operation, used for cross-operation isolation checks.
    function fundedOtherOp() public returns (LendOperation op) {
        (uint256 id, LendOperation created) = newFactoryOp();

        fiatFund(id, address(opLendWallet), user2, walletShares, testNonce2);
        registerOp(id, address(created));

        return created;
    }

    /// @dev opLend living outside the factory: lets the wallet hold shares it is not whitelisted for.
    function standaloneOpLend() public returns (LendOperation op) {
        vm.prank(admin);
        op = new LendOperation(
            admin, "Standalone op", "SOP", totalSharesAmount, mnFactArgs.lzEndpoint, admin, backendSigner
        );
    }

    //********** Signatures **********

    function getRedeemSignature(uint256 _opId, address _destination, uint256 _amount, string memory _nonce)
        public
        view
        returns (bytes memory)
    {
        return signRedeem(backendSignerPk, block.chainid, _opId, _destination, _amount, _nonce);
    }

    function signRedeem(
        uint256 _pk,
        uint256 _chainId,
        uint256 _opId,
        address _destination,
        uint256 _amount,
        string memory _nonce
    ) public pure returns (bytes memory) {
        bytes32 digest = keccak256(abi.encodePacked("OP_REDEEM", _opId, _chainId, _destination, _amount, _nonce));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(_pk, hash);

        return abi.encodePacked(r, s, v);
    }
}
