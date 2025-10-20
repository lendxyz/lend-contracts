// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

library Events {
    event ClaimedOpToken(address indexed investor, uint256 indexed operationId, uint256 indexed amount);
    event OperationStarted(uint256 indexed operationId);
    event OperationCreated(address indexed opToken, uint256 indexed operationId, uint256 totalShares);
    event OperationPaused(uint256 indexed operationId);
    event OperationResumed(uint256 indexed operationId);
    event OperationCanceled(uint256 indexed operationId);
    event OperationFinished(uint256 indexed operationId, uint256 indexed amountRaisedEuro);
    event OpLendPeerAdded(
        uint256 indexed operationId, uint32 chainId, uint32 indexed lzEndpointId, bytes32 indexed peerAddress
    );
    event Refunded(
        address indexed investor, uint256 indexed operationId, uint256 indexed usdcAmount, uint256 sharesRefunded
    );
    event Invested(
        address indexed investor, uint256 indexed operationId, uint256 indexed usdcAmount, uint256 sharesBought
    );
    event Gifted(
        address indexed investor, uint256 indexed operationId, uint256 indexed usdcAmount, uint256 sharesBought
    );
    event Predeposit(
        address indexed investor, uint256 indexed operationId, uint256 indexed usdcAmount, uint256 sharesBought
    );

    error OpNotExist();
    error OpNotStarted();
    error OpAlreadyStarted();
    error OpFinished();
    error OpNotFinished();
    error OpPaused();
    error OpCanceled();
    error TooManyShares();
    error ZeroShares();
    error InsufficientAllowance();
    error InvalidSignature();
    error TransferFailed();
    error UserNotParticipated();
    error NoOpLendBalance();
    error AlreadyWithdrawn();
    error InvalidSignatureLength();
}
