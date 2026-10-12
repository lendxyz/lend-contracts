// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {Constants} from "script/common/Constants.s.sol";
import {UUPSSafeUpgrade} from "script/common/UUPSSafeUpgrade.s.sol";

contract UpgradeRewards is Script, Constants {
    function run() external {
        vm.startBroadcast();

        Upgrades.upgradeProxy(getMainnetRewardsAddress(), "Rewards.sol:LendRewards", "");

        vm.stopBroadcast();
    }
}

/// @notice Step 1 of the Safe upgrade: run with `--ledger`.
contract DeployUUPSImplementation is UUPSSafeUpgrade {
    function run() external {
        _deployImplementation("Rewards.sol:LendRewards");
    }
}

/// @notice Step 2 of the Safe upgrade: run without `--ledger`, with `LEDGER_HD_PATH` set.
contract ProposeUUPSUpgrade is UUPSSafeUpgrade, Constants {
    function run() external {
        _proposeUpgrade("UpgradeRewards.s.sol", "Rewards.sol:LendRewards", getMainnetRewardsAddress());
    }
}
