// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {LendOperation} from "../src/opLend.sol";
import {LendDebt} from "../src/dLend.sol";

contract DeployOFTTestnet is Script {
    LendOperation public oft;

    address lzEndpoint = address(0x6EDCE65403992e310A62460808c4b910D972f10f); // ETH sepolia endpoint
    address admin = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283); // Sepolia testnet deployer address

    string name = "Lend Operation - [op name]";
    string symbol = "opLEND-[]";
    uint8 decimals = 18; // use decimals from source chain
    uint256 maxSupply = 1_000_000 * 10 ** decimals; // use supply from source chain

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        oft = new LendOperation(
            address(0x000000000000000000000000000000000000dEaD), // token admin - should only be factory on source chain but dead address on other chains
            name,
            symbol,
            maxSupply,
            decimals,
            lzEndpoint,
            admin // lz delegate - should be Lend multisig
        );

        vm.stopBroadcast();
    }
}
