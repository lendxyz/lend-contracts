// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Constants} from "../common/Constants.s.sol";
import {PriceOracle} from "../../src/PriceOracle.sol";
import {USDC} from "../../src/testnet/DummyUSDC.sol";

contract DeployOracleTestnet is Script, Constants {
    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        // Deploy the implementation contract
        PriceOracle implementation = new PriceOracle();

        // Prepare initializer data
        bytes memory initData =
            abi.encodeCall(PriceOracle.initialize, (tnOwner, tnFactArgs.backendSigner, tnFactArgs.eurUsdOracle));

        // Deploy the proxy and initialize
        new ERC1967Proxy(address(implementation), initData);

        vm.stopBroadcast();
    }
}
