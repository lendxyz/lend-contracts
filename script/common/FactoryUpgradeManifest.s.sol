// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Constants} from "script/common/Constants.s.sol";
import {FactoryUpgrade} from "script/common/FactoryUpgrade.s.sol";

/// @notice Declared intent of the next Factory upgrade. The upgrade scripts compute the diff between the build and the
///         live diamond and abort unless it is exactly this one, then abort if the simulated cut writes storage or
///         changes views this manifest does not declare.
///
///         Declare, for the next upgrade:
///         - `redeployedFacets`: facets whose code changes, e.g. `FactoryUpgrade.list("Admin", "Invest")`
///         - `addedFunctions` / `removedFunctions`: signatures, e.g. `FactoryUpgrade.list("investEur(uint256,uint256,string,bytes)")`
///         - `changedViews`: existing views whose output changes for the same input (new return format, init effect)
///         - `initCreationCode` / `initCalldata`: one-off contract delegatecalled by the diamond after the cut (e.g.
///           `type(FactoryInitVx).creationCode`), to configure the upgrade in the same transaction
///         - `initWrites`: storage fields the init sets, e.g. `FactoryUpgrade.list("AppStorage.eurc")`
///         - `externalWrites`: existing contracts whose storage the init writes
///
///         Empty it once the upgrade is executed: a stale declaration aborts the next upgrade (it is not in the diff).
abstract contract FactoryUpgradeManifest is Constants {
    function manifest() internal pure returns (FactoryUpgrade.Manifest memory m) {
        m.redeployedFacets = new string[](4);
        m.redeployedFacets[0] = "Admin";
        m.redeployedFacets[1] = "Getters";
        m.redeployedFacets[2] = "Invest";
        m.redeployedFacets[3] = "Operations";

        m.addedFunctions = FactoryUpgrade.list(
            "refundUser(uint256,address,uint256,uint256,uint256)",
            "batchRefundUsers(uint256,(address,uint256,uint256,uint256)[])",
            "fiatRefund(uint256,address,address,uint256)"
        );

        m.removedFunctions = new string[](12);
        m.removedFunctions[0] = "predeposits(uint256,address)";
        m.removedFunctions[1] = "gifted(uint256,address)";
        m.removedFunctions[2] = "claimableTotal(uint256,address)";
        m.removedFunctions[3] = "predepositsOpen(uint256)";
        m.removedFunctions[4] = "predeposit(uint256,uint256,string,bytes)";
        m.removedFunctions[5] = "giftOpTokens(uint256,uint256,address)";
        m.removedFunctions[6] = "claimOpTokens(uint256,address)";
        m.removedFunctions[7] = "claimOpTokensAndBridge(uint256,uint32)";
        m.removedFunctions[8] = "claimOpTokensBatch(uint256,address[])";
        m.removedFunctions[9] = "setPredeposits(uint256,bool)";
        m.removedFunctions[10] = "refundUser(uint256,address)";
        m.removedFunctions[11] = "batchRefundUsers(uint256,address[],uint256)";
    }
}
