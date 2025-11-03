// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../src/opLend.sol";

contract SetOpLendPeerOft is Script {
    function setUp() public {}

    function run() public {
        // vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("bsc-testnet");
        // vm.createSelectFork("polygon-testnet");
        vm.createSelectFork("arbitrum-sepolia");
        vm.startBroadcast();

        // ====================================================
        // Example data - replace addresses with actual targets
        // ====================================================

        address peerEthAddr = address(0x5b9B80ABF001a2b1c6c7C9BB6e25a310a9C92B67);
        address peerArbiAddr = address(0xD4Eca0237FB1d84AA4073bED4061037970933555);
        address peerBaseAddr = address(0x1f33E221abff9d98316F10D0B4b6E30275F620fB);
        address peerBscAddr = address(0x490a75f4758a7d93f66e46779733d9Ec6517a2E7);

        (bytes32 peerEth, uint32 lzEidEth) = (bytes32(uint256(uint160(peerEthAddr))), 40161);

        // (bytes32 peerArbi, uint32 lzEidArbi) = (bytes32(uint256(uint160(peerArbiAddr))), 40231);

        (bytes32 peerBase, uint32 lzEidBase) = (bytes32(uint256(uint160(peerBaseAddr))), 40245);

        (bytes32 peerBsc, uint32 lzEidBsc) = (bytes32(uint256(uint160(peerBscAddr))), 40102);

        LendOperation opLend = LendOperation(peerArbiAddr);

        opLend.setPeer(lzEidEth, peerEth);
        opLend.setPeer(lzEidBase, peerBase);
        // opLend.setPeer(lzEidArbi, peerArbi);
        opLend.setPeer(lzEidBsc, peerBsc);

        vm.stopBroadcast();
    }
}
