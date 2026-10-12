// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IDiamondCut} from "../../src/Factory/interfaces/IDiamondCut.sol";

import {Admin} from "../../src/Factory/facets/Admin.sol";
import {Getters} from "../../src/Factory/facets/Getters.sol";
import {Invest} from "../../src/Factory/facets/Invest.sol";
import {Operations} from "../../src/Factory/facets/Operations.sol";
import {Ownership} from "../../src/Factory/facets/Ownership.sol";

contract FactoryDiamondCuts {
    // Selectors already registered on deployed diamonds (pre-EURC). Upgrades must Replace them.

    function _adminSelectors() internal pure returns (bytes4[] memory adminSelectors) {
        adminSelectors = new bytes4[](11);

        adminSelectors[0] = Admin.refundUser.selector;
        adminSelectors[1] = Admin.batchRefundUsers.selector;
        adminSelectors[2] = Admin.updateOracleAddress.selector;
        adminSelectors[3] = Admin.updateBackendSigner.selector;
        adminSelectors[4] = Admin.setOpLendPeer.selector;
        adminSelectors[5] = Admin.batchSetOpLendPeers.selector;
        adminSelectors[6] = Admin.withdrawUsdc.selector;
        adminSelectors[7] = Admin.blacklist.selector;
        adminSelectors[8] = Admin.opLendWhitelistUser.selector;
        adminSelectors[9] = Admin.opLendAdminBurn.selector;
        adminSelectors[10] = Admin.opLendUpdateBackendSigner.selector;
    }

    function _gettersSelectors() internal pure returns (bytes4[] memory gettersSelectors) {
        gettersSelectors = new bytes4[](15);

        gettersSelectors[0] = Getters.usdc.selector;
        gettersSelectors[1] = Getters.operationCount.selector;
        gettersSelectors[2] = Getters.operations.selector;
        gettersSelectors[3] = Getters.fundingProgress.selector;
        gettersSelectors[4] = Getters.usdcRaised.selector;
        gettersSelectors[5] = Getters.fundingPaused.selector;
        gettersSelectors[6] = Getters.operationStarted.selector;
        gettersSelectors[7] = Getters.usdcWithdrawn.selector;
        gettersSelectors[8] = Getters.operationCanceled.selector;
        gettersSelectors[9] = Getters.usdcRaisedPerClient.selector;
        gettersSelectors[10] = Getters.predeposits.selector;
        gettersSelectors[11] = Getters.gifted.selector;
        gettersSelectors[12] = Getters.claimableTotal.selector;
        gettersSelectors[13] = Getters.predepositsOpen.selector;
        gettersSelectors[14] = Getters.blacklisted.selector;
    }

    function _investSelectors() internal pure returns (bytes4[] memory investSelectors) {
        investSelectors = new bytes4[](10);

        investSelectors[0] = Invest.invest.selector;
        investSelectors[1] = Invest.investAndBridge.selector;
        investSelectors[2] = Invest.predeposit.selector;
        investSelectors[3] = Invest.claimOpTokens.selector;
        investSelectors[4] = Invest.getAmountIn.selector;
        investSelectors[5] = Invest.getAmountOut.selector;
        investSelectors[6] = Invest.giftOpTokens.selector;
        investSelectors[7] = Invest.claimOpTokensAndBridge.selector;
        investSelectors[8] = Invest.claimOpTokensBatch.selector;
        investSelectors[9] = Invest.fiatInvest.selector;
    }

    // Selectors introduced by the EURC raise. Absent from deployed diamonds: upgrades must Add them.

    function _adminEurcSelectors() internal pure returns (bytes4[] memory adminSelectors) {
        adminSelectors = new bytes4[](1);

        adminSelectors[0] = Admin.setEurcAddress.selector;
    }

    function _gettersEurcSelectors() internal pure returns (bytes4[] memory gettersSelectors) {
        gettersSelectors = new bytes4[](3);

        gettersSelectors[0] = Getters.eurc.selector;
        gettersSelectors[1] = Getters.eurcRaised.selector;
        gettersSelectors[2] = Getters.eurcRaisedPerClient.selector;
    }

    function _investEurcSelectors() internal pure returns (bytes4[] memory investSelectors) {
        investSelectors = new bytes4[](3);

        investSelectors[0] = Invest.investEur.selector;
        investSelectors[1] = Invest.investEurAndBridge.selector;
        investSelectors[2] = Invest.getAmountInEur.selector;
    }

    function _concat(bytes4[] memory a, bytes4[] memory b) internal pure returns (bytes4[] memory res) {
        res = new bytes4[](a.length + b.length);

        for (uint256 i = 0; i < a.length; i++) {
            res[i] = a[i];
        }
        for (uint256 i = 0; i < b.length; i++) {
            res[a.length + i] = b[i];
        }
    }

    function _cut(address facet, IDiamondCut.FacetCutAction action, bytes4[] memory selectors)
        internal
        pure
        returns (IDiamondCut.FacetCut memory)
    {
        return IDiamondCut.FacetCut({facetAddress: facet, action: action, functionSelectors: selectors});
    }

    function getAdminFacets(address facet, IDiamondCut.FacetCutAction action)
        public
        pure
        returns (IDiamondCut.FacetCut memory)
    {
        return _cut(facet, action, _concat(_adminSelectors(), _adminEurcSelectors()));
    }

    function getGettersFacets(address facet, IDiamondCut.FacetCutAction action)
        public
        pure
        returns (IDiamondCut.FacetCut memory)
    {
        return _cut(facet, action, _concat(_gettersSelectors(), _gettersEurcSelectors()));
    }

    function getInvestFacets(address facet, IDiamondCut.FacetCutAction action)
        public
        pure
        returns (IDiamondCut.FacetCut memory)
    {
        return _cut(facet, action, _concat(_investSelectors(), _investEurcSelectors()));
    }

    function getOperationsFacets(address facet, IDiamondCut.FacetCutAction action)
        public
        pure
        returns (IDiamondCut.FacetCut memory)
    {
        bytes4[] memory operationsSelectors = new bytes4[](7);

        operationsSelectors[0] = Operations.createOperation.selector;
        operationsSelectors[1] = Operations.getOperation.selector;
        operationsSelectors[2] = Operations.isOperationFinished.selector;
        operationsSelectors[3] = Operations.cancelOperation.selector;
        operationsSelectors[4] = Operations.startOperation.selector;
        operationsSelectors[5] = Operations.pauseFunding.selector;
        operationsSelectors[6] = Operations.setPredeposits.selector;

        return IDiamondCut.FacetCut({facetAddress: facet, action: action, functionSelectors: operationsSelectors});
    }

    function getOwnershipFacets(address facet, IDiamondCut.FacetCutAction action)
        public
        pure
        returns (IDiamondCut.FacetCut memory)
    {
        bytes4[] memory ownershipSelectors = new bytes4[](2);

        ownershipSelectors[0] = Ownership.transferOwnership.selector;
        ownershipSelectors[1] = Ownership.owner.selector;

        return IDiamondCut.FacetCut({facetAddress: facet, action: action, functionSelectors: ownershipSelectors});
    }

    function getAllFacets(
        address adminFacet,
        address gettersFacet,
        address investFacet,
        address operationsFacet,
        address ownershipFacet
    ) public pure returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](5);

        cut[0] = getAdminFacets(adminFacet, IDiamondCut.FacetCutAction.Add);
        cut[1] = getGettersFacets(gettersFacet, IDiamondCut.FacetCutAction.Add);
        cut[2] = getInvestFacets(investFacet, IDiamondCut.FacetCutAction.Add);
        cut[3] = getOperationsFacets(operationsFacet, IDiamondCut.FacetCutAction.Add);
        cut[4] = getOwnershipFacets(ownershipFacet, IDiamondCut.FacetCutAction.Add);

        return cut;
    }

    /// @notice Cut upgrading a pre-EURC diamond: replaces the existing Admin/Getters/Invest selectors and adds
    ///         the EURC ones. Pair with `setEurcAddress` as init calldata to configure EURC atomically.
    function getEurcUpgradeFacets(address adminFacet, address gettersFacet, address investFacet)
        public
        pure
        returns (IDiamondCut.FacetCut[] memory)
    {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](6);

        cut[0] = _cut(adminFacet, IDiamondCut.FacetCutAction.Replace, _adminSelectors());
        cut[1] = _cut(adminFacet, IDiamondCut.FacetCutAction.Add, _adminEurcSelectors());
        cut[2] = _cut(gettersFacet, IDiamondCut.FacetCutAction.Replace, _gettersSelectors());
        cut[3] = _cut(gettersFacet, IDiamondCut.FacetCutAction.Add, _gettersEurcSelectors());
        cut[4] = _cut(investFacet, IDiamondCut.FacetCutAction.Replace, _investSelectors());
        cut[5] = _cut(investFacet, IDiamondCut.FacetCutAction.Add, _investEurcSelectors());

        return cut;
    }
}
