// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../src/opLend.sol";

contract SetOpLendPeerOft is Script {
    function setUp() public {}

    function run() public {
        vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("bsc-testnet");
        // vm.createSelectFork("polygon-testnet");
        // vm.createSelectFork("arbitrum-sepolia");
        vm.startBroadcast();

        // ====================================================
        // Example data - replace addresses with actual targets
        // ====================================================

        address peerEthAddr = address(0x730c9fde4d83A3bbf1b49d695DF2A3F5B4c3A579);
        address peerArbiAddr = address(0x82FF220b22cF3F278aE431AC9d43447C3012a0D4);
        address peerBaseAddr = address(0xA55458Ab50c7bf88A2f00a745D185889480e157f);
        address peerPolyAddr = address(0x08227874137d2A38F3c908C456C5b33e20fa2aBE);
        address peerBscAddr = address(0x5aA12Eb0D864E089723681146c91D5F17ED6Fa21);

        (bytes32 peerEth, uint32 lzEidEth) =
            (bytes32(uint256(uint160(peerEthAddr))), 40161);

        (bytes32 peerArbi, uint32 lzEidArbi) =
            (bytes32(uint256(uint160(peerArbiAddr))), 40231);

        // (bytes32 peerBase, uint32 lzEidBase) =
            // (bytes32(uint256(uint160(peerBaseAddr))), 40245);

        (bytes32 peerPoly, uint32 lzEidPoly) =
            (bytes32(uint256(uint160(peerPolyAddr))), 40267);

        (bytes32 peerBsc, uint32 lzEidBsc) =
            (bytes32(uint256(uint160(peerBscAddr))), 40102);

        LendOperation opLend = LendOperation(peerBaseAddr);

        opLend.setPeer(lzEidEth, peerEth);
        // opLend.setPeer(lzEidBase, peerBase);
        opLend.setPeer(lzEidArbi, peerArbi);
        opLend.setPeer(lzEidPoly, peerPoly);
        opLend.setPeer(lzEidBsc, peerBsc);

        vm.stopBroadcast();
    }
}
