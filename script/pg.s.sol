// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {console} from "forge-std/console.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";

contract Playground is Script {
    using OptionsBuilder for bytes;

    function setUp() public {}

    function logPeerBytes() public pure {
        address peerTest = address(0xDF4aACF64675298b3a4de0109b63A598a5Bb42F2);

        bytes32 peerBytesTest = bytes32(uint256(uint160(peerTest)));

        console.logBytes32(peerBytesTest);
    }

    function logLzOptions() public pure {
        bytes memory extraOptions = OptionsBuilder.newOptions().addExecutorLzReceiveOption(50000, 0);

        console.logBytes(extraOptions);
    }

    function run() public pure {
        logLzOptions();
    }
}
