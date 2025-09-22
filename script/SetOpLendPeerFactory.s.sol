// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {ILendFactory} from "../src/interfaces/IFactory.sol";

contract SetOpLendPeerFactory is Script {
    function setUp() public {}

    function run() public {
        // Set chain here:
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        ILendFactory factory = ILendFactory(payable(0x440C9415071A97be0fE2cE84522C3916907b638b));

        // ====================================================
        // Example data - replace addresses with actual targets
        // ====================================================

        (bytes32 peerArbi, uint32 lzEidArbi, uint32 chainIdArbi) =
            (bytes32(uint256(uint160(address(0xC0978F13D3Ad40CFa489319AFeB943Be7C363eC2)))), 40231, 421614);

        (bytes32 peerBase, uint32 lzEidBase, uint32 chainIdBase) =
            (bytes32(uint256(uint160(address(0x067f52C96393942483695C827b801c25762908D2)))), 40245, 84532);

        (bytes32 peerPoly, uint32 lzEidPoly, uint32 chainIdPoly) =
            (bytes32(uint256(uint160(address(0x54585517BBA619F74107581D0aF828EA40C25A7F)))), 40267, 80002);

        (bytes32 peerBsc, uint32 lzEidBsc, uint32 chainIdBsc) =
            (bytes32(uint256(uint160(address(0x4c465700E03CD62673c32f1d6757E5e7b93B1Bee)))), 40102, 97);


        factory.setOpLendPeer(9, chainIdArbi, lzEidArbi, peerArbi);
        factory.setOpLendPeer(9, chainIdBase, lzEidBase, peerBase);
        factory.setOpLendPeer(9, chainIdBsc, lzEidBsc, peerBsc);
        factory.setOpLendPeer(9, chainIdPoly, lzEidPoly, peerPoly);

        vm.stopBroadcast();
    }
}
