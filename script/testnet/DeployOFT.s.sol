// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {BeaconProxy} from "@openzeppelin/contracts/proxy/beacon/BeaconProxy.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {LendOperation} from "src/opLend.sol";
import {Constants} from "script/common/Constants.s.sol";

/// @notice Deploys an opLEND behind the chain's opLEND beacon, passed in `OPLEND_BEACON`. Without it, deploys a new
///         implementation and beacon owned by the testnet admin: reuse it for the next opLEND of the chain.
contract DeployOFTTestnet is Script, Constants {
    LendOperation public oft;

    string name = "Lend Operation - Condamine Commercial Unit";
    string symbol = "opLEND-14";
    uint256 maxSupply = 1_000_000_000_000; // use supply from source chain

    function setUp() public {}

    function run() public {
        // Set chain here:
        // vm.createSelectFork("arbitrum-sepolia");
        // vm.createSelectFork("bsc-testnet");
        // vm.createSelectFork("polygon-testnet");
        vm.createSelectFork("base-sepolia");
        // vm.createSelectFork("monad-testnet");
        vm.startBroadcast();

        address beacon = vm.envOr("OPLEND_BEACON", address(0));
        if (beacon == address(0)) {
            beacon = address(new UpgradeableBeacon(address(new LendOperation(tnFactArgs.lzEndpoint)), tnFactArgs.admin));
            console.log("New opLEND beacon:", beacon);
        }

        oft = LendOperation(
            address(
                new BeaconProxy(
                    beacon,
                    abi.encodeCall(
                        LendOperation.initialize,
                        (tnFactArgs.admin, name, symbol, maxSupply, tnFactArgs.admin, tnFactArgs.backendSigner)
                    )
                )
            )
        );

        vm.stopBroadcast();
    }
}
