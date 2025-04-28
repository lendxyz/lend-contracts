// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LendDebt} from "./dLend.sol";
import {LendOperation} from "./opLend.sol";
import {DummyUSDC} from "./DummyUSDC.sol";

contract Factory is Ownable {
    //********** Init **********
    DummyUSDC public immutable USDC;
    LendDebt public immutable dLEND;
    uint256 public operationCount = 0;

    mapping(uint256 => Operation) public operations;
    mapping(uint256 => uint256) public fundingProgress;
    mapping(uint256 => bool) public operationStarted;

    struct Operation {
        address opToken;
        uint256 totalShares;
        uint256 eurPerShares;
        string opName;
    }

    event OperationCreated(address indexed opToken, uint256 indexed id, uint256 totalShares);
    event Invested(address indexed investor, uint256 indexed operationId, uint256 indexed usdcAmount, uint256 sharesBought);

    constructor(address _USDC) Ownable(msg.sender) {
        dLEND = new LendDebt();
        USDC = DummyUSDC(_USDC);
    }
    //**********************************


    //********** Read functions **********
    function getOperation(uint256 id) public view returns(Operation memory) {
        return operations[id];
    }

    function getAmountIn(uint256 operationId, uint256 sharesAmount) public view returns(uint256) {
        return usdcToEur(operations[operationId].eurPerShares) * sharesAmount;
    }

    function usdcToEur(uint256 usdcAmount) public pure returns(uint256) {
        // TODO: oracle call here to get the actual quote
        return usdcAmount;
    }

    function isOperationFinished(uint256 id) public view returns(bool) {
        return operationStarted[id] && fundingProgress[id] >= operations[id].totalShares;
    }
    //**********************************


    //********** Write functions **********
    function createOperation(
        string calldata opName,
        uint256 totalShares,
        uint256 eurPerShares
    ) external onlyOwner returns (address) {
        unchecked { operationCount++; }


        string memory name = string(abi.encodePacked("Lend Operation - ", opName));
        string memory symbol = string(abi.encodePacked("opLEND-", operationCount));
        LendOperation newOp = new LendOperation(address(this), name, symbol, totalShares * 10 ** 18);

        dLEND.setMaxSupply(operationCount, totalShares);

        operations[operationCount] = Operation(
            address(newOp),
            eurPerShares,
            totalShares,
            name
        );

        emit OperationCreated(address(newOp), operationCount, totalShares);

        return address(newOp);
    }

    function startOperation(uint256 id) external onlyOwner {
        operationStarted[id] = true;
    }

    function invest(uint256 id, uint256 sharesAmount) external {
        require(operationStarted[id] == true);
        require(operations[id].totalShares > 0);
        require(fundingProgress[id] + sharesAmount <= operations[id].totalShares);
        require(sharesAmount > 0);

        uint256 cost = getAmountIn(id, sharesAmount);
        require(USDC.allowance(msg.sender, address(this)) >= cost);

        USDC.transferFrom(msg.sender, address(this), cost);

        fundingProgress[id] += sharesAmount;

        dLEND.mint(msg.sender, id, sharesAmount, "");

        emit Invested(msg.sender, id, cost, sharesAmount);
    }
    //**********************************
}
