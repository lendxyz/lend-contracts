// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../../src/opLend.sol";
import {Constants} from "../common/Constants.s.sol";

contract DeployOFT is Script, Constants {
    LendOperation public oft;

    string name = "Lend Operation - DR-2";
    string symbol = "opLEND-2";
    uint256 maxSupply = 500_000 * 10 ** 18; // use supply from source chain

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        oft = new LendOperation(
            mnFactArgs.admin, // admin - should be Lend multisig after setup
            name,
            symbol,
            maxSupply,
            mnFactArgs.lzEndpoint,
            mnFactArgs.admin, // lz delegate - should be Lend multisig
            mnFactArgs.backendSigner
        );

        (bytes32 peerEth, uint32 lzEidEth) =
            (bytes32(uint256(uint160(address(0x10daB7FD24A298513d985C5305493733B4C1262d)))), 30101);

        oft.setPeer(lzEidEth, peerEth);

        vm.stopBroadcast();
    }
}
