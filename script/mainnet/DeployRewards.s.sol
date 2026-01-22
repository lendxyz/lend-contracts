// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Constants} from "../common/Constants.s.sol";
import {LendRewards} from "../../src/Rewards.sol";

contract DeployRewards is Script, Constants {
    function run() external {
        vm.startBroadcast();

        // Deploy the implementation contract
        LendRewards implementation = new LendRewards();

        address usdcAddress = getMainnetUsdcAddress();

        require(usdcAddress != address(0));

        // Prepare initializer data
        bytes memory initData = abi.encodeCall(LendRewards.initialize, (aymAddress, usdcAddress));

        // Deploy the proxy and initialize
        new ERC1967Proxy(address(implementation), initData);

        vm.stopBroadcast();
    }
}
