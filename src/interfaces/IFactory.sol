// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

// Interface for ABI generation and testing only
interface ILendFactory {
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
    event PredepositsOpen(uint256 indexed operationId);
    event PredepositsClosed(uint256 indexed operationId);

    error UserBlacklisted();
    error OpNotExist();
    error OpNotStarted();
    error OpAlreadyStarted();
    error OpFinished();
    error OpNotFinished();
    error OpPaused();
    error OpCanceled();
    error TooManyShares();
    error ZeroShares();
    error InputCannotBeZero();
    error InsufficientAllowance();
    error InvalidSignature();
    error TransferFailed();
    error UserNotParticipated();
    error NoOpLendBalance();
    error AlreadyWithdrawn();
    error InvalidSignatureLength();
    error PredepositsNotOpen();

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

    function setPredeposits(uint256 id, bool state) external;

    function refundUser(uint256 id, address user) external;

    function batchRefundUsers(uint256 id, address[] calldata users, uint256 len) external;

    function cancelOperation(uint256 id) external;

    function startOperation(uint256 id) external;

    function pauseFunding(uint256 id, bool state) external;

    function updateOracleAddress(address newOracleAddress) external;

    function updateBackendSigner(address newBackendSigner) external;

    function blacklist(address user, bool state) external;

    function batchSetOpLendPeers(
        uint256[] calldata ids,
        uint32[] calldata chainIds,
        uint32[] calldata lzEids,
        bytes32[] calldata peers
    ) external;

    function setOpLendPeer(uint256 id, uint32 chainId, uint32 lzEndpointId, bytes32 peerAddress) external;

    function withdrawUsdc(uint256 id, address destination) external;

    function invest(uint256 id, uint256 sharesAmount, string calldata nonce, bytes calldata signature) external;

    function predeposit(uint256 id, uint256 sharesAmount, string calldata nonce, bytes calldata signature) external;

    function giftOpTokens(uint256 id, uint256 sharesAmount, address user) external;

    function investAndBridge(
        uint256 id,
        uint256 sharesAmount,
        string calldata nonce,
        bytes calldata signature,
        uint32 lzEndpointId
    ) external payable;

    function claimOpTokens(uint256 id, address user) external;

    function claimOpTokensAndBridge(uint256 id, uint32 lzEndpointId) external payable;

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

    function predeposits(uint256 id, address user) external view returns (uint256);

    function blacklisted(address user) external view returns (bool);

    function gifted(uint256 id, address user) external view returns (uint256);

    function transferOwnership(address _newOwner) external;

    function owner() external view returns (address);
}
