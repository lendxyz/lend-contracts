// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {OracleTest} from "./PriceOracle.t.sol";

contract OracleProxyTest is Test, OracleTest {
    function test_UpgradeProxy() public {
        Options memory opts;
        Upgrades.validateUpgrade("PriceOracle.sol:PriceOracle", opts);
    }
}
