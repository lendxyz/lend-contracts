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

        ILendFactory factory = ILendFactory(payable(0x2d5B2288b0Ec1A817ACb9DEe318A9089aAF26511));

        // ====================================================
        // Example data - replace addresses with actual targets
        // ====================================================

        uint256 factoryOpId = 11;

        address peerArbiAddr = address(0xD4Eca0237FB1d84AA4073bED4061037970933555);
        address peerBaseAddr = address(0x1f33E221abff9d98316F10D0B4b6E30275F620fB);
        address peerBscAddr = address(0x490a75f4758a7d93f66e46779733d9Ec6517a2E7);
        address peerPolyAddr = address(0xC95455f8a38a1660e700a5dDDfDe3D096c06fa92);

        (bytes32 peerArbi, uint32 lzEidArbi, uint32 chainIdArbi) =
            (bytes32(uint256(uint160(peerArbiAddr))), 40231, 421614);

        (bytes32 peerBase, uint32 lzEidBase, uint32 chainIdBase) =
            (bytes32(uint256(uint160(peerBaseAddr))), 40245, 84532);

        (bytes32 peerPoly, uint32 lzEidPoly, uint32 chainIdPoly) =
            (bytes32(uint256(uint160(peerPolyAddr))), 40267, 80002);

        (bytes32 peerBsc, uint32 lzEidBsc, uint32 chainIdBsc) = (bytes32(uint256(uint160(peerBscAddr))), 40102, 97);

        factory.setOpLendPeer(factoryOpId, chainIdArbi, lzEidArbi, peerArbi);
        factory.setOpLendPeer(factoryOpId, chainIdBase, lzEidBase, peerBase);
        factory.setOpLendPeer(factoryOpId, chainIdBsc, lzEidBsc, peerBsc);
        factory.setOpLendPeer(factoryOpId, chainIdPoly, lzEidPoly, peerPoly);

        vm.stopBroadcast();
    }
}
