// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {FactoryDiamondCuts} from "../common/FactoryDiamondCuts.s.sol";
import {IDiamondCut} from "../../src/interfaces/IDiamondCut.sol";

import {Admin} from "../../src/facets/Admin.sol";
import {Getters} from "../../src/facets/Getters.sol";
import {Invest} from "../../src/facets/Invest.sol";
import {Operations} from "../../src/facets/Operations.sol";
import {Ownership} from "../../src/facets/Ownership.sol";

contract DeployFacetUpgrade is Script, FactoryDiamondCuts {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy new facets
        Invest investFacet = new Invest();

        console.log("New invest facet deploy:", address(investFacet));

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);

        cut[0] = getInvestFacets(address(investFacet), IDiamondCut.FacetCutAction.Replace);

        bytes memory data = abi.encodeWithSelector(IDiamondCut.diamondCut.selector, cut, address(0), "");

        console.log("Encoded call data:");
        console.logBytes(data);

        vm.stopBroadcast();
    }
}
