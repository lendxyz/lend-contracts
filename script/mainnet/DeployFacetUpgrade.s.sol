// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console2} from "forge-std/Script.sol";

import {Admin} from "../../src/facets/Admin.sol";
import {Getters} from "../../src/facets/Getters.sol";
import {Invest} from "../../src/facets/Invest.sol";
import {Operations} from "../../src/facets/Operations.sol";
import {Ownership} from "../../src/facets/Ownership.sol";

contract DeployFacetUpgrade is Script {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Deploy new facets
        Invest investFacet = new Invest();

        console2.log("New invest facet deploy:", address(investFacet));

        vm.stopBroadcast();
    }
}
