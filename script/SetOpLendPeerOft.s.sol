// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../src/opLend.sol";

contract SetOpLendPeerOft is Script {
    function setUp() public {}

    function run() public {
        // vm.createSelectFork("sepolia");
        vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("arbitrum-sepolia");
        vm.startBroadcast();

        (bytes32 peerEth, uint32 lzEidEth) =
            (bytes32(uint256(uint160(address(0x5818295773901eF40a3b0c624a3FC50E52856319)))), 40161);

        (bytes32 peerArbi, uint32 lzEidArbi) =
            (bytes32(uint256(uint160(address(0xC0978F13D3Ad40CFa489319AFeB943Be7C363eC2)))), 40231);

        (bytes32 peerBase, uint32 lzEidBase) =
            (bytes32(uint256(uint160(address(0x067f52C96393942483695C827b801c25762908D2)))), 40245);

        LendOperation opLend = LendOperation(address(0x067f52C96393942483695C827b801c25762908D2));

        // opLend.setPeer(lzEidEth, peerEth);
        // opLend.setPeer(lzEidBase, peerBase);
        opLend.setPeer(lzEidArbi, peerArbi);

        vm.stopBroadcast();
    }
}
