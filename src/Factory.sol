// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LendDebt} from "./dLend.sol";
import {LendOperation} from "./opLend.sol";

contract Factory is Ownable {
    LendDebt public debtNFT;
    uint256 public operationCount;

    mapping(uint256 => Operation) public operations;


    event OperationCreated(address indexed opToken, uint256 indexed id, uint256 totalShares);

    struct Operation {
        address opToken;
        uint256 totalShares;
        uint256 tokensPerShares;
        uint256 fiatPerShares;
        string opName;
    }

    constructor(address _debtNFT) Ownable(msg.sender) {
        debtNFT = LendDebt(_debtNFT);
    }

    function createOperation(
        string calldata opName,
        uint256 totalShares,
        uint256 tokensPerShares,
        uint256 fiatPerShares
    ) external onlyOwner returns (address) {
        unchecked { operationCount++; }

        string memory name = string(abi.encodePacked("Lend Operation - ", opName));
        string memory symbol = string(abi.encodePacked("opLEND-", operationCount));
        LendOperation newOp = new LendOperation(address(this), name, symbol);

        operations[operationCount] = Operation(
            address(newOp),
            fiatPerShares,
            totalShares,
            tokensPerShares,
            name
        );

        emit OperationCreated(address(newOp), operationCount, totalShares);

        return address(newOp);
    }
}
