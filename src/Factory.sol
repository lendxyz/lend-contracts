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
import {DummyUSDC} from "./DummyUSDC.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

contract LendFactory is Ownable, ERC1155Holder {
    //********** Init **********
    DummyUSDC public immutable USDC;
    LendDebt public immutable dLEND;
    uint256 public operationCount = 0;

    address public immutable EURUSDOracle = 0xb49f677943BC038e9857d61E7d053CaA2C1734C1;
    address public immutable USDCUSDOracle = 0x8fFfFfd4AfB6115b954Bd326cbe7B4BA576818f6;

    mapping(uint256 => Operation) public operations;
    mapping(uint256 => uint256) public fundingProgress;
    mapping(uint256 => uint256) public usdcRaised;
    mapping(address => uint256) public opIdFromOpToken;
    mapping(uint256 => bool) public usdcWithdrawn;
    mapping(uint256 => bool) public fundingPaused;
    mapping(uint256 => bool) public operationStarted;

    struct Operation {
        address opToken;
        uint256 totalShares;
        uint256 eurPerShares;
        uint8 eurDecimals;
        string opName;
    }

    event OperationCreated(address indexed opToken, uint256 indexed operationId, uint256 totalShares);
    event OpTokenClaimed(address indexed opToken, address indexed recipient, uint256 amount);
    event Invested(
        address indexed investor, uint256 indexed operationId, uint256 indexed usdcAmount, uint256 sharesBought
    );
    event OperationFinished(uint256 indexed operationId, uint256 indexed amountRaisedEuro);

    constructor(address _admin, address _USDC, address _EURUSDCOracle, address _USDCUSDOracle) Ownable(_admin) {
        dLEND = new LendDebt();
        USDC = DummyUSDC(_USDC);
        EURUSDOracle = _EURUSDCOracle;
        USDCUSDOracle = _USDCUSDOracle;
    }
    //**********************************

    //********** Read functions **********
    function getOperation(uint256 id) public view returns (Operation memory) {
        return operations[id];
    }

    function getAmountIn(uint256 operationId, uint256 sharesAmount) public view returns (uint256) {
        return (
            uint256(scalePrice(int256(operations[operationId].eurPerShares), operations[operationId].eurDecimals))
                * sharesAmount * getEURUSDOraclePrice()
        ) / 10 ** USDC.decimals();
    }

    function isOperationFinished(uint256 id) public view returns (bool) {
        return operationStarted[id] && fundingProgress[id] >= operations[id].totalShares;
    }

    function getEURUSDOraclePrice() public view returns (uint256) {
        (, int256 eurUsd,,,) = AggregatorV3Interface(EURUSDOracle).latestRoundData();

        uint8 eurUsdDecimals = AggregatorV3Interface(EURUSDOracle).decimals();
        eurUsd = scalePrice(eurUsd, eurUsdDecimals);

        return uint256(eurUsd);
    }

    function scalePrice(int256 _price, uint8 _priceDecimals) internal view returns (int256) {
        uint256 usdcDecimals = USDC.decimals();

        if (_priceDecimals < usdcDecimals) {
            return _price * int256(10 ** uint256(usdcDecimals - _priceDecimals));
        } else if (_priceDecimals > usdcDecimals) {
            return _price / int256(10 ** uint256(_priceDecimals - usdcDecimals));
        }
        return _price;
    }
    //**********************************

    //********** Operation management **********
    function createOperation(string calldata opName, uint256 totalShares, uint256 eurPerShares, uint8 eurDecimals)
        external
        onlyOwner
        returns (address)
    {
        unchecked {
            operationCount++;
        }

        string memory name = string(abi.encodePacked("Lend Operation - ", opName));
        string memory symbol = string(abi.encodePacked("opLEND-", Strings.toString(operationCount)));
        LendOperation newOp = new LendOperation(address(this), name, symbol, totalShares * 10 ** 18);

        dLEND.setMaxSupply(operationCount, totalShares);

        operations[operationCount] = Operation(address(newOp), totalShares, eurPerShares, eurDecimals, opName);
        opIdFromOpToken[address(newOp)] = operationCount;

        emit OperationCreated(address(newOp), operationCount, totalShares);

        return address(newOp);
    }

    function startOperation(uint256 id) external onlyOwner {
        operationStarted[id] = true;
    }

    function pauseFunding(uint256 id, bool state) external onlyOwner {
        fundingPaused[id] = state;
    }

    function withdrawUSDC(uint256 id, address destination) external onlyOwner {
        require(id <= operationCount, "Operation does not exists");
        require(usdcWithdrawn[id] == false, "Already claimed USDC");
        require(isOperationFinished(id), "Operation is not finished");

        usdcWithdrawn[id] = true;
        USDC.transfer(destination, usdcRaised[id]);
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
        require(USDC.allowance(msg.sender, address(this)) >= cost, "Not enough tokens allowed to be spent");

        USDC.transferFrom(msg.sender, address(this), cost);

        fundingProgress[id] += sharesAmount;

        dLEND.mint(msg.sender, id, sharesAmount, "");

        usdcRaised[id] += cost;

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

        dLEND.safeTransferFrom(msg.sender, address(this), id, dLendBalance, "");
    }
    //**********************************

    //********** dLEND Burn and opLEND mint **********
    function handleBurnOnReceive(address user, uint256 id, uint256 value) private {
        uint256 opTokenAmount = value * 10 ** 18;
        Operation memory op = getOperation(id);
        LendOperation opToken = LendOperation(op.opToken);

        dLEND.burn(address(this), id, value);
        opToken.mint(user, opTokenAmount);

        emit OpTokenClaimed(op.opToken, user, opTokenAmount);
    }

    function onERC1155Received(address from, address, uint256 id, uint256 value, bytes memory)
        public
        override
        returns (bytes4)
    {
        handleBurnOnReceive(from, id, value);
        return this.onERC1155Received.selector;
    }

    function onERC1155BatchReceived(address from, address, uint256[] memory ids, uint256[] memory values, bytes memory)
        public
        override
        returns (bytes4)
    {
        for (uint256 i = 0; i < ids.length; i++) {
            handleBurnOnReceive(from, ids[i], values[i]);
        }

        return this.onERC1155BatchReceived.selector;
    }
    //**********************************
}
