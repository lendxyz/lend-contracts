// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "../common/Constants.s.sol";

contract UpgradeRewards is Script, Constants {
    function run() external {
        vm.startBroadcast();

        Upgrades.upgradeProxy(getMainnetRewardsAddress(), "Rewards.sol", "");

        vm.stopBroadcast();
    }
}

contract ProposeUUPSUpgrade is Script, Constants {
    function run() external {
        Options memory opts;
        address proxyAddress = getMainnetRewardsAddress();

        vm.startBroadcast();

        // Deploy & Validate the new implementation
        // This ensures the new code has the 'upgradeTo' function (is UUPS compliant)
        address newImplementation = Upgrades.prepareUpgrade("Rewards.sol", opts);

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
