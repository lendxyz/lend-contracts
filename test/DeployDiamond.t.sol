// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Diamond} from "../src/DiamondProxy.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {Admin} from "../src/facets/Admin.sol";
import {Getters} from "../src/facets/Getters.sol";
import {Invest} from "../src/facets/Invest.sol";
import {Operations} from "../src/facets/Operations.sol";
import {Ownership} from "../src/facets/Ownership.sol";
import {FactoryDiamondCuts} from "../script/common/FactoryDiamondCuts.s.sol";

contract DeployDiamondTest is Test, FactoryDiamondCuts {
    function setupDiamond(address admin, address usdc, address eurUsdOracle, address lzEndpoint, address backendSigner)
        public
        returns (address)
    {
        Admin adminFacet = new Admin();
        Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();
        Operations operationsFacet = new Operations();
        Ownership ownershipFacet = new Ownership();

        Diamond diamond = new Diamond(admin, usdc, eurUsdOracle, lzEndpoint, backendSigner);

        IDiamondCut.FacetCut[] memory cut = getAllFacets(
            address(adminFacet),
            address(gettersFacet),
            address(investFacet),
            address(operationsFacet),
            address(ownershipFacet)
        );

        diamond.diamondCut(cut, address(0), ""); // Perform cut

        return address(diamond);
    }
}
