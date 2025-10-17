// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

struct Operation {
    address opToken;
    uint256 totalShares;
    uint256 eurPerShares;
    string opName;
}

struct AppStorage {
    IERC20 usdc;
    address eurUsdOracle;
    address lzEndpoint;
    address backendSigner;
    uint256 operationCount;
    uint256 reentrancyStatus;
    mapping(uint256 => Operation) operations;
    mapping(uint256 => uint256) fundingProgress;
    mapping(uint256 => mapping(address => uint256)) predeposits;
    mapping(uint256 => uint256) usdcRaised;
    mapping(uint256 => bool) operationCanceled;
    mapping(uint256 => mapping(address => uint256)) usdcRaisedPerClient;
    mapping(uint256 => bool) usdcWithdrawn;
    mapping(uint256 => bool) fundingPaused;
    mapping(uint256 => bool) operationStarted;
    mapping(uint256 => mapping(address => uint256)) mintAllowance;
    mapping(string => bool) usedNonces;
}

library LibAppStorage {
    bytes32 constant APP_STORAGE_POSITION = keccak256("lend.factory.appstorage");

    function appStorage() internal pure returns (AppStorage storage ds) {
        bytes32 position = APP_STORAGE_POSITION;
        assembly {
            ds.slot := position
        }
    }
}
