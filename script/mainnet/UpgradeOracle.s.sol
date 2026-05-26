// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "../common/Constants.s.sol";

contract UpgradeOracle is Script, Constants {
    function run() external {
        vm.startBroadcast();

        address proxyAddress = address(0); // TODO: replace with actual deploy here
        Upgrades.upgradeProxy(proxyAddress, "PriceOracle.sol:PriceOracle", "");

        vm.stopBroadcast();
    }
}

contract ProposeUUPSUpgrade is Script, Constants {
    function run() external {
        Options memory opts;
        address proxyAddress = address(0); // TODO: replace with actual deploy here

        vm.startBroadcast();

        // Deploy & Validate the new implementation
        address newImplementation = Upgrades.prepareUpgrade("PriceOracle.sol:PriceOracle", opts);

        vm.stopBroadcast();

        console.log("--- DEPLOYMENT SUCCESSFUL ---");
        console.log("New Implementation Address:", newImplementation);

        // Encode the call for the Safe
        // For UUPS, we call 'upgradeToAndCall' on the Proxy itself.
        bytes memory data = abi.encodeWithSignature(
            "upgradeToAndCall(address,bytes)",
            newImplementation,
            "" // migration/initializer call, empty ("") if none.
        );

        console.log("--- SAFE TRANSACTION DETAILS ---");
        console.log("To (Target):", proxyAddress);
        console.log("Value: 0");
        console.log("Data (Hex):");
        console.logBytes(data);
    }
}
