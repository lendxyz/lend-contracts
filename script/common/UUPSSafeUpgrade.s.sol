// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {LendMultisig} from "./LendMultisig.s.sol";

interface IOwnableUUPS {
    function owner() external view returns (address);
    function upgradeToAndCall(address newImplementation, bytes calldata data) external payable;
}

/// @notice Two-step UUPS upgrade through the Lend Safe, one forge run each:
///         1. `_deployImplementation` (run with `--ledger`) validates and deploys the new implementation.
///         2. `_proposeUpgrade` (run WITHOUT `--ledger`, `LEDGER_HD_PATH` set) proposes `upgradeToAndCall` on the proxy
///            with the implementation from step 1's latest broadcast, signed by the step 1 deployer (see LendMultisig).
abstract contract UUPSSafeUpgrade is Script {
    function _deployImplementation(string memory contractName) internal {
        Options memory opts;

        vm.startBroadcast();

        address implementation = Upgrades.prepareUpgrade(contractName, opts);

        vm.stopBroadcast();

        console.log("New implementation:", implementation);
    }

    /// @param scriptFile File name of the calling script, which holds both steps, e.g. "UpgradeRewards.s.sol".
    function _proposeUpgrade(string memory scriptFile, string memory contractName, address proxy) internal {
        require(IOwnableUUPS(proxy).owner() == LendMultisig.SAFE, "Proxy is not owned by the Lend Safe");

        string memory deployment = vm.readFile(
            string.concat(
                vm.projectRoot(), "/broadcast/", scriptFile, "/", vm.toString(block.chainid), "/run-latest.json"
            )
        );
        // Guards against proposing a stale or unrelated deployment.
        require(
            keccak256(vm.parseJsonBytes(deployment, ".transactions[0].transaction.input"))
                == keccak256(vm.getCode(contractName)),
            string.concat(
                "Latest ", scriptFile, " broadcast is not a deployment of the current ", contractName, " build"
            )
        );
        address implementation = vm.parseJsonAddress(deployment, ".transactions[0].contractAddress");
        address deployer = vm.parseJsonAddress(deployment, ".transactions[0].transaction.from");
        require(implementation.code.length != 0, "Implementation from the latest broadcast is not deployed");
        require(
            address(uint160(uint256(vm.load(proxy, ERC1967Utils.IMPLEMENTATION_SLOT)))) != implementation,
            "Proxy already uses this implementation"
        );

        console.log("Proxy:", proxy);
        console.log("New implementation:", implementation);

        vm.startBroadcast(deployer);

        LendMultisig.proposeTransaction(proxy, abi.encodeCall(IOwnableUUPS.upgradeToAndCall, (implementation, "")));

        vm.stopBroadcast();
    }
}
