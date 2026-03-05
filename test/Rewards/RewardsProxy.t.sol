// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {RewardsTest} from "./Rewards.t.sol";

contract RewardsProxyTest is Test, RewardsTest {
    function test_UpgradeProxy() public {
        Options memory opts;
        Upgrades.validateUpgrade("Rewards.sol:LendRewards", opts);
    }
}
