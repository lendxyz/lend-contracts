// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {LendOperation} from "../src/opLend.sol";

contract SetOpLendPeerOft is Script {
    function setUp() public {}

    function run() public {
        // vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("bsc-testnet");
        vm.createSelectFork("polygon-testnet");
        // vm.createSelectFork("arbitrum-sepolia");
        vm.startBroadcast();

        // ====================================================
        // Example data - replace addresses with actual targets
        // ====================================================

        address peerEthAddr = address(0x6f26a0160705D19C90280818b2532526Fc6838E3);
        address peerArbiAddr = address(0x26b03b189E4cb20D19391cC2c25521E72A6839A5);
        address peerBaseAddr = address(0x39DC4b033d6a373b0E4194B3B6bC463DC92c41A5);
        address peerBscAddr = address(0x7394Ad24BDD2B7d2051FDf5efFbD09601d2C0651);
        address peerPolyAddr = address(0x483FD90F0c34d268752FA98eaFEC336d71a1A727);

        (bytes32 peerEth, uint32 lzEidEth) = (bytes32(uint256(uint160(peerEthAddr))), 40161);

        (bytes32 peerArbi, uint32 lzEidArbi) = (bytes32(uint256(uint160(peerArbiAddr))), 40231);

        (bytes32 peerBase, uint32 lzEidBase) = (bytes32(uint256(uint160(peerBaseAddr))), 40245);

        (bytes32 peerBsc, uint32 lzEidBsc) = (bytes32(uint256(uint160(peerBscAddr))), 40102);

        // (bytes32 peerPoly, uint32 lzEidPoly) = (bytes32(uint256(uint160(peerPolyAddr))), 40267);

        LendOperation opLend = LendOperation(peerPolyAddr);

        opLend.setPeer(lzEidEth, peerEth);
        opLend.setPeer(lzEidBase, peerBase);
        opLend.setPeer(lzEidArbi, peerArbi);
        opLend.setPeer(lzEidBsc, peerBsc);
        // opLend.setPeer(lzEidPoly, peerPoly);

        vm.stopBroadcast();
    }
}
