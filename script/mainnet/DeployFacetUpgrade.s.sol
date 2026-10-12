// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Constants} from "../common/Constants.s.sol";
import {FactoryDiamondCuts} from "../common/FactoryDiamondCuts.s.sol";
import {LendMultisig} from "../common/LendMultisig.s.sol";
import {IDiamondCut} from "../../src/Factory/interfaces/IDiamondCut.sol";

import {Admin} from "../../src/Factory/facets/Admin.sol";

contract DeployFacetUpgrade is Script {
    function run() public {
        vm.startBroadcast();

        Admin adminFacet = new Admin();

        vm.stopBroadcast();

        console.log("New admin facet deploy:", address(adminFacet));
    }
}

contract ProposeFacetUpgrade is Script, Constants, FactoryDiamondCuts {
    function run() public {
        string memory deployment = vm.readFile(
            string.concat(
                vm.projectRoot(), "/broadcast/DeployFacetUpgrade.s.sol/", vm.toString(block.chainid), "/run-latest.json"
            )
        );
        address adminFacet = vm.parseJsonAddress(deployment, ".transactions[0].contractAddress");
        address deployer = vm.parseJsonAddress(deployment, ".transactions[0].transaction.from");

        // Guards against proposing a stale deployment from an older build.
        require(
            keccak256(adminFacet.code) == keccak256(type(Admin).runtimeCode),
            "Deployed Admin facet does not match the current build: rerun DeployFacetUpgrade"
        );
        console.log("New admin facet:", adminFacet);

        IDiamondCut.FacetCut[] memory cut = new IDiamondCut.FacetCut[](1);
        cut[0] = getAdminFacets(adminFacet, IDiamondCut.FacetCutAction.Replace);

        vm.startBroadcast(deployer);

        LendMultisig.proposeTransaction(MAINNET_FACTORY, abi.encodeCall(IDiamondCut.diamondCut, (cut, address(0), "")));

        vm.stopBroadcast();
    }
}
