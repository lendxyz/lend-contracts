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

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.operations[id];
    }

    function fundingProgress(uint256 id) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.fundingProgress[id];
    }

    function usdcRaised(uint256 id) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.usdcRaised[id];
    }

    function fundingPaused(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.fundingPaused[id];
    }

    function operationStarted(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.operationStarted[id];
    }

    function usdcWithdrawn(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.usdcWithdrawn[id];
    }

    function operationCanceled(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.operationCanceled[id];
    }

    function usdcRaisedPerClient(uint256 id, address user) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.usdcRaisedPerClient[id][user];
    }

    function predeposits(uint256 id, address user) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.predeposits[id][user];
    }

    function gifted(uint256 id, address user) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.gifted[id][user];
    }

    function claimableTotal(uint256 id, address user) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.gifted[id][user] + s.predeposits[id][user];
    }

    function predepositsOpen(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        if (id > s.operationCount) revert Events.OpNotExist();
        return s.predepositsOpen[id];
    }

    function blacklisted(address user) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();
        return s.blacklisted[user];
    }

    function restitutionOpen(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) return false;
        return s.restituedAmount[id] > 0;
    }

    function restituableFunds(uint256 id, address user) external view returns (uint256) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) return 0;
        if (!s.fundsRestitued[id]) return 0;

        LendOperation opLend = LendOperation(s.operations[id].opToken);

        uint256 userBalance = opLend.balanceOf(user);
        if (userBalance == 0) return 0;

        return (userBalance * s.restituedAmount[id]) / opLend.MAX_SUPPLY();
    }
}
