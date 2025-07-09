// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../src/opLend.sol";

contract DeployOFTTestnet is Script {
    LendOperation public oft;

    address lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f); // ETH sepolia endpoint
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Sepolia testnet deployer address
    address backendSigner = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Backend signer to generate mint allowances

    string name = "Lend Operation - [name here]";
    string symbol = "opLEND-[factory op id here]";
    uint256 maxSupply = 1_000_000_000_000; // use supply from source chain

    function setUp() public {}

    function run() public {
        // Set chain here:
        vm.createSelectFork("arbitrum-sepolia");
        // vm.createSelectFork("monad-testnet");
        // vm.createSelectFork("base-sepolia");
        vm.startBroadcast();

        oft = new LendOperation(
            admin, // token admin
            name,
            symbol,
            maxSupply,
            lzEndpoint,
            admin, // lz delegate
            backendSigner
        );

        vm.stopBroadcast();
    }
}
