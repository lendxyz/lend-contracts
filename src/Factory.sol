// SPDX-License-Identifier: MIT
//
//         ++++++++++++++++++++++
//        ++++++++++++++++++++++++
//        ++++++++++++++++++++++++++++++++
//        +++++++++               +++++++++
//         ++++++++++++++++++++++++++++++++
//                 ++++++++++++++++++++++++
//                  ++++++++++++++++++++++
//
//  +++++++                                      ++++
//  +++++++                                      ++++
//    +++++       +++            +++        ++   ++++
//    +++++   ++++++++++  +++++++++++++  ++++++++++++
//    +++++  +++++   ++++++++++++++++++++++++++++++++
//    +++++  ++++++++++++++++++    +++++++++     ++++
//    +++++  +++++        ++++     +++++++++    +++++
//   +++++++++++++++++++++++++     ++++++++++++++++++
//   +++++++++ +++++++++  ++++     +++++ ++++++++++++
//
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {LendOperation} from "./opLend.sol";
import {SignatureHelper} from "./lib/SignatureHelper.sol";
import {LendUtils} from "./lib/LendUtils.sol";

contract LendFactory is Ownable, SignatureHelper {
    using LendUtils for *;

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

    IERC20 public immutable USDC;

    address private eurUsdOracle;
    address private immutable LZ_ENDPOINT;

    uint256 public operationCount = 0;

    uint256 private reentrancyStatus;

    modifier nonReentrant() {
        require(reentrancyStatus == 0, "ReentrancyGuard: reentrant call");
        reentrancyStatus = 1;
        _;
        reentrancyStatus = 0;
    }

    mapping(uint256 => Operation) public operations;
    mapping(uint256 => uint256) public fundingProgress;
    mapping(uint256 => uint256) public usdcRaised;
    mapping(uint256 => bool) public operationCanceled;
    mapping(uint256 => mapping(address => uint256)) public usdcRaisedPerClient;
    mapping(uint256 => bool) public usdcWithdrawn;
    mapping(uint256 => bool) public fundingPaused;
    mapping(uint256 => bool) public operationStarted;

    constructor(
        address _admin,
        address _usdcAddress,
        address _eurUsdOracle,
        address _lzEndpoint,
        address _backendSigner
    ) Ownable(_admin) SignatureHelper(_backendSigner) {
        USDC = IERC20(_usdcAddress);
        eurUsdOracle = _eurUsdOracle;
        LZ_ENDPOINT = _lzEndpoint;
    }

    //********** Read functions **********
    function getOperation(uint256 id) external view returns (Operation memory) {
        if (id > operationCount) revert OpNotExist();
        return operations[id];
    }

    function getAmountIn(uint256 id, uint256 sharesAmount) public view returns (uint256 usdcCost) {
        uint256 sharesPriceEur = (operations[id].eurPerShares * sharesAmount) / 10 ** 6;
        usdcCost = sharesPriceEur * LendUtils.getEurUsdOraclePrice(eurUsdOracle) / 10 ** 6;
    }

    function getAmountOut(uint256 id, uint256 usdcAmount) public view returns (uint256 sharesAmount) {
        uint256 eurPerShares = operations[id].eurPerShares;
        uint256 oraclePrice = LendUtils.getEurUsdOraclePrice(eurUsdOracle);

        sharesAmount = (usdcAmount * 10 ** 12) / (eurPerShares * oraclePrice);
    }

    function isOperationFinished(uint256 id) public view returns (bool) {
        return operationStarted[id] && fundingProgress[id] >= operations[id].totalShares;
    }

    //**********************************

    //********** Operation management **********
    function createOperation(string calldata opName, uint256 totalShares, uint256 eurPerShares)
        external
        onlyOwner
        returns (address)
    {
        unchecked {
            operationCount++;
        }

        string memory name = string(abi.encodePacked("Lend Operation - ", opName));
        string memory symbol = string(abi.encodePacked("opLEND-", LendUtils.uintToString(operationCount)));

        LendOperation newOp =
            new LendOperation(address(this), name, symbol, totalShares, LZ_ENDPOINT, owner(), backendSigner);

        operations[operationCount] = Operation(address(newOp), totalShares, eurPerShares, opName);

        emit OperationCreated(address(newOp), operationCount, totalShares);

        return address(newOp);
    }

    function refundUser(uint256 id, address user) public onlyOwner {
        LendOperation opToken = LendOperation(operations[id].opToken);
        uint256 userInvestAmount = usdcRaisedPerClient[id][user];
        uint256 opLendBalance = opToken.balanceOf(user);

        if (id > operationCount) revert OpNotExist();
        if (userInvestAmount == 0) revert UserNotParticipated();
        if (opLendBalance == 0) revert NoOpLendBalance();

        fundingProgress[id] -= opLendBalance;
        usdcRaised[id] -= userInvestAmount;
        usdcRaisedPerClient[id][user] -= userInvestAmount;

        opToken.adminBurn(user, opLendBalance);
        require(USDC.transfer(user, userInvestAmount), TransferFailed());

        emit Refunded(user, id, userInvestAmount, opLendBalance);
    }

    function batchRefundUsers(uint256 id, address[] calldata users, uint256 len) external onlyOwner {
        for (uint256 i = 0; i < len; i++) {
            refundUser(id, users[i]);
        }
    }

    function cancelOperation(uint256 id) external onlyOwner {
        if (id > operationCount) revert OpNotExist();

        operationCanceled[id] = true;
        emit OperationCanceled(id);
    }

    function startOperation(uint256 id) external onlyOwner {
        operationStarted[id] = true;
        emit OperationStarted(id);
    }

    function pauseFunding(uint256 id, bool state) external onlyOwner {
        fundingPaused[id] = state;
        if (state) {
            emit OperationPaused(id);
        } else {
            emit OperationResumed(id);
        }
    }

    function updateOracleAddress(address newOracleAddress) external onlyOwner {
        eurUsdOracle = newOracleAddress;
    }

    function updateBackendSigner(address newBackendSigner) external onlyOwner {
        backendSigner = newBackendSigner;
    }

    function setOpLendPeer(uint256 id, uint32 chainId, uint32 lzEndpointId, bytes32 peerAddress) external onlyOwner {
        if (id > operationCount) revert OpNotExist();
        LendOperation opLend = LendOperation(operations[id].opToken);
        opLend.setPeer(lzEndpointId, peerAddress);

        emit OpLendPeerAdded(id, chainId, lzEndpointId, peerAddress);
    }

    function withdrawUsdc(uint256 id, address destination) external onlyOwner {
        if (id > operationCount) revert OpNotExist();
        if (usdcWithdrawn[id]) revert AlreadyWithdrawn();
        if (!isOperationFinished(id)) revert OpNotFinished();

        usdcWithdrawn[id] = true;
        require(USDC.transfer(destination, usdcRaised[id]), TransferFailed());
    }
    //**********************************

    //********** User-facing functions **********
    function _invest(uint256 id, uint256 sharesAmount, string calldata nonce, bytes memory signature)
        private
        returns (uint256)
    {
        if (id > operationCount) revert OpNotExist();
        if (!operationStarted[id]) revert OpNotStarted();
        if (fundingProgress[id] + sharesAmount > operations[id].totalShares) revert TooManyShares();
        if (isOperationFinished(id)) revert OpFinished();
        if (operationCanceled[id]) revert OpCanceled();
        if (fundingPaused[id]) revert OpPaused();
        if (sharesAmount <= 0) revert ZeroShares();

        uint256 cost = getAmountIn(id, sharesAmount);

        bool isSignatureValid = verifySignatureMint(msg.sender, sharesAmount, id, nonce, signature);
        if (!isSignatureValid) revert InvalidSignature();
        if (USDC.allowance(msg.sender, address(this)) < cost) revert InsufficientAllowance();
        require(USDC.transferFrom(msg.sender, address(this), cost), TransferFailed());

        fundingProgress[id] += sharesAmount;

        usdcRaised[id] += cost;
        usdcRaisedPerClient[id][msg.sender] += cost;

        emit Invested(msg.sender, id, cost, sharesAmount);

        if (fundingProgress[id] >= operations[id].totalShares) {
            emit OperationFinished(id, operations[id].totalShares * operations[id].eurPerShares);
        }

        return cost;
    }

    function invest(uint256 id, uint256 sharesAmount, string calldata nonce, bytes memory signature)
        public
        nonReentrant
    {
        _invest(id, sharesAmount, nonce, signature);
        LendOperation(operations[id].opToken).mint(msg.sender, sharesAmount);
    }

    function investAndBridge(
        uint256 id,
        uint256 sharesAmount,
        string calldata nonce,
        bytes memory signature,
        uint32 lzEndpointId
    ) public payable nonReentrant {
        require(msg.value > 0, "Must include LZ fees in ethers");
        _invest(id, sharesAmount, nonce, signature);

        LendOperation(operations[id].opToken).mint(address(this), sharesAmount);

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

        LendOperation(operations[id].opToken).send{value: msg.value}(sendParam, fee, msg.sender);
    }

    //**********************************
}
