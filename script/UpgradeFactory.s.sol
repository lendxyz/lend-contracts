// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Constants} from "./common/Constants.s.sol";
import {FactoryDiamondCuts} from "./common/FactoryDiamondCuts.s.sol";
import {Diamond} from "../src/DiamondProxy.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";

import {Admin} from "../src/facets/Admin.sol";
import {Getters} from "../src/facets/Getters.sol";
import {Invest} from "../src/facets/Invest.sol";
import {Operations} from "../src/facets/Operations.sol";
import {Ownership} from "../src/facets/Ownership.sol";

contract UpgradeFactory is Script, Constants, FactoryDiamondCuts {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy new facet
        Getters gettersFacet = new Getters();

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

        // Spec selectors
        bytes4[] memory gettersSelectors = new bytes4[](13);

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

        cut[0] = IDiamondCut.FacetCut({
            facetAddress: address(gettersFacet),
            action: IDiamondCut.FacetCutAction.Replace,
            functionSelectors: gettersSelectors
        });

        // Connect diamond proxy
        Diamond diamond = Diamond(payable(0x2d5B2288b0Ec1A817ACb9DEe318A9089aAF26511));

        // Perform cut
        diamond.diamondCut(cut, address(0), "");

        vm.stopBroadcast();
    }
}
