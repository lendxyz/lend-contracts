// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {Upgrades, Options} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Constants} from "script/common/Constants.s.sol";
import {LendMultisig} from "script/common/LendMultisig.s.sol";
import {ILendFactory} from "src/Factory/interfaces/IFactory.sol";

string constant OPLEND = "opLend.sol:LendOperation";

/// @notice Upgrades every opLEND of a chain at once through the Lend Safe, one forge run each:
///         1. `DeployOpLendImplementation` (run with `--ledger`) validates and deploys the new implementation. The new
///            version must declare its predecessor with an `oz-upgrades-from` custom natspec tag.
///         2. `ProposeOpLendUpgrade` (run WITHOUT `--ledger`, `LEDGER_HD_PATH` set) proposes pointing the chain's opLEND
///            beacon at the implementation from step 1's latest broadcast: through the factory on Ethereum, directly on
///            the Safe-owned beacon elsewhere.
contract DeployOpLendImplementation is Script, Constants {
    function run() external {
        Options memory opts;
        opts.constructorData = abi.encode(getLzEndpointMainnet());
        opts.unsafeAllow = OPLEND_UNSAFE_ALLOW;

        vm.startBroadcast();

        address implementation = Upgrades.prepareUpgrade(OPLEND, opts);

        vm.stopBroadcast();

        console.log("New opLEND implementation:", implementation);
    }
}

contract ProposeOpLendUpgrade is Script, Constants {
    function run() external {
        string memory deployment = vm.readFile(
            string.concat(
                vm.projectRoot(), "/broadcast/UpgradeOpLend.s.sol/", vm.toString(block.chainid), "/run-latest.json"
            )
        );
        // Guards against proposing a stale or unrelated deployment.
        require(
            keccak256(vm.parseJsonBytes(deployment, ".transactions[0].transaction.input"))
                == keccak256(abi.encodePacked(vm.getCode(OPLEND), abi.encode(getLzEndpointMainnet()))),
            "Latest UpgradeOpLend.s.sol broadcast is not a deployment of the current opLEND build"
        );
        address implementation = vm.parseJsonAddress(deployment, ".transactions[0].contractAddress");
        address deployer = vm.parseJsonAddress(deployment, ".transactions[0].transaction.from");
        require(implementation.code.length != 0, "Implementation from the latest broadcast is not deployed");

        address beacon = getOpLendBeaconAddress();
        require(UpgradeableBeacon(beacon).implementation() != implementation, "Beacon already uses this implementation");

        address target;
        bytes memory callData;
        if (block.chainid == 1) {
            require(ILendFactory(MAINNET_FACTORY).owner() == LendMultisig.SAFE, "Factory is not owned by the Lend Safe");
            target = MAINNET_FACTORY;
            callData = abi.encodeCall(ILendFactory.updateOpLendImplementation, (implementation));
        } else {
            require(UpgradeableBeacon(beacon).owner() == LendMultisig.SAFE, "Beacon is not owned by the Lend Safe");
            target = beacon;
            callData = abi.encodeCall(UpgradeableBeacon.upgradeTo, (implementation));
        }

        console.log("opLEND beacon:", beacon);
        console.log("New implementation:", implementation);

        vm.startBroadcast(deployer);

        LendMultisig.proposeTransaction(target, callData);

        vm.stopBroadcast();
    }
}
