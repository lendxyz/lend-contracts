// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Constants} from "script/common/Constants.s.sol";
import {FactoryDiamondCuts} from "script/common/FactoryDiamondCuts.s.sol";
import {LendFactory} from "src/Factory/DiamondProxy.sol";
import {IDiamondCut} from "src/Factory/interfaces/IDiamondCut.sol";

import {ILendFactory} from "src/Factory/interfaces/IFactory.sol";
import {Admin} from "src/Factory/facets/Admin.sol";
import {Getters} from "src/Factory/facets/Getters.sol";
import {Invest} from "src/Factory/facets/Invest.sol";
import {Operations} from "src/Factory/facets/Operations.sol";
import {Ownership} from "src/Factory/facets/Ownership.sol";
import {LendOperation} from "src/opLend.sol";

contract DeployFactory is Script, Constants, FactoryDiamondCuts {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        require(
            block.chainid == 1 || block.chainid == 11155111, "Factory can either be deployed to ETH mainnet or sepolia"
        );

        // tnFactArgs => testnet
        // mnFactArgs => mainnet
        FactoryConstructorArgs memory factoryArgs = mnFactArgs;

        if (block.chainid == 11155111) {
            factoryArgs = tnFactArgs;
        }

        Admin adminFacet = new Admin();
        Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();
        Operations operationsFacet = new Operations();
        Ownership ownershipFacet = new Ownership();

        LendFactory diamond = new LendFactory(
            factoryArgs.admin,
            factoryArgs.usdc,
            factoryArgs.eurUsdOracle,
            factoryArgs.lzEndpoint,
            factoryArgs.backendSigner
        );

        IDiamondCut.FacetCut[] memory cut = getAllFacets(
            address(adminFacet),
            address(gettersFacet),
            address(investFacet),
            address(operationsFacet),
            address(ownershipFacet)
        );

        diamond.diamondCut(cut, address(0), ""); // Perform cut

        ILendFactory factory = ILendFactory(address(diamond));
        factory.setEurcAddress(factoryArgs.eurc);
        factory.updateOpLendImplementation(address(new LendOperation(factoryArgs.lzEndpoint)));
        if (block.chainid == 1) {
            factory.transferOwnership(multisigAddress);
        }

        vm.stopBroadcast();
    }
}
