// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LibDiamond} from "../lib/LibDiamond.sol";
import {Operation, AppStorage, LibAppStorage} from "../lib/Storage.sol";
import {Utils} from "../lib/Utils.sol";
import {Events} from "../lib/Utils.sol";
import {LendOperation} from "../opLend.sol";

contract Getters {
    function usdc() external view returns (address) {
        AppStorage storage s = LibAppStorage.appStorage();
        return address(s.usdc);
    }

    function operationCount() external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.operationCount;
    }

    function operations(uint256 id) external view returns (Operation memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.operations[id];
    }

    function fundingProgress(uint256 id) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.fundingProgress[id];
    }

    function usdcRaised(uint256 id) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.usdcRaised[id];
    }

    function fundingPaused(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.fundingPaused[id];
    }

    function operationStarted(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.operationStarted[id];
    }

    function usdcWithdrawn(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.usdcWithdrawn[id];
    }

    function operationCanceled(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.operationCanceled[id];
    }

    function usdcRaisedPerClient(uint256 id, address user) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.usdcRaisedPerClient[id][user];
    }

    function predeposits(uint256 id, address user) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.predeposits[id][user];
    }
}
