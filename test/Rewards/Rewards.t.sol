// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test, console} from "forge-std/Test.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {TestBase} from "../TestBase.t.sol";
import {MerkleHelper} from "../MerkleHelper.sol";
import {LendRewards} from "../../src/Rewards.sol";
import {IPoolDataProvider, IPoolAddressesProvider, IPool} from "../../src/interfaces/AaveInterfaces.sol";

contract RewardsTest is Test, TestBase, MerkleHelper {
    address aaveAddressProvider = address(0x2f39d218133AFaB8F2B819B1066c7E434Ad94E9e);
    IPool aavePool = IPool(IPoolAddressesProvider(aaveAddressProvider).getPool());

    uint256 totalAllocation = 600e6;
    uint256 epoch = 1;
    uint256 opId = 2;
    uint256 rewIndex = 2;
    address ru;
    uint256 ra;

    function createOpDistribution() public {
        bytes32 root = getRoot(rewardUsers, rewardAmounts);

        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation);
        rewards.distributeOpRewards(opId, epoch, root, totalAllocation);
        vm.stopPrank();
    }

    function createMultipleOpDistribution() public {
        bytes32 rootEpoch1 = getRoot(rewardUsers, rewardAmounts);
        bytes32 rootEpoch2 = getRoot(rewardUsers, rewardAmounts);
        bytes32 rootEpoch3 = getRoot(rewardUsers, rewardAmounts);

        deal(address(usdc), address(admin), totalAllocation * 3);

        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation * 3);
        rewards.distributeOpRewards(opId, 1, rootEpoch1, totalAllocation);
        rewards.distributeOpRewards(opId, 2, rootEpoch2, totalAllocation);
        rewards.distributeOpRewards(opId, 3, rootEpoch3, totalAllocation);
        vm.stopPrank();
    }

    function createMultipleRefDistribution() public {
        bytes32 rootEpoch1 = getRoot(rewardUsers, rewardAmounts);
        bytes32 rootEpoch2 = getRoot(rewardUsers, rewardAmounts);
        bytes32 rootEpoch3 = getRoot(rewardUsers, rewardAmounts);

        deal(address(usdc), address(admin), totalAllocation * 3);

        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation * 3);
        rewards.distributeRefRewards(1, rootEpoch1, totalAllocation);
        rewards.distributeRefRewards(2, rootEpoch2, totalAllocation);
        rewards.distributeRefRewards(3, rootEpoch3, totalAllocation);
        vm.stopPrank();
    }

    function createRefDistribution() public {
        bytes32 root = getRoot(rewardUsers, rewardAmounts);

        vm.startPrank(admin);
        usdc.approve(address(rewards), totalAllocation);
        rewards.distributeRefRewards(epoch, root, totalAllocation);
        vm.stopPrank();
    }

    function enableAaveModule() public {
        vm.prank(admin);
        rewards.setAaveAddressProvider(aaveAddressProvider);
    }

    function setUp() public override(TestBase) {
        super.setUp();
        deal(address(usdc), address(admin), totalAllocation);

        ru = rewardUsers[rewIndex];
        ra = rewardAmounts[rewIndex];
    }
}
