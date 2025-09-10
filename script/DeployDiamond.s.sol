// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
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

contract DeployDiamond is Script {
    address eurUsdOracle = address(0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910);
    address lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f);
    address usdc = address(0x73DC60bb3f14852fF727C6C67B187e61A7BB26E8);
    address backendSigner = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Backend signer to generate mint allowances
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Sepolia testnet deployer address

    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        Admin adminFacet = new Admin();
        Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();
        Operations operationsFacet = new Operations();
        Ownership ownershipFacet = new Ownership();

        Diamond diamond = new Diamond(
            admin,
            usdc,
            eurUsdOracle,
            lzEndpoint,
            backendSigner
        );

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](5);

        // AdminFacet selectors
        bytes4[] memory adminSelectors = new bytes4[](6); // Add all your admin funcs

        adminSelectors[0] = adminFacet.refundUser.selector;
        adminSelectors[1] = adminFacet.batchRefundUsers.selector;
        adminSelectors[2] = adminFacet.updateOracleAddress.selector;
        adminSelectors[3] = adminFacet.updateBackendSigner.selector;
        adminSelectors[4] = adminFacet.setOpLendPeer.selector;
        adminSelectors[5] = adminFacet.withdrawUsdc.selector;

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(adminFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: adminSelectors
        });

        // GettersFacet selectors
        bytes4[] memory gettersSelectors = new bytes4[](10); // Add all your admin funcs

        gettersSelectors[0] = gettersFacet.usdc.selector;
        gettersSelectors[1] = gettersFacet.operationCount.selector;
        gettersSelectors[2] = gettersFacet.operations.selector;
        gettersSelectors[3] = gettersFacet.fundingProgress.selector;
        gettersSelectors[4] = gettersFacet.usdcRaised.selector;
        gettersSelectors[5] = gettersFacet.fundingPaused.selector;
        gettersSelectors[6] = gettersFacet.operationStarted.selector;
        gettersSelectors[7] = gettersFacet.usdcWithdrawn.selector;
        gettersSelectors[8] = gettersFacet.operationCanceled.selector;
        gettersSelectors[9] = gettersFacet.usdcRaisedPerClient.selector;

        cut[1] = IDiamondCut.FacetCut({
            facetAddress: address(gettersFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: gettersSelectors
        });


        // InvestFacet selectors
        bytes4[] memory investSelectors = new bytes4[](4);

        investSelectors[0] = investFacet.invest.selector;
        investSelectors[1] = investFacet.investAndBridge.selector;
        investSelectors[2] = investFacet.getAmountIn.selector;
        investSelectors[3] = investFacet.getAmountOut.selector;

        cut[2] = IDiamondCut.FacetCut({
            facetAddress: address(investFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: investSelectors
        });

        // OperationsFacet selectors
        bytes4[] memory operationsSelectors = new bytes4[](6);

        operationsSelectors[0] = operationsFacet.createOperation.selector;
        operationsSelectors[1] = operationsFacet.getOperation.selector;
        operationsSelectors[2] = operationsFacet.isOperationFinished.selector;
        operationsSelectors[3] = operationsFacet.cancelOperation.selector;
        operationsSelectors[4] = operationsFacet.startOperation.selector;
        operationsSelectors[5] = operationsFacet.pauseFunding.selector;

        cut[3] = IDiamondCut.FacetCut({
            facetAddress: address(operationsFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: operationsSelectors
        });

        // OwnershipFacet selectors
        bytes4[] memory ownershipSelectors = new bytes4[](2);

        ownershipSelectors[0] = ownershipFacet.transferOwnership.selector;
        ownershipSelectors[1] = ownershipFacet.owner.selector;

        cut[4] = IDiamondCut.FacetCut({
            facetAddress: address(ownershipFacet),
            action: IDiamondCut.FacetCutAction.Add,
            functionSelectors: ownershipSelectors
        });

        diamond.diamondCut(cut, address(0), ""); // Perform cut

        vm.stopBroadcast();
    }
}
