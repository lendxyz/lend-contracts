// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../../src/opLend.sol";
import {Constants} from "../common/Constants.s.sol";

contract DeployOFT is Script, Constants {
    LendOperation public oft;

    string name = "Lend Operation - [op name]";
    string symbol = "opLEND-[]";
    uint256 maxSupply = 1_000_000 * 10 ** 18; // use supply from source chain

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        oft = new LendOperation(
            address(0x000000000000000000000000000000000000dEaD), // token admin - should only be factory on source chain but dead address on other chains
            name,
            symbol,
            maxSupply,
            mnFactArgs.lzEndpoint,
            mnFactArgs.admin, // lz delegate - should be Lend multisig
            mnFactArgs.backendSigner
        );

        vm.stopBroadcast();
    }
}
