// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../../src/opLend.sol";
import {Constants} from "../common/Constants.s.sol";

contract DeployOFTTestnet is Script, Constants {
    LendOperation public oft;

    string name = "Lend Operation - Commercial unit Tremoille";
    string symbol = "opLEND-11";
    uint256 maxSupply = 1_000_000_000_000; // use supply from source chain

    function setUp() public {}

    function run() public {
        // Set chain here:
        vm.createSelectFork("arbitrum-sepolia");
        // vm.createSelectFork("bsc-testnet");
        // vm.createSelectFork("polygon-testnet");
        // vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("monad-testnet");
        vm.startBroadcast();

        oft = new LendOperation(
            tnFactArgs.admin, name, symbol, maxSupply, tnFactArgs.lzEndpoint, tnFactArgs.admin, tnFactArgs.backendSigner
        );

        vm.stopBroadcast();
    }
}
