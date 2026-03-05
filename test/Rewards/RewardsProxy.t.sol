// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {TestBase} from "../TestBase.t.sol";
import {MerkleHelper} from "../MerkleHelper.sol";
import {LendRewards} from "../../src/Rewards.sol";
import {IPoolDataProvider, IPoolAddressesProvider, IPool} from "../../src/interfaces/AaveInterfaces.sol";

import {RewardsTest} from "./Rewards.t.sol";

contract RewardsProxyTest is Test, RewardsTest {
    function test_UpgradeProxy() public {
        Options memory opts;
        Upgrades.validateUpgrade("Rewards.sol:LendRewards", opts);
    }
}
