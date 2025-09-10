// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LibDiamond} from "../lib/LibDiamond.sol";
import {Operation, AppStorage, LibAppStorage} from "../lib/Storage.sol";
import {Utils} from "../lib/Utils.sol";
import {Events} from "../lib/Utils.sol";
import {LendOperation} from "../opLend.sol";

contract Admin {
    function refundUser(uint256 id, address user) external {
        AppStorage storage s = LibAppStorage.appStorage();

        LibDiamond.enforceIsContractOwner();

        LendOperation opToken = LendOperation(s.operations[id].opToken);
        uint256 userInvestAmount = s.usdcRaisedPerClient[id][user];
        uint256 opLendBalance = opToken.balanceOf(user);

        if (id > s.operationCount) revert Events.OpNotExist();
        if (userInvestAmount == 0) revert Events.UserNotParticipated();
        if (opLendBalance == 0) revert Events.NoOpLendBalance();

        s.fundingProgress[id] -= opLendBalance;
        s.usdcRaised[id] -= userInvestAmount;
        s.usdcRaisedPerClient[id][user] -= userInvestAmount;

        opToken.adminBurn(user, opLendBalance);
        require(s.usdc.transfer(user, userInvestAmount), Events.TransferFailed());

        emit Events.Refunded(user, id, userInvestAmount, opLendBalance);
    }

    function batchRefundUsers(uint256 id, address[] calldata users, uint256 len) external {
        LibDiamond.enforceIsContractOwner();

        for (uint256 i = 0; i < len; i++) {
            this.refundUser(id, users[i]);
        }
    }

    function updateOracleAddress(address newOracleAddress) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        s.eurUsdOracle = newOracleAddress;
    }

    function updateBackendSigner(address newBackendSigner) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        s.backendSigner = newBackendSigner;
    }

    function batchSetOpLendPeers(
        uint256[] calldata ids,
        uint32[] calldata chainIds,
        uint32[] calldata lzEids,
        bytes32[] calldata peers
    ) external {
        LibDiamond.enforceIsContractOwner();

        require(ids.length == peers.length, "OP ids length mismatch");
        require(lzEids.length == peers.length, "LzEids length mismatch");
        require(chainIds.length == peers.length, "ChainIds length mismatch");

        for (uint256 i = 0; i < lzEids.length; i++) {
            this.setOpLendPeer(ids[i], chainIds[i], lzEids[i], peers[i]);
        }
    }

    function setOpLendPeer(uint256 id, uint32 chainId, uint32 lzEndpointId, bytes32 peerAddress) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        LendOperation opLend = LendOperation(s.operations[id].opToken);
        opLend.setPeer(lzEndpointId, peerAddress);

        emit Events.OpLendPeerAdded(id, chainId, lzEndpointId, peerAddress);
    }

    function withdrawUsdc(uint256 id, address destination) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        bool isOpFinished = s.operationStarted[id] && s.fundingProgress[id] >= s.operations[id].totalShares;

        if (!isOpFinished) revert Events.OpNotFinished();
        if (id > s.operationCount) revert Events.OpNotExist();
        if (s.usdcWithdrawn[id]) revert Events.AlreadyWithdrawn();

        s.usdcWithdrawn[id] = true;
        require(s.usdc.transfer(destination, s.usdcRaised[id]), Events.TransferFailed());
    }
}
