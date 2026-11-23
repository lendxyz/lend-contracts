// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {LibDiamond} from "src/Factory/lib/LibDiamond.sol";
import {Operation, AppStorage, LibAppStorage} from "src/Factory/lib/Storage.sol";
import {Utils} from "src/Factory/lib/Utils.sol";
import {Events} from "src/Factory/lib/Utils.sol";
import {LendOperation} from "src/opLend.sol";

contract Admin {
    struct RefundEntry {
        address user;
        uint256 sharesToBurn;
        uint256 usdcToRefund;
        uint256 eurcToRefund;
    }

    function refundUser(uint256 id, address user, uint256 sharesToBurn, uint256 usdcToRefund, uint256 eurcToRefund)
        external
    {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        _requireRefundable(s, id);

        _refund(
            s, id, LendOperation(s.operations[id].opToken), RefundEntry(user, sharesToBurn, usdcToRefund, eurcToRefund)
        );
    }

    function batchRefundUsers(uint256 id, RefundEntry[] calldata entries) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        _requireRefundable(s, id);

        LendOperation opToken = LendOperation(s.operations[id].opToken);
        for (uint256 i = 0; i < entries.length; i++) {
            _refund(s, id, opToken, entries[i]);
        }
    }

    function fiatRefund(uint256 id, address user, address opLendHolder, uint256 sharesAmount) external {
        LibDiamond.enforceIsContractOwner();
        AppStorage storage s = LibAppStorage.appStorage();

        _requireRefundable(s, id);
        if (sharesAmount == 0) revert Events.ZeroShares();

        LendOperation opToken = LendOperation(s.operations[id].opToken);
        if (sharesAmount > opToken.balanceOf(opLendHolder)) revert Events.InsufficientShareBalance();

        s.fundingProgress[id] -= sharesAmount;
        opToken.adminBurn(opLendHolder, sharesAmount);

        emit Events.Refunded(user, id, 0, sharesAmount);
        emit Events.RefundedFiat(user, opLendHolder, id, sharesAmount);
    }

    /// @dev A finished operation is settled: refunding it would reopen the sale after its funds may already be
    ///      withdrawn. `cancelOperation` refuses a finished operation too, so a finished operation is never refunded.
    function _requireRefundable(AppStorage storage s, uint256 id) private view {
        if (id > s.operationCount) revert Events.OpNotExist();
        if (s.operationStarted[id] && s.fundingProgress[id] >= s.operations[id].totalShares) {
            revert Events.OpFinished();
        }
    }

    function _refund(AppStorage storage s, uint256 id, LendOperation opToken, RefundEntry memory entry) private {
        if (entry.sharesToBurn == 0 && entry.usdcToRefund == 0 && entry.eurcToRefund == 0) {
            revert Events.InputCannotBeZero();
        }
        if (entry.sharesToBurn > opToken.balanceOf(entry.user)) revert Events.InsufficientShareBalance();

        // Each coin of every operation sits in one balance: refunding more than this operation still holds would pay
        // out another operation's escrow. Such a refund is paid in full by the owner instead; the escrow pays only when
        // it covers the whole amount, so one coin's refund never comes from both. Decided before any state change.
        bool usdcFromOwner = _paidByOwner(s.usdc, entry.usdcToRefund, s.usdcRaised[id] - s.usdcWithdrawnAmount[id]);
        bool eurcFromOwner = _paidByOwner(s.eurc, entry.eurcToRefund, s.eurcRaised[id] - s.eurcWithdrawnAmount[id]);

        if (entry.sharesToBurn > 0) {
            s.fundingProgress[id] -= entry.sharesToBurn;
            opToken.adminBurn(entry.user, entry.sharesToBurn);
        }

        // Refunded reports a USD amount: EURC is converted at the current oracle rate.
        uint256 usdRefunded = entry.usdcToRefund;
        if (entry.usdcToRefund > 0) {
            if (!usdcFromOwner) s.usdcRaised[id] -= entry.usdcToRefund;
            _payRefund(s.usdc, usdcFromOwner, entry.user, entry.usdcToRefund);
        }

        if (entry.eurcToRefund > 0) {
            if (!eurcFromOwner) s.eurcRaised[id] -= entry.eurcToRefund;
            _payRefund(s.eurc, eurcFromOwner, entry.user, entry.eurcToRefund);
            usdRefunded += Utils.eurToUsd(s.eurUsdOracle, entry.eurcToRefund);
        }

        emit Events.Refunded(entry.user, id, usdRefunded, entry.sharesToBurn);
    }

    /// @dev Whether the owner pays `amount` of `token`: true when the escrow's `available` does not cover it.
    function _paidByOwner(IERC20 token, uint256 amount, uint256 available) private view returns (bool) {
        if (amount <= available) return false;
        if (token.balanceOf(msg.sender) < amount) revert Events.InsufficientEscrow();
        if (token.allowance(msg.sender, address(this)) < amount) revert Events.InsufficientAllowance();
        return true;
    }

    function _payRefund(IERC20 token, bool fromOwner, address user, uint256 amount) private {
        bool success = fromOwner ? token.transferFrom(msg.sender, user, amount) : token.transfer(user, amount);
        require(success, Events.TransferFailed());
    }

    function updateOracleAddress(address newOracleAddress) external {
        LibDiamond.enforceIsContractOwner();

        require(newOracleAddress != address(0), "Cannot be address 0");

        AppStorage storage s = LibAppStorage.appStorage();
        s.eurUsdOracle = newOracleAddress;
    }

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

    function updateOpLendImplementation(address newImplementation) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();

        // The endpoint is an implementation immutable: rejects implementations built for another chain.
        require(
            address(LendOperation(newImplementation).endpoint()) == s.lzEndpoint, "Implementation LZ endpoint mismatch"
        );

        if (s.opLendBeacon == address(0)) {
            s.opLendBeacon = address(new UpgradeableBeacon(newImplementation, address(this)));
        } else {
            UpgradeableBeacon(s.opLendBeacon).upgradeTo(newImplementation);
        }

        emit Events.OpLendImplementationUpdated(newImplementation);
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

        emit Events.FundingWithdrawn(id, usdcAmount, eurcAmount);
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
