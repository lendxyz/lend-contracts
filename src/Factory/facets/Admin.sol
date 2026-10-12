// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {LibDiamond} from "../lib/LibDiamond.sol";
import {Operation, AppStorage, LibAppStorage} from "../lib/Storage.sol";
import {Utils} from "../lib/Utils.sol";
import {Events} from "../lib/Utils.sol";
import {LendOperation} from "../../opLend.sol";

contract Admin {
    function refundUser(uint256 id, address user) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();

        LendOperation opToken = LendOperation(s.operations[id].opToken);
        uint256 usdcRefund = s.usdcRaisedPerClient[id][user];
        uint256 eurcRefund = s.eurcRaisedPerClient[id][user];
        uint256 opLendBalance = opToken.balanceOf(user);

        if (id > s.operationCount) revert Events.OpNotExist();
        if (usdcRefund == 0 && eurcRefund == 0) revert Events.UserNotParticipated();
        if (opLendBalance == 0) revert Events.NoOpLendBalance();
        if (
            s.usdcWithdrawn[id] || s.usdcRaised[id] - s.usdcWithdrawnAmount[id] < usdcRefund
                || s.eurcRaised[id] - s.eurcWithdrawnAmount[id] < eurcRefund
        ) {
            revert Events.InsufficientOpUsdc();
        }

        s.fundingProgress[id] -= opLendBalance;
        s.usdcRaised[id] -= usdcRefund;
        s.usdcRaisedPerClient[id][user] -= usdcRefund;
        s.eurcRaised[id] -= eurcRefund;
        s.eurcRaisedPerClient[id][user] -= eurcRefund;

        opToken.adminBurn(user, opLendBalance);

        // Refunded reports a USD amount: EURC is converted at the current oracle rate.
        uint256 usdRefunded = usdcRefund;
        if (usdcRefund > 0) {
            require(s.usdc.transfer(user, usdcRefund), Events.TransferFailed());
        }
        if (eurcRefund > 0) {
            require(s.eurc.transfer(user, eurcRefund), Events.TransferFailed());
            usdRefunded += Utils.eurToUsd(s.eurUsdOracle, eurcRefund);
        }

        emit Events.Refunded(user, id, usdRefunded, opLendBalance);
    }

    function batchRefundUsers(uint256 id, address[] calldata users, uint256 len) external {
        LibDiamond.enforceIsContractOwner();

        require(len > 0 && len <= users.length, "Invalid len");

        for (uint256 i = 0; i < len; i++) {
            this.refundUser(id, users[i]);
        }
    }

    function updateOracleAddress(address newOracleAddress) external {
        LibDiamond.enforceIsContractOwner();

        require(newOracleAddress != address(0), "Cannot be address 0");

        AppStorage storage s = LibAppStorage.appStorage();
        s.eurUsdOracle = newOracleAddress;
    }

    /// @notice Sets the EURC token accepted by `investEur`. Set once: raised EURC is accounted against this token.
    function setEurcAddress(address eurcAddress) external {
        LibDiamond.enforceIsContractOwner();

        require(eurcAddress != address(0), "Cannot be address 0");

        AppStorage storage s = LibAppStorage.appStorage();
        require(address(s.eurc) == address(0), "EURC already set");
        s.eurc = IERC20(eurcAddress);
    }

    function updateBackendSigner(address newBackendSigner) external {
        LibDiamond.enforceIsContractOwner();

        require(newBackendSigner != address(0), "Cannot be address 0");

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

        require(destination != address(0), "Cannot send USDC to address 0");
        require(destination != address(this), "Cannot send USDC back to factory");

        if (id > s.operationCount) revert Events.OpNotExist();
        if (s.usdcWithdrawn[id]) revert Events.AlreadyWithdrawn();

        // Withdraws the outstanding raise in both tokens; the final flag covers both.
        uint256 usdcAmount = s.usdcRaised[id] - s.usdcWithdrawnAmount[id];
        uint256 eurcAmount = s.eurcRaised[id] - s.eurcWithdrawnAmount[id];
        if (usdcAmount == 0 && eurcAmount == 0) revert Events.AlreadyWithdrawn();

        s.usdcWithdrawnAmount[id] += usdcAmount;
        s.eurcWithdrawnAmount[id] += eurcAmount;
        if (s.operationStarted[id] && s.fundingProgress[id] >= s.operations[id].totalShares) {
            s.usdcWithdrawn[id] = true;
        }

        if (usdcAmount > 0) {
            require(s.usdc.transfer(destination, usdcAmount), Events.TransferFailed());
        }
        if (eurcAmount > 0) {
            require(s.eurc.transfer(destination, eurcAmount), Events.TransferFailed());
        }
    }

    function blacklist(address user, bool state) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        require(user != address(0), "Cannot blacklist address 0");
        require(user != address(this), "Cannot blacklist factory");

        s.blacklisted[user] = state;
    }

    function opLendWhitelistUser(uint256 opId, address user, bool state) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        require(user != address(0), "Cannot whitelist address 0");
        require(user != address(this), "Cannot whitelist factory");

        if (opId > s.operationCount) revert Events.OpNotExist();
        LendOperation opLend = LendOperation(s.operations[opId].opToken);

        opLend.whitelistUserAdmin(user, state);
    }

    function opLendUpdateBackendSigner(uint256 opId, address newSigner) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        require(newSigner != address(0), "New backend signer cannot be address 0");
        require(newSigner != address(this), "New backend signer cannot be the factory");

        if (opId > s.operationCount) revert Events.OpNotExist();
        LendOperation opLend = LendOperation(s.operations[opId].opToken);

        opLend.updateBackendSigner(newSigner);
    }

    function opLendAdminBurn(uint256 opId, address user, uint256 value) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        require(user != address(0), "Cannot burn tokens from address 0");
        require(user != address(this), "Cannot burn tokens from factory");
        require(value > 0, "No amount specified");

        if (opId > s.operationCount) revert Events.OpNotExist();
        LendOperation opLend = LendOperation(s.operations[opId].opToken);

        opLend.adminBurn(user, value);
    }
}
