// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "../common/Constants.s.sol";

abstract contract RestitutionProxyResolver is Script, Constants {
    function restitutionProxy() internal view returns (address) {
        address proxy = vm.envOr("RESTITUTION_PROXY", getMainnetRestitutionAddress());
        require(proxy != address(0), "Set RESTITUTION_PROXY or record the proxy in Constants.s.sol");
        return proxy;
    }
}

contract UpgradeRestitution is RestitutionProxyResolver {
    function run() external {
        vm.startBroadcast();

        Upgrades.upgradeProxy(restitutionProxy(), "Restitution.sol:LendRestitution", "");

        vm.stopBroadcast();
    }
}

contract ProposeUUPSUpgrade is RestitutionProxyResolver {
    function run() external {
        Options memory opts;
        address proxyAddress = restitutionProxy();

        vm.startBroadcast();

        // Deploy & Validate the new implementation
        address newImplementation = Upgrades.prepareUpgrade("Restitution.sol:LendRestitution", opts);

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
