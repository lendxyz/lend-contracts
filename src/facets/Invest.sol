// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ISignatureTransfer} from "../interfaces/ISignatureTransfer.sol";
import {LibDiamond} from "../lib/LibDiamond.sol";
import {Operation, AppStorage, LibAppStorage} from "../lib/Storage.sol";
import {Utils} from "../lib/Utils.sol";
import {Events} from "../lib/Utils.sol";
import {LendOperation} from "../opLend.sol";

contract Invest {
    address constant PERMIT2 = address(0x000000000022D473030F116dDEE9F6B43aC78BA3);
    uint256 private reentrancyStatus;

    modifier nonReentrant() {
        require(reentrancyStatus == 0, "ReentrancyGuard: reentrant call");
        reentrancyStatus = 1;
        _;
        reentrancyStatus = 0;
    }

    function _getPermit2Args(uint256 nonce, uint256 deadline, uint256 amount)
        internal
        view
        returns (
            ISignatureTransfer.PermitTransferFrom memory permit,
            ISignatureTransfer.SignatureTransferDetails memory transferDetails
        )
    {
        AppStorage storage s = LibAppStorage.appStorage();

        permit = ISignatureTransfer.PermitTransferFrom({
            permitted: ISignatureTransfer.TokenPermissions({token: address(s.usdc), amount: amount}),
            nonce: nonce,
            deadline: deadline
        });

        transferDetails = ISignatureTransfer.SignatureTransferDetails({to: address(this), requestedAmount: amount});
    }

    function _invest(
        uint256 id,
        uint256 sharesAmount,
        string calldata lendNonce,
        bytes calldata lendSignature,
        uint256 permit2Nonce,
        uint256 permit2Deadline,
        bytes calldata permit2Signature
    ) internal returns (uint256) {
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

        bool isSignatureValid = _verifySignature(msg.sender, sharesAmount, id, lendNonce, lendSignature);
        if (!isSignatureValid) revert Events.InvalidSignature();

        (
            ISignatureTransfer.PermitTransferFrom memory permit,
            ISignatureTransfer.SignatureTransferDetails memory transferDetails
        ) = _getPermit2Args(permit2Nonce, permit2Deadline, cost);

        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, transferDetails, msg.sender, permit2Signature);

        s.fundingProgress[id] += sharesAmount;
        s.usdcRaised[id] += cost;
        s.usdcRaisedPerClient[id][msg.sender] += cost;

        emit Events.Invested(msg.sender, id, cost, sharesAmount);

        if (s.fundingProgress[id] >= s.operations[id].totalShares) {
            emit Events.OperationFinished(id, s.operations[id].totalShares * s.operations[id].eurPerShares);
        }

        return cost;
    }

    function invest(
        uint256 id,
        uint256 sharesAmount,
        string calldata lendNonce,
        bytes calldata lendSignature,
        uint256 permit2Nonce,
        uint256 permit2Deadline,
        bytes calldata permit2Signature
    ) external nonReentrant {
        AppStorage storage s = LibAppStorage.appStorage();

        if (s.blacklisted[msg.sender]) revert Events.UserBlacklisted();

        _invest(id, sharesAmount, lendNonce, lendSignature, permit2Nonce, permit2Deadline, permit2Signature);
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

    function _bridge(uint256 id, uint256 sharesAmount, uint32 lzEndpointId) internal {
        AppStorage storage s = LibAppStorage.appStorage();

        MessagingFee memory fee = MessagingFee(msg.value, 0);
        SendParam memory sendParam = SendParam(
            lzEndpointId, // Dest eID
            bytes32(uint256(uint160(msg.sender))), // receiver
            sharesAmount, // amountLD
            sharesAmount, // minAmountLD
            hex"00030100110100000000000000000000000000013880", // 80k gas for lzReceive
            new bytes(0), // composeMsg
            new bytes(0) // oftCmd
        );

        LendOperation opLend = LendOperation(s.operations[id].opToken);

        opLend.whitelistUserAdmin(msg.sender, true);
        opLend.send{value: msg.value}(sendParam, fee, msg.sender);
    }

    function investAndBridge(
        uint256 id,
        uint256 sharesAmount,
        string calldata lendNonce,
        bytes calldata lendSignature,
        uint256 permit2Nonce,
        uint256 permit2Deadline,
        bytes calldata permit2Signature,
        uint32 lzEndpointId
    ) external payable nonReentrant {
        require(msg.value > 0, "Must include LZ fees in ethers");
        _invest(id, sharesAmount, lendNonce, lendSignature, permit2Nonce, permit2Deadline, permit2Signature);
        AppStorage storage s = LibAppStorage.appStorage();

        if (s.blacklisted[msg.sender]) revert Events.UserBlacklisted();

        LendOperation(s.operations[id].opToken).mint(address(this), sharesAmount);

        _bridge(id, sharesAmount, lzEndpointId);
    }

    function giftOpTokens(
        uint256 id,
        uint256 sharesAmount,
        address user,
        uint256 permit2Nonce,
        uint256 permit2Deadline,
        bytes calldata permit2Signature
    ) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();

        bool isOpFinished = s.operationStarted[id] && s.fundingProgress[id] >= s.operations[id].totalShares;

        if (s.blacklisted[user]) revert Events.UserBlacklisted();
        if (isOpFinished) revert Events.OpFinished();
        if (id > s.operationCount) revert Events.OpNotExist();
        if (s.fundingProgress[id] + sharesAmount > s.operations[id].totalShares) revert Events.TooManyShares();
        if (s.operationCanceled[id]) revert Events.OpCanceled();
        if (s.fundingPaused[id]) revert Events.OpPaused();
        if (sharesAmount <= 0) revert Events.ZeroShares();

        uint256 cost = this.getAmountIn(id, sharesAmount);

        (
            ISignatureTransfer.PermitTransferFrom memory permit,
            ISignatureTransfer.SignatureTransferDetails memory transferDetails
        ) = _getPermit2Args(permit2Nonce, permit2Deadline, cost);

        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, transferDetails, msg.sender, permit2Signature);

        s.fundingProgress[id] += sharesAmount;
        s.usdcRaised[id] += cost;
        s.usdcRaisedPerClient[id][user] += cost;
        s.gifted[id][user] += sharesAmount;

        emit Events.Invested(user, id, cost, sharesAmount);
        emit Events.Gifted(user, id, cost, sharesAmount);

        if (s.fundingProgress[id] >= s.operations[id].totalShares) {
            s.operationStarted[id] = true;
            emit Events.OperationFinished(id, s.operations[id].totalShares * s.operations[id].eurPerShares);
        }
    }

    function predeposit(
        uint256 id,
        uint256 sharesAmount,
        string calldata lendNonce,
        bytes calldata lendSignature,
        uint256 permit2Nonce,
        uint256 permit2Deadline,
        bytes calldata permit2Signature
    ) external nonReentrant {
        AppStorage storage s = LibAppStorage.appStorage();

        bool isOpFinished = s.operationStarted[id] && s.fundingProgress[id] >= s.operations[id].totalShares;

        if (isOpFinished) revert Events.OpFinished();
        if (s.blacklisted[msg.sender]) revert Events.UserBlacklisted();
        if (id > s.operationCount) revert Events.OpNotExist();
        if (s.operationStarted[id]) revert Events.OpAlreadyStarted();
        if (!s.predepositsOpen[id]) revert Events.PredepositsNotOpen();
        if (s.fundingProgress[id] + sharesAmount > s.operations[id].totalShares) revert Events.TooManyShares();
        if (s.operationCanceled[id]) revert Events.OpCanceled();
        if (s.fundingPaused[id]) revert Events.OpPaused();
        if (sharesAmount <= 0) revert Events.ZeroShares();

        uint256 cost = this.getAmountIn(id, sharesAmount);

        bool isSignatureValid = _verifySignature(msg.sender, sharesAmount, id, lendNonce, lendSignature);
        if (!isSignatureValid) revert Events.InvalidSignature();

        (
            ISignatureTransfer.PermitTransferFrom memory permit,
            ISignatureTransfer.SignatureTransferDetails memory transferDetails
        ) = _getPermit2Args(permit2Nonce, permit2Deadline, cost);

        ISignatureTransfer(PERMIT2).permitTransferFrom(permit, transferDetails, msg.sender, permit2Signature);

        s.fundingProgress[id] += sharesAmount;
        s.usdcRaised[id] += cost;
        s.usdcRaisedPerClient[id][msg.sender] += cost;
        s.predeposits[id][msg.sender] += sharesAmount;

        emit Events.Invested(msg.sender, id, cost, sharesAmount);
        emit Events.Predeposit(msg.sender, id, cost, sharesAmount);

        if (s.fundingProgress[id] >= s.operations[id].totalShares) {
            s.operationStarted[id] = true;
            emit Events.OperationFinished(id, s.operations[id].totalShares * s.operations[id].eurPerShares);
        }
    }

    function _claimToken(uint256 id, address user, address dest) internal {
        AppStorage storage s = LibAppStorage.appStorage();

        if (s.blacklisted[user]) revert Events.UserBlacklisted();

        uint256 amount = s.gifted[id][user] + s.predeposits[id][user];

        if (s.predeposits[id][user] > 0) {
            s.predeposits[id][user] = 0;
        }

        if (s.gifted[id][user] > 0) {
            s.gifted[id][user] = 0;
        }

        if (amount > 0) {
            LendOperation(s.operations[id].opToken).mint(dest, amount);
            emit Events.ClaimedOpToken(user, id, amount);
        }
    }

    function claimOpTokens(uint256 id, address user) external {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        if (!s.operationStarted[id]) revert Events.OpNotStarted();

        _claimToken(id, user, user);
    }

    function claimOpTokensAndBridge(uint256 id, uint32 lzEndpointId) external payable nonReentrant {
        AppStorage storage s = LibAppStorage.appStorage();

        uint256 amount = s.gifted[id][msg.sender] + s.predeposits[id][msg.sender];

        if (amount > 0) {
            _claimToken(id, msg.sender, address(this));
            _bridge(id, amount, lzEndpointId);
        }
    }

    function claimOpTokensBatch(uint256 id, address[] memory users) external {
        for (uint256 i = 0; i < users.length; i++) {
            this.claimOpTokens(id, users[i]);
        }
    }

    function getAmountIn(uint256 id, uint256 sharesAmount) external view returns (uint256 usdcCost) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        if (sharesAmount <= 0) revert Events.InputCannotBeZero();

        uint256 sharesPriceEur = (s.operations[id].eurPerShares * sharesAmount) / 10 ** 6;
        usdcCost = sharesPriceEur * Utils.getEurUsdOraclePrice(s.eurUsdOracle) / 10 ** 6;

        if (usdcCost <= 0) {
            usdcCost = 1;
        }
    }

    function getAmountOut(uint256 id, uint256 usdcAmount) external view returns (uint256 sharesAmount) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        if (usdcAmount <= 0) revert Events.InputCannotBeZero();

        uint256 eurPerShares = s.operations[id].eurPerShares;
        uint256 oraclePrice = Utils.getEurUsdOraclePrice(s.eurUsdOracle);

        sharesAmount = (usdcAmount * 10 ** 12) / (eurPerShares * oraclePrice);

        if (sharesAmount <= 0) {
            sharesAmount = 1;
        }
    }
}
