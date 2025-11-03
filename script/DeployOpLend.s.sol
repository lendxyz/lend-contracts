// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {CustomOpLend} from "../src/legacy/customOpLend.sol";

contract DeployCustomOpLend is Script {
    function run() public {
        vm.startBroadcast();

        CustomOpLend customOpLend = new CustomOpLend(
            msg.sender,
            "opLend-10",
            "opLend-10",
            1000000000000
        );

        vm.stopBroadcast();
    }
}
