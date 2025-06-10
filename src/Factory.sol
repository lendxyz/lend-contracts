// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

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

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {LendOperation} from "./opLend.sol";
import {SignatureHelper} from "./SignatureHelper.sol";
import {SendParam, MessagingFee} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LendFactory is Ownable, SignatureHelper {
    //********** Init **********

    event OperationStarted(uint256 indexed operationId);
    event OperationCreated(address indexed opToken, uint256 indexed operationId, uint256 totalShares);
    event OperationPaused(uint256 indexed operationId, bool indexed paused);
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

    struct Operation {
        address opToken;
        uint256 totalShares;
        uint256 eurPerShares;
        string opName;
    }

    IERC20 public immutable usdc;
    uint256 public immutable opDecimals = 6;

    address private EURUSDOracle;
    address private immutable lzEndpoint;

    uint256 public operationCount = 0;

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
        address _USDCAddress,
        address _EURUSDCOracle,
        address _lzEndpoint,
        address _backendSigner
    ) Ownable(_admin) SignatureHelper(_backendSigner) {
        usdc = IERC20(_USDCAddress);
        EURUSDOracle = _EURUSDCOracle;
        lzEndpoint = _lzEndpoint;
    }
    //**********************************

    //********** Read functions **********
    function getOperation(uint256 id) external view returns (Operation memory) {
        require(id <= operationCount, "Operation does not exists");
        return operations[id];
    }

    function getAmountIn(uint256 id, uint256 sharesAmount) public view returns (uint256 usdcCost) {
        uint256 sharesPriceEur = (operations[id].eurPerShares * sharesAmount) / 10 ** 6;
        usdcCost = sharesPriceEur * getEURUSDOraclePrice() / 10 ** 6;
    }

    function getAmountOut(uint256 id, uint256 usdcAmount) public view returns (uint256 sharesAmount) {
        uint256 eurPerShares = operations[id].eurPerShares;
        uint256 oraclePrice = getEURUSDOraclePrice();

        sharesAmount = (usdcAmount * 10 ** 12) / (eurPerShares * oraclePrice);
    }

    function isOperationFinished(uint256 id) public view returns (bool) {
        return operationStarted[id] && fundingProgress[id] >= operations[id].totalShares;
    }

    function getEURUSDOraclePrice() public view returns (uint256 eurUsd) {
        (, int256 eurUsdRaw,,,) = AggregatorV3Interface(EURUSDOracle).latestRoundData();
        eurUsd = uint256(scalePrice(eurUsdRaw, AggregatorV3Interface(EURUSDOracle).decimals(), 6));
    }

    function scalePrice(int256 _price, uint8 _priceDecimals, uint8 _targetDecimals) internal pure returns (int256) {
        if (_priceDecimals < _targetDecimals) {
            return _price * int256(10 ** uint256(_targetDecimals - _priceDecimals));
        } else if (_priceDecimals > _targetDecimals) {
            return _price / int256(10 ** uint256(_priceDecimals - _targetDecimals));
        }
        return _price;
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
        string memory symbol = string(abi.encodePacked("opLEND-", Strings.toString(operationCount)));

        LendOperation newOp = new LendOperation(address(this), name, symbol, totalShares, lzEndpoint, owner());

        operations[operationCount] = Operation(address(newOp), totalShares, eurPerShares, opName);

        emit OperationCreated(address(newOp), operationCount, totalShares);

        return address(newOp);
    }

    function refundUser(uint256 id, address user) public onlyOwner {
        LendOperation opToken = LendOperation(operations[id].opToken);
        uint256 userInvestAmount = usdcRaisedPerClient[id][user];
        uint256 opLendBalance = opToken.balanceOf(user);

        require(id <= operationCount, "Operation does not exists");
        require(userInvestAmount > 0, "User has not participated");
        require(opLendBalance > 0, "User has no opLend");

        fundingProgress[id] -= opLendBalance;
        usdcRaised[id] -= userInvestAmount;
        usdcRaisedPerClient[id][user] -= userInvestAmount;

        opToken.adminBurn(user, opLendBalance);
        usdc.transfer(user, userInvestAmount);

        emit Refunded(user, id, userInvestAmount, opLendBalance);
    }

    function batchRefundUsers(uint256 id, address[] calldata users, uint256 len) external onlyOwner {
        for (uint256 i = 0; i < len; i++) {
            refundUser(id, users[i]);
        }
    }

    function cancelOperation(uint256 id) external onlyOwner {
        require(id <= operationCount, "Operation does not exists");

        operationCanceled[id] = true;
        emit OperationCanceled(id);
    }

    function startOperation(uint256 id) external onlyOwner {
        operationStarted[id] = true;
        emit OperationStarted(id);
    }

    function pauseFunding(uint256 id, bool state) external onlyOwner {
        fundingPaused[id] = state;
        emit OperationPaused(id, state);
    }

    function updateOracleAddress(address newOracleAddress) external onlyOwner {
        EURUSDOracle = newOracleAddress;
    }

    function updateBackendSigner(address newBackendSigner) external onlyOwner {
        backendSigner = newBackendSigner;
    }

    function setOpLendPeer(uint256 id, uint32 chainId, uint32 lzEndpointId, bytes32 peerAddress) external onlyOwner {
        require(id <= operationCount, "Operation does not exists");
        LendOperation opLend = LendOperation(operations[id].opToken);
        opLend.setPeer(lzEndpointId, peerAddress);

        emit OpLendPeerAdded(id, chainId, lzEndpointId, peerAddress);
    }

    function withdrawUSDC(uint256 id, address destination) external onlyOwner {
        require(id <= operationCount, "Operation does not exists");
        require(!usdcWithdrawn[id], "Already claimed USDC");
        require(!operationCanceled[id], "Operation is canceled");
        require(!fundingPaused[id], "Operation is paused");
        require(isOperationFinished(id), "Operation is not finished");

        usdcWithdrawn[id] = true;
        usdc.transfer(destination, usdcRaised[id]);
    }
    //**********************************

    //********** User-facing functions **********
    function _invest(uint256 id, uint256 sharesAmount, string calldata nonce, bytes memory signature)
        private
        returns (uint256)
    {
        require(id <= operationCount, "Operation does not exists");
        require(operationStarted[id] == true, "Operation is not started");
        require(fundingProgress[id] + sharesAmount <= operations[id].totalShares, "Cannot buy that many shares");
        require(!isOperationFinished(id), "Operation is finished");
        require(!operationCanceled[id], "Operation is canceled");
        require(!fundingPaused[id], "Operation is paused");
        require(sharesAmount > 0, "Not enough shares");

        uint256 cost = getAmountIn(id, sharesAmount);
        require(usdc.allowance(msg.sender, address(this)) >= cost, "Not enough USDC allowed to be spent");

        bool isSignatureValid = verifySignature(msg.sender, sharesAmount, id, nonce, signature);
        require(isSignatureValid, "Invalid signature");

        usdc.transferFrom(msg.sender, address(this), cost);

        fundingProgress[id] += sharesAmount;

        usdcRaised[id] += cost;
        usdcRaisedPerClient[id][msg.sender] += cost;

        emit Invested(msg.sender, id, cost, sharesAmount);

        if (fundingProgress[id] >= operations[id].totalShares) {
            emit OperationFinished(id, operations[id].totalShares * operations[id].eurPerShares);
        }

        return cost;
    }

    function invest(uint256 id, uint256 sharesAmount, string calldata nonce, bytes memory signature) public {
        _invest(id, sharesAmount, nonce, signature);
        LendOperation(operations[id].opToken).mint(msg.sender, sharesAmount);
    }

    function investAndBridge(
        uint256 id,
        uint256 sharesAmount,
        string calldata nonce,
        bytes memory signature,
        uint32 lzEndpointId
    ) public payable {
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
