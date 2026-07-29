// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {RestitutionTest} from "./Restitution.t.sol";

contract RewardsProxyTest is Test, RestitutionTest {
    function test_UpgradeProxy() public {
        Options memory opts;
        Upgrades.validateUpgrade("Restitution.sol:LendRestitution", opts);
    }
}
