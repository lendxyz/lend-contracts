// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Interface for ABI generation and testing only
interface ILendFactory {
    event OperationStarted(uint256 indexed operationId);
    event OperationCreated(address indexed opToken, uint256 indexed operationId, uint256 totalShares);
    event OperationPaused(uint256 indexed operationId);
    event OperationResumed(uint256 indexed operationId);
    event OperationCanceled(uint256 indexed operationId);
    event OpLendPeerAdded(
        uint256 indexed operationId, uint32 chainId, uint32 indexed lzEndpointId, bytes32 indexed peerAddress
    );
    event Refunded(
        address indexed investor, uint256 indexed operationId, uint256 indexed usdcAmount, uint256 sharesRefunded
    );
    event Invested(
        address indexed investor, uint256 indexed operationId, uint256 indexed usdcAmount, uint256 sharesBought
    );
    event OperationFinished(uint256 indexed operationId, uint256 indexed amountRaisedEuro);

    error OpNotExist();
    error OpNotStarted();
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

    struct Operation {
        address opToken;
        uint256 totalShares;
        uint256 eurPerShares;
        string opName;
    }

    function getOperation(uint256 id) external view returns (Operation memory);

    function getAmountIn(uint256 id, uint256 sharesAmount) external view returns (uint256 usdcCost);

    function getAmountOut(uint256 id, uint256 usdcAmount) external view returns (uint256 sharesAmount);

    function isOperationFinished(uint256 id) external view returns (bool);

    function createOperation(string calldata opName, uint256 totalShares, uint256 eurPerShares)
        external
        returns (address);

    function refundUser(uint256 id, address user) external;

    function batchRefundUsers(uint256 id, address[] calldata users, uint256 len) external;

    function cancelOperation(uint256 id) external;

    function startOperation(uint256 id) external;

    function pauseFunding(uint256 id, bool state) external;

    function updateOracleAddress(address newOracleAddress) external;

    function updateBackendSigner(address newBackendSigner) external;

    function batchSetOpLendPeers(
        uint256[] calldata ids,
        uint32[] calldata chainIds,
        uint32[] calldata lzEids,
        bytes32[] calldata peers
    ) external;

    function setOpLendPeer(uint256 id, uint32 chainId, uint32 lzEndpointId, bytes32 peerAddress) external;

    function withdrawUsdc(uint256 id, address destination) external;

    function invest(uint256 id, uint256 sharesAmount, string calldata nonce, bytes memory signature) external;

    function investAndBridge(
        uint256 id,
        uint256 sharesAmount,
        string calldata nonce,
        bytes memory signature,
        uint32 lzEndpointId
    ) external payable;

    function usdc() external view returns (address);

    function operationCount() external view returns (uint256);

    function operations(uint256 id) external view returns (Operation memory);

    function fundingProgress(uint256 id) external view returns (uint256);

    function usdcRaised(uint256 id) external view returns (uint256);

    function fundingPaused(uint256 id) external view returns (bool);

    function operationStarted(uint256 id) external view returns (bool);

    function usdcWithdrawn(uint256 id) external view returns (bool);

    function operationCanceled(uint256 id) external view returns (bool);

    function usdcRaisedPerClient(uint256 id, address user) external view returns (uint256);
}
