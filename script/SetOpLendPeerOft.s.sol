// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../src/opLend.sol";
import {Constants} from "./common/Constants.s.sol";

contract SetOpLendPeerOft is Script, Constants {
    function setUp() public {}

    function run() public {
        // vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("bsc-testnet");
        // vm.createSelectFork("polygon-testnet");
        // vm.createSelectFork("arbitrum-sepolia");
        vm.startBroadcast();

        // ====================================================
        // Example data - replace addresses with actual targets
        // ====================================================

        address peerEthAddr = address(0x8733D688eDc07A036C1457fDe2d1C7f8351AAF91);
        address peerArbiAddr = address(0x678B42A61223bAe39b531B3f61d54b7Ecbd4Ab45); // ok
        address peerBaseAddr = address(0xffE1278BA1a6770c8513f296FfD0541EdC5f38C2); // ok
        address peerBscAddr = address(0x3A83b051EB73651ad2D91F311262e22347D3fB26); // ok
        address peerPolyAddr = address(0xAC3FC66A4BfA086B9f888cDb6e5f46bA7459E517); // ok
        address peerSonicAddr = address(0xa0Dc88318eCa43cc2a0c3c2f46a8FF7860fC8D4c); // ok
        address peerPlumeAddr = address(0xAC3FC66A4BfA086B9f888cDb6e5f46bA7459E517);
        address peerLineaAddr = address(0x3A83b051EB73651ad2D91F311262e22347D3fB26); // ok

        (bytes32 peerEth, uint32 lzEidEth) = (bytes32(uint256(uint160(peerEthAddr))), 30101);

        (bytes32 peerArbi, uint32 lzEidArbi) = (bytes32(uint256(uint160(peerArbiAddr))), 30110);

        (bytes32 peerBase, uint32 lzEidBase) = (bytes32(uint256(uint160(peerBaseAddr))), 30184);

        (bytes32 peerBsc, uint32 lzEidBsc) = (bytes32(uint256(uint160(peerBscAddr))), 30102);

        (bytes32 peerPoly, uint32 lzEidPoly) = (bytes32(uint256(uint160(peerPolyAddr))), 30109);

        (bytes32 peerSonic, uint32 lzEidSonic) = (bytes32(uint256(uint160(peerSonicAddr))), 30332);

        (bytes32 peerPlume, uint32 lzEidPlume) = (bytes32(uint256(uint160(peerPlumeAddr))), 30370);

        (bytes32 peerLinea, uint32 lzEidLinea) = (bytes32(uint256(uint160(peerLineaAddr))), 30183);

        LendOperation opLend = LendOperation(peerPlumeAddr);

        opLend.setPeer(lzEidEth, peerEth);
        opLend.setPeer(lzEidBase, peerBase);
        opLend.setPeer(lzEidArbi, peerArbi);
        opLend.setPeer(lzEidBsc, peerBsc);
        opLend.setPeer(lzEidPoly, peerPoly);
        opLend.setPeer(lzEidSonic, peerSonic);
        // opLend.setPeer(lzEidPlume, peerPlume);
        opLend.setPeer(lzEidLinea, peerLinea);

        // opLend.transferOwnership(multisigAddress);

        vm.stopBroadcast();
    }
}
