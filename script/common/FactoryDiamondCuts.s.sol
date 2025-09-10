// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";

import {Admin} from "../../src/facets/Admin.sol";
import {Getters} from "../../src/facets/Getters.sol";
import {Invest} from "../../src/facets/Invest.sol";
import {Operations} from "../../src/facets/Operations.sol";
import {Ownership} from "../../src/facets/Ownership.sol";

contract FactoryDiamondCuts {
    function getFacets(
        address adminFacet,
        address gettersFacet,
        address investFacet,
        address operationsFacet,
        address ownershipFacet
    ) public pure returns (IDiamondCut.FacetCut[] memory) {
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](5);

        // AdminFacet selectors
        bytes4[] memory adminSelectors = new bytes4[](7);

        adminSelectors[0] = Admin.refundUser.selector;
        adminSelectors[1] = Admin.batchRefundUsers.selector;
        adminSelectors[2] = Admin.updateOracleAddress.selector;
        adminSelectors[3] = Admin.updateBackendSigner.selector;
        adminSelectors[4] = Admin.setOpLendPeer.selector;
        adminSelectors[5] = Admin.batchSetOpLendPeers.selector;
        adminSelectors[6] = Admin.withdrawUsdc.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: adminFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        // GettersFacet selectors
        bytes4[] memory gettersSelectors = new bytes4[](10);

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

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: gettersFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: gettersSelectors
        });

        // InvestFacet selectors
        bytes4[] memory investSelectors = new bytes4[](4);

        investSelectors[0] = Invest.invest.selector;
        investSelectors[1] = Invest.investAndBridge.selector;
        investSelectors[2] = Invest.getAmountIn.selector;
        investSelectors[3] = Invest.getAmountOut.selector;

        cut[2] = IDiamondCut.FacetCut({
            facetAddress: investFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: investSelectors
        });

        // OperationsFacet selectors
        bytes4[] memory operationsSelectors = new bytes4[](6);

        operationsSelectors[0] = Operations.createOperation.selector;
        operationsSelectors[1] = Operations.getOperation.selector;
        operationsSelectors[2] = Operations.isOperationFinished.selector;
        operationsSelectors[3] = Operations.cancelOperation.selector;
        operationsSelectors[4] = Operations.startOperation.selector;
        operationsSelectors[5] = Operations.pauseFunding.selector;

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(operationsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: operationsSelectors
        });

        // OwnershipFacet selectors
        bytes4[] memory ownershipSelectors = new bytes4[](2);

        ownershipSelectors[0] = Ownership.transferOwnership.selector;
        ownershipSelectors[1] = Ownership.owner.selector;

        cut[4] = IDiamondCut.FacetCut({
            facetAddress: ownershipFacet,
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        return cut;
    }
}
