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
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {LendDebt} from "./dLend.sol";
import {LendOperation} from "./opLend.sol";
import {USDC} from "./DummyUSDC.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LendFactory is Ownable, ERC1155Holder {
    //********** Init **********

    event OperationCreated(address indexed opToken, uint256 indexed operationId, uint256 totalShares);
    event OpTokenClaimed(address indexed opToken, address indexed recipient, uint256 amount);
    event Invested(
        address indexed investor, uint256 indexed operationId, uint256 indexed usdcAmount, uint256 sharesBought
    );
    event OperationFinished(uint256 indexed operationId, uint256 indexed amountRaisedEuro);

    struct Operation {
        address opToken;
        uint256 totalShares;
        uint256 eurPerShares;
        uint8 decimals;
        string opName;
    }

    USDC public immutable usdc;
    LendDebt public dLEND;

    address public EURUSDOracle;

    address private immutable lzEndpoint;
    address private immutable lzDelegate;

    uint256 public operationCount = 0;

    mapping(uint256 => Operation) public operations;
    mapping(uint256 => uint256) public fundingProgress;
    mapping(uint256 => uint256) public usdcRaised;
    mapping(uint256 => mapping(address => uint256)) public usdcRaisedPerClient;
    mapping(address => uint256) public opIdFromOpToken;
    mapping(uint256 => address) public opTokenFromOpId;
    mapping(uint256 => bool) public usdcWithdrawn;
    mapping(uint256 => bool) public fundingPaused;
    mapping(uint256 => bool) public operationStarted;

    constructor(address _admin, address _USDCAddress, address _EURUSDCOracle, address _lzEndpoint) Ownable(_admin) {
        usdc = USDC(_USDCAddress);
        EURUSDOracle = _EURUSDCOracle;
        lzEndpoint = _lzEndpoint;
        lzDelegate = _admin;
    }

    //**********************************

    //********** Read functions **********
    function operationDecimals(uint256 id) public view returns (uint256) {
        return operations[id].decimals;
    }

    function getOperation(uint256 id) public view returns (Operation memory) {
        return operations[id];
    }

    function getAmountIn(uint256 operationId, uint256 sharesAmount) public view returns (uint256) {
        uint256 sharesPriceEur =
            (operations[operationId].eurPerShares * sharesAmount) / 10 ** operations[operationId].decimals;
        uint256 sharesPriceEurConverted =
            uint256(scalePrice(int256(sharesPriceEur), operations[operationId].decimals, usdc.decimals()));

        return sharesPriceEurConverted * getEURUSDOraclePrice() / 10 ** usdc.decimals();
    }

    function isOperationFinished(uint256 id) public view returns (bool) {
        return operationStarted[id] && fundingProgress[id] >= operations[id].totalShares;
    }

    function getEURUSDOraclePrice() public view returns (uint256) {
        (, int256 eurUsd,,,) = AggregatorV3Interface(EURUSDOracle).latestRoundData();
        eurUsd = scalePrice(eurUsd, AggregatorV3Interface(EURUSDOracle).decimals(), usdc.decimals());

        return uint256(eurUsd);
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
    function createOperation(string calldata opName, uint256 totalShares, uint256 eurPerShares, uint8 decimals)
        external
        onlyOwner
        returns (address)
    {
        unchecked {
            operationCount++;
        }

        string memory name = string(abi.encodePacked("Lend Operation - ", opName));
        string memory symbol = string(abi.encodePacked("opLEND-", Strings.toString(operationCount)));

        LendOperation newOp = new LendOperation(
            address(this),
            name,
            symbol,
            totalShares,
            decimals,
            lzEndpoint,
            lzDelegate
        );

        dLEND.setMaxSupply(operationCount, totalShares);

        operations[operationCount] = Operation(address(newOp), totalShares, eurPerShares, decimals, opName);
        opIdFromOpToken[address(newOp)] = operationCount;
        opTokenFromOpId[operationCount] = address(newOp);

        emit OperationCreated(address(newOp), operationCount, totalShares);

        return address(newOp);
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

    function setDLendAddress(address dlend) public onlyOwner {
        dLEND = LendDebt(dlend);
    }

    function withdrawUSDC(uint256 id, address destination) external onlyOwner {
        require(id <= operationCount, "Operation does not exists");
        require(usdcWithdrawn[id] == false, "Already claimed USDC");
        require(isOperationFinished(id), "Operation is not finished");

        usdcWithdrawn[id] = true;
        usdc.transfer(destination, usdcRaised[id]);
    }
    //**********************************

    //********** User-facing functions **********
    function invest(uint256 id, uint256 sharesAmount) external {
        require(id <= operationCount, "Operation does not exists");
        require(operationStarted[id] == true, "Operation is not started");
        require(fundingProgress[id] + sharesAmount <= operations[id].totalShares, "Cannot buy that many shares");
        require(!isOperationFinished(id), "Operation is finished");
        require(!fundingPaused[id], "Operation is paused");
        require(sharesAmount > 0, "Not enough shares");

        uint256 cost = getAmountIn(id, sharesAmount);
        require(usdc.allowance(msg.sender, address(this)) >= cost, "Not enough tokens allowed to be spent");

        usdc.transferFrom(msg.sender, address(this), cost);

        fundingProgress[id] += sharesAmount;

        dLEND.mint(msg.sender, id, sharesAmount, "");

        usdcRaised[id] += cost;
        usdcRaisedPerClient[id][msg.sender] += cost;

        emit Invested(msg.sender, id, cost, sharesAmount);

        if (fundingProgress[id] >= operations[id].totalShares) {
            emit OperationFinished(id, operations[id].totalShares * operations[id].eurPerShares);
        }
    }

    function claimOpTokens(uint256 id) external {
        require(id <= operationCount, "Operation does not exists");
        require(isOperationFinished(id), "Operation is not finished");

        uint256 dLendBalance = dLEND.balanceOf(msg.sender, id);

        require(dLendBalance > 0, "User has no dLEND");
        require(dLEND.isApprovedForAll(msg.sender, address(this)), "dLEND tokens not approved");

        bytes memory sender = abi.encode(msg.sender);

        dLEND.safeTransferFrom(msg.sender, address(this), id, dLendBalance, sender);
    }
    //**********************************

    //********** dLEND Burn and opLEND mint **********
    function getUserFromOnReceive(address from, bytes memory data) private view returns (address user) {
        user = from;
        if (from == address(this) && data.length > 0) {
            (address decodedUser) = abi.decode(data, (address));
            user = decodedUser;
        }
    }

    function handleBurnOnReceive(address user, uint256 id, uint256 value) private {
        require(isOperationFinished(id), "Operation is not finished");

        Operation memory op = getOperation(id);
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
