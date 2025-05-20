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
import {ERC1155Holder} from "@openzeppelin/contracts/token/ERC1155/utils/ERC1155Holder.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {ILendDebt} from "./interfaces/IdLend.sol";
import {LendOperation} from "./opLend.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LendFactory is Ownable, ERC1155Holder {
    //********** Init **********

    event OperationCreated(address indexed opToken, uint256 indexed operationId, uint256 totalShares);
    event OperationCanceled(uint256 indexed operationId);
    event OpTokenClaimed(address indexed opToken, address indexed recipient, uint256 amount);
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

    ILendDebt public dLEND;
    IERC20 public immutable usdc;

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

    constructor(address _admin, address _USDCAddress, address _EURUSDCOracle, address _lzEndpoint) Ownable(_admin) {
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
        // 18: operation decimals - 6: USDC decimals

        uint256 sharesPriceEur = (operations[id].eurPerShares * sharesAmount) / 10 ** 18;
        uint256 sharesPriceEurConverted = uint256(scalePrice(int256(sharesPriceEur), 18, 6));

        usdcCost = sharesPriceEurConverted * getEURUSDOraclePrice() / 10 ** 6;
    }

    function getAmountOut(uint256 id, uint256 usdcAmount) public view returns (uint256 sharesAmount) {
        uint256 eurPerShares = operations[id].eurPerShares; // 18 decimals
        uint256 oraclePrice = getEURUSDOraclePrice(); // 6 decimals

        sharesAmount = (usdcAmount * 10 ** 36) / (eurPerShares * oraclePrice);
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

        dLEND.setMaxSupply(operationCount, totalShares);

        operations[operationCount] = Operation(address(newOp), totalShares, eurPerShares, opName);

        emit OperationCreated(address(newOp), operationCount, totalShares);

        return address(newOp);
    }

    function _refund(uint256 id, address user) internal {
        uint256 userInvestAmount = usdcRaisedPerClient[id][user];
        uint256 userDlendBalance = dLEND.balanceOf(user, id);

        require(id <= operationCount, "Operation does not exists");
        require(userInvestAmount > 0, "User has not participated");
        require(userDlendBalance > 0, "User has no dLend");
        require(LendOperation(operations[id].opToken).balanceOf(user) == 0, "User has already claimed opLend tokens");

        fundingProgress[id] -= userDlendBalance;
        usdcRaised[id] -= userInvestAmount;
        usdcRaisedPerClient[id][user] -= userInvestAmount;

        dLEND.adminBurn(user, id, userDlendBalance);
        usdc.transfer(user, userInvestAmount);

        emit Refunded(user, id, userInvestAmount, userDlendBalance);
    }

    function refundUser(uint256 id, address user) public onlyOwner {
        _refund(id, user);
    }

    function selfRefund(uint256 id) public {
        _refund(id, msg.sender);
    }

    function batchRefundUsers(uint256 id, address[] calldata users, uint256 len) external onlyOwner {
        for (uint256 i = 0; i < len; i++) {
            refundUser(id, users[i]);
        }
    }

    function setDLendAddress(address dlend) external onlyOwner {
        dLEND = ILendDebt(dlend);
    }

    function cancelOperation(uint256 id) external onlyOwner {
        require(id <= operationCount, "Operation does not exists");

        operationCanceled[id] = true;
        emit OperationCanceled(id);
    }

    function startOperation(uint256 id) external onlyOwner {
        operationStarted[id] = true;
    }

    function pauseFunding(uint256 id, bool state) external onlyOwner {
        fundingPaused[id] = state;
    }

    function updateOracleAddress(address newOracleAddress) external onlyOwner {
        EURUSDOracle = newOracleAddress;
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
    function invest(uint256 id, uint256 usdcAmount) external {
        require(id <= operationCount, "Operation does not exists");
        require(operationStarted[id] == true, "Operation is not started");
        require(!isOperationFinished(id), "Operation is finished");
        require(!operationCanceled[id], "Operation is canceled");
        require(!fundingPaused[id], "Operation is paused");
        require(usdc.allowance(msg.sender, address(this)) >= usdcAmount, "Not enough tokens allowed to be spent");

        uint256 sharesAmount = getAmountOut(id, usdcAmount);

        require(fundingProgress[id] + sharesAmount <= operations[id].totalShares, "Cannot buy that many shares");
        require(sharesAmount > 0, "Not enough shares");

        usdc.transferFrom(msg.sender, address(this), usdcAmount);

        fundingProgress[id] += sharesAmount;

        dLEND.mint(msg.sender, id, sharesAmount, "");

        usdcRaised[id] += usdcAmount;
        usdcRaisedPerClient[id][msg.sender] += usdcAmount;

        emit Invested(msg.sender, id, usdcAmount, sharesAmount);

        if (fundingProgress[id] >= operations[id].totalShares) {
            emit OperationFinished(id, operations[id].totalShares * operations[id].eurPerShares);
        }
    }
    //**********************************

    //********** dLEND Burn and opLEND mint **********
    function claimOpTokens(uint256 id) external {
        require(id <= operationCount, "Operation does not exists");
        require(isOperationFinished(id), "Operation is not finished");
        require(!operationCanceled[id], "Operation is canceled");
        require(!fundingPaused[id], "Operation is paused");

        uint256 dLendBalance = dLEND.balanceOf(msg.sender, id);

        require(dLendBalance > 0, "User has no dLEND");
        require(dLEND.isApprovedForAll(msg.sender, address(this)), "dLEND tokens not approved");

        bytes memory sender = abi.encode(msg.sender);

        dLEND.safeTransferFrom(msg.sender, address(this), id, dLendBalance, sender);
    }

    function getUserFromOnReceive(address from, bytes memory data) private view returns (address user) {
        user = from;
        if (from == address(this) && data.length > 0) {
            (address decodedUser) = abi.decode(data, (address));
            user = decodedUser;
        }
    }

    function handleBurnOnReceive(address user, uint256 id, uint256 value) private {
        require(isOperationFinished(id), "Operation is not finished");
        require(!operationCanceled[id], "Operation is canceled");
        require(!fundingPaused[id], "Operation is paused");

        Operation memory op = operations[id];
        LendOperation opToken = LendOperation(address(op.opToken));

        dLEND.burn(address(this), id, value);
        opToken.mint(user, value);

        emit OpTokenClaimed(op.opToken, user, value);
    }

    function onERC1155Received(address from, address, uint256 id, uint256 value, bytes memory data)
        public
        override
        returns (bytes4)
    {
        handleBurnOnReceive(getUserFromOnReceive(from, data), id, value);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(
        address from,
        address,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public override returns (bytes4) {
        address user = getUserFromOnReceive(from, data);

        for (uint256 i = 0; i < ids.length; i++) {
            handleBurnOnReceive(user, ids[i], values[i]);
        }

        return this.onERC1155BatchReceived.selector;
    }
    //**********************************
}
