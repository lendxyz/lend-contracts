// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {LendFactory} from "../src/legacy/Factory.sol";
import {USDC} from "../src/testnet/DummyUSDC.sol";
import {LendOperation} from "../src/opLend.sol";
import {Diamond} from "../src/DiamondProxy.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {Admin} from "../src/facets/Admin.sol";
import {Getters} from "../src/facets/Getters.sol";
import {Invest} from "../src/facets/Invest.sol";
import {Operations} from "../src/facets/Operations.sol";
import {Ownership} from "../src/facets/Ownership.sol";

contract DeployDiamondTest is Test {
    function setupDiamond(address admin, address usdc, address eurUsdOracle, address lzEndpoint, address backendSigner)
        public
        returns (address)
    {
        Admin adminFacet = new Admin();
        Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();
        Operations operationsFacet = new Operations();
        Ownership ownershipFacet = new Ownership();

        Diamond diamond = new Diamond(admin, usdc, eurUsdOracle, lzEndpoint, backendSigner);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](5);

        // AdminFacet selectors
        bytes4[] memory adminSelectors = new bytes4[](7); // Add all your admin funcs

        adminSelectors[0] = Admin.refundUser.selector;
        adminSelectors[1] = Admin.batchRefundUsers.selector;
        adminSelectors[2] = Admin.updateOracleAddress.selector;
        adminSelectors[3] = Admin.updateBackendSigner.selector;
        adminSelectors[4] = Admin.setOpLendPeer.selector;
        adminSelectors[5] = Admin.batchSetOpLendPeers.selector;
        adminSelectors[6] = Admin.withdrawUsdc.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        // GettersFacet selectors
        bytes4[] memory gettersSelectors = new bytes4[](11); // Add all your admin funcs

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

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(gettersFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: gettersSelectors
        });

        // InvestFacet selectors
        bytes4[] memory investSelectors = new bytes4[](6);

        investSelectors[0] = Invest.invest.selector;
        investSelectors[1] = Invest.investAndBridge.selector;
        investSelectors[2] = Invest.predeposit.selector;
        investSelectors[3] = Invest.claimPredeposit.selector;
        investSelectors[4] = Invest.getAmountIn.selector;
        investSelectors[5] = Invest.getAmountOut.selector;

        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(investFacet),
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
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        diamond.diamondCut(cut, address(0), ""); // Perform cut

        return address(diamond);
    }
}
