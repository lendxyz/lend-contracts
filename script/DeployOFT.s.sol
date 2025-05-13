// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Script, console} from "forge-std/Script.sol";
import {opLEND_OFT} from "../src/opLendOft.sol";
import {LendDebt} from "../src/dLend.sol";

contract DeployOFT is Script {
    opLEND_OFT public oft;

    address lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c); // ETH mainnet endpoint
    address lzDelegate = msg.sender;

    string name = 'Lend Operation - [op name]';
    string symbol = 'opLEND-[]';

    function setUp() public {}

    function run() public {
        vm.startBroadcast();

        oft = new opLEND_OFT(name, symbol, lzEndpoint, lzDelegate);

        vm.stopBroadcast();
    }
}
