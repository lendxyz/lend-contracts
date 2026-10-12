// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Constants} from "script/common/Constants.s.sol";
import {FactoryDiamondCuts} from "script/common/FactoryDiamondCuts.s.sol";
import {LendFactory} from "src/Factory/DiamondProxy.sol";
import {IDiamondCut} from "src/Factory/interfaces/IDiamondCut.sol";

import {Admin} from "src/Factory/facets/Admin.sol";
import {Getters} from "src/Factory/facets/Getters.sol";
import {Invest} from "src/Factory/facets/Invest.sol";
import {Operations} from "src/Factory/facets/Operations.sol";
import {Ownership} from "src/Factory/facets/Ownership.sol";
import {LendOperation} from "src/opLend.sol";

contract UpgradeFactoryTestnet is Script, Constants, FactoryDiamondCuts {
    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        // Connect diamond proxy
        LendFactory diamond = LendFactory(payable(0x2d5B2288b0Ec1A817ACb9DEe318A9089aAF26511));

        // Deploy new facets
        Admin adminFacet = new Admin();
        Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();
        Operations operationsFacet = new Operations();
        LendOperation opLendImplementation = new LendOperation(tnFactArgs.lzEndpoint);

        // get cuts
        IDiamondCut.FacetCut[] memory cut = _concatCuts(
            getEurcUpgradeFacets(address(adminFacet), address(gettersFacet), address(investFacet)),
            getOpLendBeaconUpgradeFacets(address(adminFacet), address(gettersFacet), address(operationsFacet))
        );

        // Perform cut and configure EURC in the same transaction
        diamond.diamondCut(cut, address(adminFacet), abi.encodeCall(Admin.setEurcAddress, (tnFactArgs.eurc)));

        // Deploy the opLEND beacon: the next operations are upgradeable
        Admin(address(diamond)).updateOpLendImplementation(address(opLendImplementation));

        vm.stopBroadcast();
    }
}
