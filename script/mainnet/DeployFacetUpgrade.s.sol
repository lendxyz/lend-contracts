// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Constants} from "script/common/Constants.s.sol";
import {FactoryDiamondCuts} from "script/common/FactoryDiamondCuts.s.sol";
import {LendMultisig} from "script/common/LendMultisig.s.sol";
import {IDiamondCut} from "src/Factory/interfaces/IDiamondCut.sol";

import {Admin} from "src/Factory/facets/Admin.sol";
import {Getters} from "src/Factory/facets/Getters.sol";
import {Invest} from "src/Factory/facets/Invest.sol";
import {Operations} from "src/Factory/facets/Operations.sol";
import {Ownership} from "src/Factory/facets/Ownership.sol";

contract DeployFacetUpgrade is Script {
    function run() public {
        vm.startBroadcast();

        Admin adminFacet = new Admin();
        Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();

        vm.stopBroadcast();

        console.log("New admin facet deploy:", address(adminFacet));
        console.log("New getters facet deploy:", address(gettersFacet));
        console.log("New invest facet deploy:", address(investFacet));
    }
}

contract ProposeFacetUpgrade is Script, Constants, FactoryDiamondCuts {
    function run() public {
        string memory deployment = vm.readFile(
            string.concat(
                vm.projectRoot(), "/broadcast/DeployFacetUpgrade.s.sol/", vm.toString(block.chainid), "/run-latest.json"
            )
        );

        address adminFacet = _deployedAddress(deployment, "Admin");
        address gettersFacet = _deployedAddress(deployment, "Getters");
        address investFacet = _deployedAddress(deployment, "Invest");
        address deployer = vm.parseJsonAddress(deployment, ".transactions[0].transaction.from");

        // Guards against proposing a stale deployment from an older build.
        require(
            keccak256(adminFacet.code) == keccak256(type(Admin).runtimeCode),
            "Deployed Admin facet does not match the current build: rerun DeployFacetUpgrade"
        );
        require(
            keccak256(gettersFacet.code) == keccak256(type(Getters).runtimeCode),
            "Deployed Getters facet does not match the current build: rerun DeployFacetUpgrade"
        );
        require(
            keccak256(investFacet.code) == keccak256(type(Invest).runtimeCode),
            "Deployed Invest facet does not match the current build: rerun DeployFacetUpgrade"
        );

        console.log("New admin facet:", adminFacet);
        console.log("New getters facet:", gettersFacet);
        console.log("New invest facet:", investFacet);

        IDiamondCut.FacetCut[] memory cut = getEurcUpgradeFacets(adminFacet, gettersFacet, investFacet);
        // Configures EURC in the same call as the cut (delegatecalled from the diamond, so the Safe is the caller).
        bytes memory init = abi.encodeCall(Admin.setEurcAddress, (mnFactArgs.eurc));

        vm.startBroadcast(deployer);

        LendMultisig.proposeTransaction(
            MAINNET_FACTORY, abi.encodeCall(IDiamondCut.diamondCut, (cut, adminFacet, init))
        );

        vm.stopBroadcast();
    }

    /// @dev Reverts unless exactly one CREATE of `contractName` is in the broadcast.
    function _deployedAddress(string memory deployment, string memory contractName) internal pure returns (address) {
        return vm.parseJsonAddress(
            deployment,
            string.concat(
                "$.transactions[?(@.contractName == '",
                contractName,
                "' && @.transactionType == 'CREATE')].contractAddress"
            )
        );
    }
}
