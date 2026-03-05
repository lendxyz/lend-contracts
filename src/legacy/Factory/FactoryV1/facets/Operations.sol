// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LibDiamond} from "../lib/LibDiamond.sol";
import {Operation, AppStorage, LibAppStorage} from "../lib/Storage.sol";
import {Utils} from "../lib/Utils.sol";
import {Events} from "../lib/Events.sol";
import {LendOperation} from "../../../../opLend.sol";

contract Operations {
    function createOperation(string calldata opName, uint256 totalShares, uint256 eurPerShares)
        external
        returns (address)
    {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();

        unchecked {
            s.operationCount++;
        }

        string memory name = string(abi.encodePacked("Lend Operation - ", opName));
        string memory symbol = string(abi.encodePacked("opLEND-", Utils.uintToString(s.operationCount)));

        LendOperation newOp = new LendOperation(
            address(this), name, symbol, totalShares, s.lzEndpoint, LibDiamond.contractOwner(), s.backendSigner
        );

        s.operations[s.operationCount] = Operation(address(newOp), totalShares, eurPerShares, opName);

        emit Events.OperationCreated(address(newOp), s.operationCount, totalShares);

        return address(newOp);
    }

    function getOperation(uint256 id) external view returns (Operation memory) {
        AppStorage storage s = LibAppStorage.appStorage();
        if (id > s.operationCount) revert Events.OpNotExist();
        return s.operations[id];
    }

    function isOperationFinished(uint256 id) external view returns (bool) {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        return s.operationStarted[id] && s.fundingProgress[id] >= s.operations[id].totalShares;
    }

    function cancelOperation(uint256 id) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        s.operationCanceled[id] = true;

        emit Events.OperationCanceled(id);
    }

    function startOperation(uint256 id) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        s.operationStarted[id] = true;

        emit Events.OperationStarted(id);
    }

    function pauseFunding(uint256 id, bool state) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        s.fundingPaused[id] = state;

        if (state) {
            emit Events.OperationPaused(id);
        } else {
            emit Events.OperationResumed(id);
        }
    }

    function setPredeposits(uint256 id, bool state) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();

        if (s.predepositsOpen[id] != state) {
            s.predepositsOpen[id] = state;

            if (state) {
                emit Events.PredepositsOpen(id);
            } else {
                emit Events.PredepositsClosed(id);
            }
        }
    }
}
