// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script} from "forge-std/Script.sol";
import {LendFactory} from "../src/Factory.sol";

contract SetOpLendPeerFactory is Script {
    function setUp() public {}

    function run() public {
        // Set chain here:
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        LendFactory factory = LendFactory(payable(0xcC90663A4f20A41492e9e014f2012F9F48f73EF1));

        bytes32 peer1 = bytes32(uint256(uint160(address(0x5aA12Eb0D864E089723681146c91D5F17ED6Fa21))));
        bytes32 peer2 = bytes32(uint256(uint160(address(0xEb7c6573084E9e4f0e0a1101a05014F631Ec0AC6))));

        factory.setOpLendPeer(4, 421614, 40231, peer1);
        factory.setOpLendPeer(4, 84532, 40245, peer2);

        vm.stopBroadcast();
    }
}
