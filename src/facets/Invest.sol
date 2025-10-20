// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {LibDiamond} from "../lib/LibDiamond.sol";
import {Operation, AppStorage, LibAppStorage} from "../lib/Storage.sol";
import {Utils} from "../lib/Utils.sol";
import {Events} from "../lib/Utils.sol";
import {LendOperation} from "../opLend.sol";

contract Invest {
    uint256 private reentrancyStatus;

    modifier nonReentrant() {
        require(reentrancyStatus == 0, "ReentrancyGuard: reentrant call");
        reentrancyStatus = 1;
        _;
        reentrancyStatus = 0;
    }

    function _invest(uint256 id, uint256 sharesAmount, string calldata nonce, bytes memory signature)
        internal
        returns (uint256)
    {
        AppStorage storage s = LibAppStorage.appStorage();

        bool isOpFinished = s.operationStarted[id] && s.fundingProgress[id] >= s.operations[id].totalShares;

        if (isOpFinished) revert Events.OpFinished();
        if (id > s.operationCount) revert Events.OpNotExist();
        if (!s.operationStarted[id]) revert Events.OpNotStarted();
        if (s.fundingProgress[id] + sharesAmount > s.operations[id].totalShares) revert Events.TooManyShares();
        if (s.operationCanceled[id]) revert Events.OpCanceled();
        if (s.fundingPaused[id]) revert Events.OpPaused();
        if (sharesAmount <= 0) revert Events.ZeroShares();

        uint256 cost = this.getAmountIn(id, sharesAmount);

        bool isSignatureValid = _verifySignature(msg.sender, sharesAmount, id, nonce, signature);
        if (!isSignatureValid) revert Events.InvalidSignature();
        if (s.usdc.allowance(msg.sender, address(this)) < cost) revert Events.InsufficientAllowance();

        s.fundingProgress[id] += sharesAmount;
        s.usdcRaised[id] += cost;
        s.usdcRaisedPerClient[id][msg.sender] += cost;

        require(s.usdc.transferFrom(msg.sender, address(this), cost), Events.TransferFailed());
        emit Events.Invested(msg.sender, id, cost, sharesAmount);

        if (s.fundingProgress[id] >= s.operations[id].totalShares) {
            emit Events.OperationFinished(id, s.operations[id].totalShares * s.operations[id].eurPerShares);
        }

        return cost;
    }

    function invest(uint256 id, uint256 sharesAmount, string calldata nonce, bytes memory signature)
        external
        nonReentrant
    {
        AppStorage storage s = LibAppStorage.appStorage();

        _invest(id, sharesAmount, nonce, signature);
        LendOperation(s.operations[id].opToken).mint(msg.sender, sharesAmount);
    }

    function _verifySignature(
        address _user,
        uint256 _amount,
        uint256 _opId,
        string calldata _nonce,
        bytes memory _signature
    ) internal returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (s.usedNonces[_nonce]) {
            return false;
        }

        bytes32 messageHash = keccak256(abi.encodePacked(_opId, _user, _amount, _nonce));
        bytes32 ethSignedMessageHash = Utils.computeEthSignedHash(messageHash);
        address recovered = Utils.recoverSigner(ethSignedMessageHash, _signature);
        bool isValid = recovered == s.backendSigner;

        if (isValid) {
            s.usedNonces[_nonce] = true;
            s.mintAllowance[_opId][_user] += _amount;
        }

        return isValid;
    }

    function investAndBridge(
        uint256 id,
        uint256 sharesAmount,
        string calldata nonce,
        bytes memory signature,
        uint32 lzEndpointId
    ) external payable nonReentrant {
        require(msg.value > 0, "Must include LZ fees in ethers");
        _invest(id, sharesAmount, nonce, signature);
        AppStorage storage s = LibAppStorage.appStorage();

        LendOperation(s.operations[id].opToken).mint(address(this), sharesAmount);

        MessagingFee memory fee = MessagingFee(msg.value, 0);
        SendParam memory sendParam = SendParam(
            lzEndpointId,
            bytes32(uint256(uint160(msg.sender))),
            sharesAmount,
            sharesAmount,
            hex"0003010011010000000000000000000000000000ea60",
            new bytes(0),
            new bytes(0)
        );

        LendOperation(s.operations[id].opToken).send{value: msg.value}(sendParam, fee, msg.sender);
    }

    function giftOpTokens(uint256 id, uint256 sharesAmount, address user) external {
        AppStorage storage s = LibAppStorage.appStorage();
        LibDiamond.enforceIsContractOwner();

        bool isOpFinished = s.operationStarted[id] && s.fundingProgress[id] >= s.operations[id].totalShares;

        if (isOpFinished) revert Events.OpFinished();
        if (id > s.operationCount) revert Events.OpNotExist();
        if (s.fundingProgress[id] + sharesAmount > s.operations[id].totalShares) revert Events.TooManyShares();
        if (s.operationCanceled[id]) revert Events.OpCanceled();
        if (s.fundingPaused[id]) revert Events.OpPaused();
        if (sharesAmount <= 0) revert Events.ZeroShares();

        uint256 cost = this.getAmountIn(id, sharesAmount);

        if (s.usdc.allowance(msg.sender, address(this)) < cost) revert Events.InsufficientAllowance();

        s.fundingProgress[id] += sharesAmount;
        s.usdcRaised[id] += cost;
        s.usdcRaisedPerClient[id][user] += cost;
        s.gifted[id][user] += sharesAmount;

        require(s.usdc.transferFrom(msg.sender, address(this), cost), Events.TransferFailed());

        emit Events.Invested(user, id, cost, sharesAmount);
        emit Events.Gifted(user, id, cost, sharesAmount);

        if (s.fundingProgress[id] >= s.operations[id].totalShares) {
            s.operationStarted[id] = true;
            emit Events.OperationFinished(id, s.operations[id].totalShares * s.operations[id].eurPerShares);
        }
    }


    function predeposit(uint256 id, uint256 sharesAmount, string calldata nonce, bytes memory signature)
        external
        nonReentrant
    {
        AppStorage storage s = LibAppStorage.appStorage();

        bool isOpFinished = s.operationStarted[id] && s.fundingProgress[id] >= s.operations[id].totalShares;

        if (isOpFinished) revert Events.OpFinished();
        if (id > s.operationCount) revert Events.OpNotExist();
        if (s.operationStarted[id]) revert Events.OpAlreadyStarted();
        if (s.fundingProgress[id] + sharesAmount > s.operations[id].totalShares) revert Events.TooManyShares();
        if (s.operationCanceled[id]) revert Events.OpCanceled();
        if (s.fundingPaused[id]) revert Events.OpPaused();
        if (sharesAmount <= 0) revert Events.ZeroShares();

        uint256 cost = this.getAmountIn(id, sharesAmount);

        bool isSignatureValid = _verifySignature(msg.sender, sharesAmount, id, nonce, signature);
        if (!isSignatureValid) revert Events.InvalidSignature();
        if (s.usdc.allowance(msg.sender, address(this)) < cost) revert Events.InsufficientAllowance();

        s.fundingProgress[id] += sharesAmount;
        s.usdcRaised[id] += cost;
        s.usdcRaisedPerClient[id][msg.sender] += cost;
        s.predeposits[id][msg.sender] += sharesAmount;

        require(s.usdc.transferFrom(msg.sender, address(this), cost), Events.TransferFailed());

        emit Events.Invested(msg.sender, id, cost, sharesAmount);
        emit Events.Predeposit(msg.sender, id, cost, sharesAmount);

        if (s.fundingProgress[id] >= s.operations[id].totalShares) {
            s.operationStarted[id] = true;
            emit Events.OperationFinished(id, s.operations[id].totalShares * s.operations[id].eurPerShares);
        }
    }

    function claimOpTokens(uint256 id, address user) external {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        if (!s.operationStarted[id]) revert Events.OpNotStarted();

        uint256 amount = s.gifted[id][user] + s.predeposits[id][user];

        if (s.predeposits[id][user] > 0) {
            s.predeposits[id][user] = 0;
        }

        if (s.gifted[id][user] > 0) {
            s.gifted[id][user] = 0;
        }

        if (amount > 0) {
            LendOperation(s.operations[id].opToken).mint(user, amount);
            emit Events.ClaimedOpToken(user, id, amount);
        }
    }

    function claimOpTokensBatch(uint256 id, address[] memory users) external {
        for (uint256 i = 0; i < users.length; i++) {
            this.claimOpTokens(id, users[i]);
        }
    }

    function getAmountIn(uint256 id, uint256 sharesAmount) external view returns (uint256 usdcCost) {
        AppStorage storage s = LibAppStorage.appStorage();

        uint256 sharesPriceEur = (s.operations[id].eurPerShares * sharesAmount) / 10 ** 6;
        usdcCost = sharesPriceEur * Utils.getEurUsdOraclePrice(s.eurUsdOracle) / 10 ** 6;
    }

    function getAmountOut(uint256 id, uint256 usdcAmount) external view returns (uint256 sharesAmount) {
        AppStorage storage s = LibAppStorage.appStorage();

        uint256 eurPerShares = s.operations[id].eurPerShares;
        uint256 oraclePrice = Utils.getEurUsdOraclePrice(s.eurUsdOracle);

        sharesAmount = (usdcAmount * 10 ** 12) / (eurPerShares * oraclePrice);
    }
}
