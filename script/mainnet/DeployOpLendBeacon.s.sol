// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {IBeacon} from "@openzeppelin/contracts/proxy/beacon/IBeacon.sol";
import {Constants} from "script/common/Constants.s.sol";

/// @notice Deploys the opLEND implementation and its beacon, owned by the Lend Safe, on a chain without the factory.
///         Every opLEND deployed on the chain by `DeployOFT` points at this beacon: one Safe `upgradeTo` upgrades them
///         all. Add the beacon to `Constants.getOpLendBeaconAddress` once deployed.
contract DeployOpLendBeacon is Script, Constants {
    function run() public {
        require(block.chainid != 1, "The factory owns the Ethereum opLEND beacon: use updateOpLendImplementation");

        Options memory opts;
        opts.constructorData = abi.encode(getLzEndpointMainnet());
        opts.unsafeAllow = OPLEND_UNSAFE_ALLOW;

        vm.startBroadcast();

        address beacon = Upgrades.deployBeacon("opLend.sol:LendOperation", multisigAddress, opts);

        vm.stopBroadcast();

        console.log("opLEND beacon:", beacon);
        console.log("opLEND implementation:", IBeacon(beacon).implementation());
    }
}
