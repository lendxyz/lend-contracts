// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {LibDiamond} from "src/Factory/lib/LibDiamond.sol";
import {Operation, AppStorage, LibAppStorage} from "src/Factory/lib/Storage.sol";
import {Utils} from "src/Factory/lib/Utils.sol";
import {Events} from "src/Factory/lib/Events.sol";
import {LendOperation} from "src/opLend.sol";

contract Operations {
    function createOperation(string calldata opName, uint256 totalShares, uint256 eurPerShares)
        external
        returns (address)
    {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();
        if (s.opLendBeacon == address(0)) revert Events.OpLendImplementationNotSet();

        unchecked {
            s.operationCount++;
        }

        string memory name = string(abi.encodePacked("Lend Operation - ", opName));
        string memory symbol = string(abi.encodePacked("opLEND-", Utils.uintToString(s.operationCount)));

        address newOp = address(
            new BeaconProxy(
                s.opLendBeacon,
                abi.encodeCall(
                    LendOperation.initialize,
                    (address(this), name, symbol, totalShares, LibDiamond.contractOwner(), s.backendSigner)
                )
            )
        );

        s.operations[s.operationCount] = Operation(newOp, totalShares, eurPerShares, opName);

        emit Events.OperationCreated(newOp, s.operationCount, totalShares);

        return newOp;
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
