// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../src/opLend.sol";

contract SetOpLendPeerOft is Script {
    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        // vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("bsc-testnet");
        // vm.createSelectFork("polygon-testnet");
        // vm.createSelectFork("arbitrum-sepolia");
        vm.startBroadcast();

        // ====================================================
        // Example data - replace addresses with actual targets
        // ====================================================

        (bytes32 peerEth, uint32 lzEidEth) =
            (bytes32(uint256(uint160(address(0x5818295773901eF40a3b0c624a3FC50E52856319)))), 40161);

        (bytes32 peerArbi, uint32 lzEidArbi) =
            (bytes32(uint256(uint160(address(0xC0978F13D3Ad40CFa489319AFeB943Be7C363eC2)))), 40231);

        (bytes32 peerBase, uint32 lzEidBase) =
            (bytes32(uint256(uint160(address(0x067f52C96393942483695C827b801c25762908D2)))), 40245);

        (bytes32 peerPoly, uint32 lzEidPoly) =
            (bytes32(uint256(uint160(address(0x54585517BBA619F74107581D0aF828EA40C25A7F)))), 40267);

        (bytes32 peerBsc, uint32 lzEidBsc) =
            (bytes32(uint256(uint160(address(0x4c465700E03CD62673c32f1d6757E5e7b93B1Bee)))), 40102);

        LendOperation opLend = LendOperation(address(0xC0978F13D3Ad40CFa489319AFeB943Be7C363eC2));

        opLend.setPeer(lzEidEth, peerEth);
        opLend.setPeer(lzEidBase, peerBase);
        opLend.setPeer(lzEidArbi, peerArbi);
        opLend.setPeer(lzEidPoly, peerPoly);
        opLend.setPeer(lzEidBsc, peerBsc);

        vm.stopBroadcast();
    }
}
