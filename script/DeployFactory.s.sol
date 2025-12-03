// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script,console} from "forge-std/Script.sol";
import {Constants} from "./common/Constants.s.sol";
import {FactoryDiamondCuts} from "./common/FactoryDiamondCuts.s.sol";
import {Diamond} from "../src/DiamondProxy.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";

import {ILendFactory} from "../src/interfaces/IFactory.sol";
import {Admin} from "../src/facets/Admin.sol";
import {Getters} from "../src/facets/Getters.sol";
import {Invest} from "../src/facets/Invest.sol";
import {Operations} from "../src/facets/Operations.sol";
import {Ownership} from "../src/facets/Ownership.sol";

contract DeployFactory is Script, Constants, FactoryDiamondCuts {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // tnFactArgs => testnet
        // FactoryConstructorArgs memory factoryArgs = tnFactArgs;
        // mnFactArgs => mainnet
        FactoryConstructorArgs memory factoryArgs = mnFactArgs;

        console.log(msg.sender);

        Admin adminFacet = new Admin();
        Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();
        Operations operationsFacet = new Operations();
        Ownership ownershipFacet = new Ownership();

        Diamond diamond = new Diamond(
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
        factory.transferOwnership(multisigAddress);

        vm.stopBroadcast();
    }
}
