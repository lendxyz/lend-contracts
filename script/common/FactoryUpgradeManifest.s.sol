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
    function manifest() internal view returns (FactoryUpgrade.Manifest memory m) {}
}
