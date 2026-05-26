// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../../src/opLend.sol";
import {Constants} from "../common/Constants.s.sol";

contract DeployOFT is Script, Constants {
    LendOperation public oft;

    string name = "Lend Operation - Vouziers - Commercial Units";
    string symbol = "opLEND-2";
    uint256 maxSupply = 364250000000; // use supply from source chain

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        new LendOperation(
            multisigAddress, // admin - should be Lend multisig after setup
            name,
            symbol,
            maxSupply,
            getLzEndpointMainnet(),
            multisigAddress, // lz delegate - should be Lend multisig
            address(0x499603A70DC410c50A435D0Cd40C656bef4685FD)
        );

        // (bytes32 peerEth, uint32 lzEidEth) =
        // (bytes32(uint256(uint160(address(0x10daB7FD24A298513d985C5305493733B4C1262d)))), 30101);

        // oft.setPeer(lzEidEth, peerEth);

        vm.stopBroadcast();
    }
}
