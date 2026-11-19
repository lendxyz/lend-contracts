// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Constants} from "script/common/Constants.s.sol";
import {FactoryUpgrade} from "script/common/FactoryUpgrade.s.sol";
import {LendFactory} from "src/Factory/DiamondProxy.sol";
import {ILendFactory} from "src/Factory/interfaces/IFactory.sol";
import {LendOperation} from "src/opLend.sol";

contract DeployFactory is Script, Constants {
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

        LendFactory diamond = new LendFactory(
            factoryArgs.admin,
            factoryArgs.usdc,
            factoryArgs.eurUsdOracle,
            factoryArgs.lzEndpoint,
            factoryArgs.backendSigner
        );

        // A fresh diamond routes nothing: the plan adds every function of the build.
        FactoryUpgrade.Plan memory p =
            FactoryUpgrade.plan(address(diamond), FactoryUpgrade.facets(), FactoryUpgrade.emptyManifest());
        FactoryUpgrade.deploy(p);
        diamond.diamondCut(p.cut, address(0), ""); // Perform cut

        ILendFactory factory = ILendFactory(address(diamond));
        factory.setEurcAddress(factoryArgs.eurc);
        factory.updateOpLendImplementation(address(new LendOperation(factoryArgs.lzEndpoint)));
        if (block.chainid == 1) {
            factory.transferOwnership(multisigAddress);
        }

        vm.stopBroadcast();
    }
}
