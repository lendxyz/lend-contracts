// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {ERC1967Utils} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Utils.sol";
import {UpgradeableBeacon} from "@openzeppelin/contracts/proxy/beacon/UpgradeableBeacon.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {ILendFactory} from "src/Factory/interfaces/IFactory.sol";
import {LendOperation} from "src/opLend.sol";
import {TestBase} from "test/TestBase.t.sol";

interface IEndpointDelegates {
    function delegates(address oapp) external view returns (address);
}

contract LendOperationV2Mock is LendOperation {
    constructor(address lzEndpoint) LendOperation(lzEndpoint) {}

    function version() external pure returns (uint256) {
        return 2;
    }
}

contract FactoryOpLendBeaconTest is Test, TestBase {
    function newOperation() public returns (LendOperation) {
        vm.prank(admin);
        return LendOperation(factory.createOperation("Test operation", totalSharesAmount, sharePriceEur));
    }

    function test_CreateOperationDeploysBeaconProxy() public {
        LendOperation op = newOperation();
        address beacon = factory.opLendBeacon();

        assertEq(address(uint160(uint256(vm.load(address(op), ERC1967Utils.BEACON_SLOT)))), beacon);
        assertEq(UpgradeableBeacon(beacon).owner(), address(factory));
        assertEq(op.owner(), address(factory));
        assertEq(IEndpointDelegates(mnFactArgs.lzEndpoint).delegates(address(op)), admin);
        assertEq(op.decimals(), 6);
        assertEq(op.MAX_SUPPLY(), totalSharesAmount);
    }

    function test_RevertWhen_InitializingTwice() public {
        LendOperation op = newOperation();

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        op.initialize(user, "Hijack", "HJK", 1, user, user);
    }

    function test_RevertWhen_InitializingTheImplementation() public {
        LendOperation implementation = LendOperation(UpgradeableBeacon(factory.opLendBeacon()).implementation());

        vm.expectRevert(Initializable.InvalidInitialization.selector);
        implementation.initialize(user, "Hijack", "HJK", 1, user, user);
    }

    function test_UpdateOpLendImplementationUpgradesEveryOperation() public {
        LendOperation first = newOperation();
        LendOperation second = newOperation();
        address beacon = factory.opLendBeacon();

        vm.prank(address(factory));
        first.mint(user, sharesToBuy);

        vm.startPrank(admin);
        factory.opLendWhitelistUser(2, user2, true);

        LendOperationV2Mock v2 = new LendOperationV2Mock(mnFactArgs.lzEndpoint);
        vm.expectEmit(address(factory));
        emit ILendFactory.OpLendImplementationUpdated(address(v2));
        factory.updateOpLendImplementation(address(v2));
        vm.stopPrank();

        assertEq(factory.opLendBeacon(), beacon);
        assertEq(UpgradeableBeacon(beacon).implementation(), address(v2));
        assertEq(LendOperationV2Mock(address(first)).version(), 2);
        assertEq(LendOperationV2Mock(address(second)).version(), 2);
        // State lives in the proxies: untouched by the upgrade.
        assertEq(first.balanceOf(user), sharesToBuy);
        assertEq(first.symbol(), "opLEND-1");
        assertEq(second.symbol(), "opLEND-2");
        assertTrue(second.whitelisted(user2));
    }

    function test_RevertWhen_UpdateOpLendImplementationNotOwner() public {
        LendOperationV2Mock v2 = new LendOperationV2Mock(mnFactArgs.lzEndpoint);

        vm.prank(user);
        vm.expectRevert("LibDiamond: Must be contract owner");
        factory.updateOpLendImplementation(address(v2));
    }

    function test_RevertWhen_UpdateOpLendImplementationOtherEndpoint() public {
        LendOperationV2Mock v2 = new LendOperationV2Mock(tnFactArgs.lzEndpoint);

        vm.prank(admin);
        vm.expectRevert("Implementation LZ endpoint mismatch");
        factory.updateOpLendImplementation(address(v2));
    }

    function test_RevertWhen_BeaconUpgradedOutsideFactory() public {
        UpgradeableBeacon beacon = UpgradeableBeacon(factory.opLendBeacon());
        LendOperationV2Mock v2 = new LendOperationV2Mock(mnFactArgs.lzEndpoint);

        vm.prank(admin);
        vm.expectRevert(abi.encodeWithSelector(Ownable.OwnableUnauthorizedAccount.selector, admin));
        beacon.upgradeTo(address(v2));
    }

    function test_RevertWhen_CreateOperationWithoutImplementation() public {
        vm.startPrank(admin);
        deployDiamond();

        vm.expectRevert(ILendFactory.OpLendImplementationNotSet.selector);
        factory.createOperation("Test operation", totalSharesAmount, sharePriceEur);
        vm.stopPrank();
    }
}
