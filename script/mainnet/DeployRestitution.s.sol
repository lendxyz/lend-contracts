// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Constants} from "../common/Constants.s.sol";
import {LendRestitution} from "../../src/Restitution.sol";

contract DeployRestitution is Script, Constants {
    function run() external {
        vm.startBroadcast();

        // Deploy the implementation contract
        LendRestitution implementation = new LendRestitution();

        address usdcAddress = getMainnetUsdcAddress();

        require(usdcAddress != address(0));

        // Prepare initializer data
        bytes memory initData = abi.encodeCall(LendRestitution.initialize, (aymAddress, usdcAddress));

        // Deploy the proxy and initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        vm.stopBroadcast();

        console.log("Restitution implementation:", address(implementation));
        console.log("Restitution proxy:", address(proxy));
        console.log("Record the proxy in DEPLOYMENTS.md and Constants.s.sol");
    }
}
