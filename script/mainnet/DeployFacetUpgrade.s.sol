// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "script/common/Constants.s.sol";
import {FactoryDiamondCuts} from "script/common/FactoryDiamondCuts.s.sol";
import {LendMultisig} from "script/common/LendMultisig.s.sol";
import {IDiamondCut} from "src/Factory/interfaces/IDiamondCut.sol";

import {Admin} from "src/Factory/facets/Admin.sol";
import {Getters} from "src/Factory/facets/Getters.sol";
import {Invest} from "src/Factory/facets/Invest.sol";
import {Operations} from "src/Factory/facets/Operations.sol";
import {Ownership} from "src/Factory/facets/Ownership.sol";
import {LendOperation} from "src/opLend.sol";

contract DeployFacetUpgrade is Script, Constants {
    function run() public {
        Options memory opts;
        opts.constructorData = abi.encode(mnFactArgs.lzEndpoint);
        opts.unsafeAllow = OPLEND_UNSAFE_ALLOW;
        Upgrades.validateImplementation("opLend.sol:LendOperation", opts);

        vm.startBroadcast();

        Admin adminFacet = new Admin();
        Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();
        Operations operationsFacet = new Operations();
        LendOperation opLendImplementation = new LendOperation(mnFactArgs.lzEndpoint);

        vm.stopBroadcast();

        console.log("New admin facet deploy:", address(adminFacet));
        console.log("New getters facet deploy:", address(gettersFacet));
        console.log("New invest facet deploy:", address(investFacet));
        console.log("New operations facet deploy:", address(operationsFacet));
        console.log("New opLEND implementation deploy:", address(opLendImplementation));
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
        address operationsFacet = _deployedAddress(deployment, "Operations");
        address opLendImplementation = _deployedAddress(deployment, "LendOperation");
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
        require(
            keccak256(operationsFacet.code) == keccak256(type(Operations).runtimeCode),
            "Deployed Operations facet does not match the current build: rerun DeployFacetUpgrade"
        );
        // Immutables (the LZ endpoint) keep runtimeCode out of reach: compares the deployment input instead.
        require(
            keccak256(_deployedInput(deployment, "LendOperation"))
                == keccak256(abi.encodePacked(type(LendOperation).creationCode, abi.encode(mnFactArgs.lzEndpoint))),
            "Deployed opLEND implementation does not match the current build: rerun DeployFacetUpgrade"
        );
        require(opLendImplementation.code.length != 0, "opLEND implementation from the broadcast is not deployed");

        console.log("New admin facet:", adminFacet);
        console.log("New getters facet:", gettersFacet);
        console.log("New invest facet:", investFacet);
        console.log("New operations facet:", operationsFacet);
        console.log("New opLEND implementation:", opLendImplementation);

        IDiamondCut.FacetCut[] memory cut = _concatCuts(
            getEurcUpgradeFacets(adminFacet, gettersFacet, investFacet),
            getOpLendBeaconUpgradeFacets(adminFacet, gettersFacet, operationsFacet)
        );

        vm.startBroadcast(deployer);

        uint256 nonce = LendMultisig.nextNonce();

        // Configures EURC in the same call as the cut (delegatecalled from the diamond, so the Safe is the caller).
        LendMultisig.proposeTransaction(
            MAINNET_FACTORY,
            abi.encodeCall(
                IDiamondCut.diamondCut, (cut, adminFacet, abi.encodeCall(Admin.setEurcAddress, (mnFactArgs.eurc)))
            ),
            nonce
        );

        // Deploys the opLEND beacon, owned by the factory: `createOperation` reverts until this one is executed.
        LendMultisig.proposeTransaction(
            MAINNET_FACTORY, abi.encodeCall(Admin.updateOpLendImplementation, (opLendImplementation)), nonce + 1
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

    /// @dev Creation input of the single CREATE of `contractName` in the broadcast.
    function _deployedInput(string memory deployment, string memory contractName)
        internal
        pure
        returns (bytes memory)
    {
        return vm.parseJsonBytes(
            deployment,
            string.concat(
                "$.transactions[?(@.contractName == '",
                contractName,
                "' && @.transactionType == 'CREATE')].transaction.input"
            )
        );
    }
}
