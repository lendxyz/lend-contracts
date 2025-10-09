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

        uint256 factoryOpId = 10;

        address peerArbiAddr = address(0x82FF220b22cF3F278aE431AC9d43447C3012a0D4);
        address peerBaseAddr = address(0xA55458Ab50c7bf88A2f00a745D185889480e157f);
        address peerPolyAddr = address(0x08227874137d2A38F3c908C456C5b33e20fa2aBE);
        address peerBscAddr = address(0x5aA12Eb0D864E089723681146c91D5F17ED6Fa21);

        (bytes32 peerArbi, uint32 lzEidArbi, uint32 chainIdArbi) =
            (bytes32(uint256(uint160(peerArbiAddr))), 40231, 421614);

        (bytes32 peerBase, uint32 lzEidBase, uint32 chainIdBase) =
            (bytes32(uint256(uint160(peerBaseAddr))), 40245, 84532);

        (bytes32 peerPoly, uint32 lzEidPoly, uint32 chainIdPoly) =
            (bytes32(uint256(uint160(peerPolyAddr))), 40267, 80002);

        (bytes32 peerBsc, uint32 lzEidBsc, uint32 chainIdBsc) =
            (bytes32(uint256(uint160(peerBscAddr))), 40102, 97);


        factory.setOpLendPeer(factoryOpId, chainIdArbi, lzEidArbi, peerArbi);
        factory.setOpLendPeer(factoryOpId, chainIdBase, lzEidBase, peerBase);
        factory.setOpLendPeer(factoryOpId, chainIdBsc, lzEidBsc, peerBsc);
        factory.setOpLendPeer(factoryOpId, chainIdPoly, lzEidPoly, peerPoly);

        vm.stopBroadcast();
    }
}
