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

        bytes32 peerArbi = bytes32(uint256(uint160(address(0xC0978F13D3Ad40CFa489319AFeB943Be7C363eC2))));
        bytes32 peerBase = bytes32(uint256(uint160(address(0x067f52C96393942483695C827b801c25762908D2))));

        factory.setOpLendPeer(9, 421614, 40231, peerArbi);
        factory.setOpLendPeer(9, 84532, 40245, peerBase);

        vm.stopBroadcast();
    }
}
