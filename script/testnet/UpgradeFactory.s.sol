// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Constants} from "../common/Constants.s.sol";
import {FactoryDiamondCuts} from "../common/FactoryDiamondCuts.s.sol";
import {LendFactory} from "../../src/Factory/DiamondProxy.sol";
import {IDiamondCut} from "../../src/Factory/interfaces/IDiamondCut.sol";

import {Admin} from "../../src/Factory/facets/Admin.sol";
import {Getters} from "../../src/Factory/facets/Getters.sol";
import {Invest} from "../../src/Factory/facets/Invest.sol";
import {Operations} from "../../src/Factory/facets/Operations.sol";
import {Ownership} from "../../src/Factory/facets/Ownership.sol";

contract UpgradeFactoryTestnet is Script, Constants, FactoryDiamondCuts {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Connect diamond proxy
        LendFactory diamond = LendFactory(payable(0x2d5B2288b0Ec1A817ACb9DEe318A9089aAF26511));

        // Deploy new facets
        // Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();
        // Operations operationsFacet = new Operations();

        // get cuts
        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

        cut[0] = getInvestFacets(address(investFacet), IDiamondCut.FacetCutAction.Replace);

        // Perform cut
        diamond.diamondCut(cut, address(0), "");

        vm.stopBroadcast();
    }
}
