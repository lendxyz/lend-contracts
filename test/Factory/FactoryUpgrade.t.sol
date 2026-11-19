// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {FactoryUpgrade} from "script/common/FactoryUpgrade.s.sol";
import {FactoryUpgradeManifest} from "script/common/FactoryUpgradeManifest.s.sol";
import {LendFactory} from "src/Factory/DiamondProxy.sol";
import {IDiamondCut} from "src/Factory/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "src/Factory/interfaces/IDiamondLoupe.sol";
import {IERC173} from "src/Factory/interfaces/IERC173.sol";
import {Getters} from "src/Factory/facets/Getters.sol";
import {Ownership} from "src/Factory/facets/Ownership.sol";
import {
    AdminAddMock,
    GettersReplaceMock,
    OwnershipRemoveMock,
    OwnershipMisreadMock,
    FactoryUpgradeInitMock
} from "test/mocks/FactoryUpgradeMocks.sol";

/// @notice Upgrades of the live factories (Ethereum and Sepolia forks) with mock builds: every cut action, the manifest
///         checks and the simulation guards. The mock scenarios start from the live factory with the pending upgrade
///         (`FactoryUpgradeManifest`) applied, i.e. from the build.
contract FactoryUpgradeTest is Test, FactoryUpgradeManifest {
    string constant MOCKS = "test/mocks/FactoryUpgradeMocks.sol";

    address diamond;
    address owner;

    function setUp() public {
        vm.createSelectFork("mainnet");
        diamond = MAINNET_FACTORY;
        owner = IERC173(diamond).owner();
        _applyPendingUpgrade();
    }

    // ------------------------------------------------------------------------------------------------------------
    // Live factories
    // ------------------------------------------------------------------------------------------------------------

    /// @dev The live diff is exactly the upgrade declared in `FactoryUpgradeManifest` (none once it is executed and the
    ///      manifest emptied): fails on an undeclared facet change and on a stale declaration.
    function test_MainnetDiffMatchesManifest() public {
        vm.createSelectFork("mainnet");
        FactoryUpgrade.Manifest memory m = manifest();
        FactoryUpgrade.checkManifest(FactoryUpgrade.plan(diamond, FactoryUpgrade.facets(), m), m);
    }

    /// @dev Sepolia is upgraded before mainnet: its diff is either empty (declared upgrade already executed there) or
    ///      exactly the declared one.
    function test_SepoliaDiffEmptyOrMatchesManifest() public {
        _forkSepolia();
        FactoryUpgrade.Manifest memory m = manifest();
        FactoryUpgrade.Plan memory p = FactoryUpgrade.plan(TESTNET_FACTORY, FactoryUpgrade.facets(), m);
        if (p.cut.length != 0) FactoryUpgrade.checkManifest(p, m);
    }

    // ------------------------------------------------------------------------------------------------------------
    // Cut actions
    // ------------------------------------------------------------------------------------------------------------

    function test_Replace() public {
        FactoryUpgrade.Facet[] memory specs = _with(FactoryUpgrade.facets(), _gettersReplace());
        FactoryUpgrade.Manifest memory m = _empty();
        m.redeployedFacets = FactoryUpgrade.list("Getters");

        FactoryUpgrade.Plan memory p = this.simulateUpgrade(diamond, specs, m);

        address target = FactoryUpgrade.predict(type(GettersReplaceMock).creationCode);
        assertEq(p.cut.length, 1);
        assertEq(uint8(p.cut[0].action), uint8(IDiamondCut.FacetCutAction.Replace));
        assertEq(p.cut[0].facetAddress, target);
        assertEq(p.cut[0].functionSelectors.length, 15);

        address usdcBefore = address(Getters(diamond).usdc());
        _execute(p);

        assertEq(IDiamondLoupe(diamond).facetAddress(Getters.usdc.selector), target);
        assertEq(address(Getters(diamond).usdc()), usdcBefore);
        assertTrue(FactoryUpgrade.isEmpty(FactoryUpgrade.plan(diamond, specs, _empty())));
    }

    function test_Add() public {
        FactoryUpgrade.Facet[] memory specs = _with(FactoryUpgrade.facets(), _adminAdd());
        FactoryUpgrade.Manifest memory m = _empty();
        m.redeployedFacets = FactoryUpgrade.list("Admin");
        m.addedFunctions = FactoryUpgrade.list("upgradeProbe()");

        FactoryUpgrade.Plan memory p = this.simulateUpgrade(diamond, specs, m);

        assertEq(p.cut.length, 2);
        assertEq(uint8(p.cut[0].action), uint8(IDiamondCut.FacetCutAction.Add));
        assertEq(p.cut[0].functionSelectors.length, 1);
        assertEq(p.cut[0].functionSelectors[0], AdminAddMock.upgradeProbe.selector);
        assertEq(uint8(p.cut[1].action), uint8(IDiamondCut.FacetCutAction.Replace));
        assertEq(p.cut[1].functionSelectors.length, 13);

        vm.expectRevert(LendFactory.UnsupportedOperation.selector);
        AdminAddMock(diamond).upgradeProbe();

        _execute(p);

        assertEq(AdminAddMock(diamond).upgradeProbe(), 42);
        assertTrue(FactoryUpgrade.isEmpty(FactoryUpgrade.plan(diamond, specs, _empty())));
    }

    function test_Remove() public {
        FactoryUpgrade.Facet[] memory specs = _with(FactoryUpgrade.facets(), _ownershipRemove());
        FactoryUpgrade.Manifest memory m = _empty();
        m.redeployedFacets = FactoryUpgrade.list("Ownership");
        m.removedFunctions = FactoryUpgrade.list("transferOwnership(address)");

        FactoryUpgrade.Plan memory p = this.simulateUpgrade(diamond, specs, m);

        assertEq(p.cut.length, 2);
        assertEq(uint8(p.cut[0].action), uint8(IDiamondCut.FacetCutAction.Replace));
        assertEq(p.cut[0].functionSelectors[0], Ownership.owner.selector);
        assertEq(uint8(p.cut[1].action), uint8(IDiamondCut.FacetCutAction.Remove));
        assertEq(p.cut[1].facetAddress, address(0));
        assertEq(p.cut[1].functionSelectors.length, 1);
        assertEq(p.cut[1].functionSelectors[0], Ownership.transferOwnership.selector);

        _execute(p);

        assertEq(IERC173(diamond).owner(), owner);
        vm.prank(owner);
        vm.expectRevert(LendFactory.UnsupportedOperation.selector);
        IERC173(diamond).transferOwnership(address(1));
        assertTrue(FactoryUpgrade.isEmpty(FactoryUpgrade.plan(diamond, specs, _empty())));
    }

    function test_AddReplaceRemove() public {
        _upgradeAllActions();
    }

    function test_AddReplaceRemove_Sepolia() public {
        _forkSepolia();
        diamond = TESTNET_FACTORY;
        owner = IERC173(diamond).owner();
        _applyPendingUpgrade();

        _upgradeAllActions();
    }

    function test_SimulationLeavesNoTrace() public {
        FactoryUpgrade.Facet[] memory specs = _with(FactoryUpgrade.facets(), _adminAdd());
        FactoryUpgrade.Manifest memory m = _empty();
        m.redeployedFacets = FactoryUpgrade.list("Admin");
        m.addedFunctions = FactoryUpgrade.list("upgradeProbe()");

        bytes32 facetsBefore = keccak256(abi.encode(IDiamondLoupe(diamond).facets()));
        this.simulateUpgrade(diamond, specs, m);

        assertEq(keccak256(abi.encode(IDiamondLoupe(diamond).facets())), facetsBefore);
        assertEq(FactoryUpgrade.predict(type(AdminAddMock).creationCode).code.length, 0);
    }

    // ------------------------------------------------------------------------------------------------------------
    // Manifest
    // ------------------------------------------------------------------------------------------------------------

    function test_RevertWhen_AddUndeclared() public {
        FactoryUpgrade.Manifest memory m = _empty();
        m.redeployedFacets = FactoryUpgrade.list("Admin");

        vm.expectRevert(bytes("FactoryUpgrade: undeclared added function upgradeProbe(), declare it in the manifest"));
        this.simulateUpgrade(diamond, _with(FactoryUpgrade.facets(), _adminAdd()), m);
    }

    function test_RevertWhen_RemoveUndeclared() public {
        FactoryUpgrade.Manifest memory m = _empty();
        m.redeployedFacets = FactoryUpgrade.list("Ownership");

        vm.expectRevert(bytes("FactoryUpgrade: undeclared removed function 0xf2fde38b, declare it in the manifest"));
        this.simulateUpgrade(diamond, _with(FactoryUpgrade.facets(), _ownershipRemove()), m);
    }

    function test_RevertWhen_RedeployUndeclared() public {
        vm.expectRevert(bytes("FactoryUpgrade: undeclared redeployed facet Getters, declare it in the manifest"));
        this.simulateUpgrade(diamond, _with(FactoryUpgrade.facets(), _gettersReplace()), _empty());
    }

    function test_RevertWhen_DeclaredChangeNotInDiff() public {
        FactoryUpgrade.Manifest memory m = _empty();
        m.addedFunctions = FactoryUpgrade.list("upgradeProbe()");

        vm.expectRevert(bytes("FactoryUpgrade: declared added function upgradeProbe() is not in the diff"));
        this.simulateUpgrade(diamond, FactoryUpgrade.facets(), m);
    }

    // ------------------------------------------------------------------------------------------------------------
    // Simulation guards
    // ------------------------------------------------------------------------------------------------------------

    function test_RevertWhen_FacetMisreadsStorage() public {
        FactoryUpgrade.Manifest memory m = _empty();
        m.redeployedFacets = FactoryUpgrade.list("Ownership");

        vm.expectRevert(bytes("FactoryUpgrade: the upgrade changes the output of owner()"));
        this.simulateUpgrade(diamond, _with(FactoryUpgrade.facets(), _ownershipMisread()), m);
    }

    function test_ChangedViewDeclared() public {
        FactoryUpgrade.Manifest memory m = _empty();
        m.redeployedFacets = FactoryUpgrade.list("Ownership");
        m.changedViews = FactoryUpgrade.list("owner()");

        this.simulateUpgrade(diamond, _with(FactoryUpgrade.facets(), _ownershipMisread()), m);
    }

    function test_InitDeclaredWrite() public {
        address newEurc = makeAddr("new-eurc");
        FactoryUpgrade.Manifest memory m = _init(abi.encodeCall(FactoryUpgradeInitMock.setEurc, (newEurc)));
        m.initWrites = FactoryUpgrade.list("AppStorage.eurc");
        m.changedViews = FactoryUpgrade.list("eurc()");

        FactoryUpgrade.Plan memory p = this.simulateUpgrade(diamond, FactoryUpgrade.facets(), m);
        assertEq(p.cut.length, 0);
        assertEq(p.init, FactoryUpgrade.predict(type(FactoryUpgradeInitMock).creationCode));

        _execute(p);
        assertEq(address(Getters(diamond).eurc()), newEurc);
    }

    function test_RevertWhen_InitChangesUndeclaredView() public {
        FactoryUpgrade.Manifest memory m = _init(abi.encodeCall(FactoryUpgradeInitMock.setEurc, (makeAddr("new-eurc"))));
        m.initWrites = FactoryUpgrade.list("AppStorage.eurc");

        vm.expectRevert(bytes("FactoryUpgrade: the upgrade changes the output of eurc()"));
        this.simulateUpgrade(diamond, FactoryUpgrade.facets(), m);
    }

    function test_RevertWhen_InitWritesUndeclaredField() public {
        _expectSimulationRevert(
            _init(abi.encodeCall(FactoryUpgradeInitMock.setEurc, (makeAddr("new-eurc")))),
            "FactoryUpgrade: the upgrade writes undeclared storage AppStorage.eurc (slot "
        );
        _expectSimulationRevert(
            _init(abi.encodeCall(FactoryUpgradeInitMock.resetOperationCount, ())),
            "FactoryUpgrade: the upgrade writes undeclared storage AppStorage.operationCount (slot "
        );
    }

    function test_RevertWhen_InitWritesMappingEntry() public {
        _expectSimulationRevert(
            _init(abi.encodeCall(FactoryUpgradeInitMock.blacklistAccount, (makeAddr("account")))),
            "FactoryUpgrade: the upgrade writes undeclared storage AppStorage.blacklisted (slot "
        );
    }

    function test_RevertWhen_InitWritesStructInMapping() public {
        _expectSimulationRevert(
            _init(abi.encodeCall(FactoryUpgradeInitMock.setOperationShares, (1, 1))),
            "FactoryUpgrade: the upgrade writes undeclared storage AppStorage.operations (slot "
        );
    }

    function test_RevertWhen_InitHijacksOwnership() public {
        _expectSimulationRevert(
            _init(abi.encodeCall(FactoryUpgradeInitMock.setOwner, (makeAddr("attacker")))),
            "FactoryUpgrade: the upgrade writes undeclared storage DiamondStorage.contractOwner (slot "
        );
    }

    function test_RevertWhen_InitWritesExternalContract() public {
        _expectSimulationRevert(
            _init(abi.encodeCall(FactoryUpgradeInitMock.approveUsdc, (makeAddr("spender")))),
            "FactoryUpgrade: the upgrade writes the storage of 0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48"
        );
    }

    function test_RevertWhen_InitReverts() public {
        vm.expectRevert(bytes("init failed"));
        this.simulateUpgrade(
            diamond, FactoryUpgrade.facets(), _init(abi.encodeCall(FactoryUpgradeInitMock.revertingInit, ()))
        );
    }

    function test_InitWithoutNetChange() public {
        this.simulateUpgrade(
            diamond, FactoryUpgrade.facets(), _init(abi.encodeCall(FactoryUpgradeInitMock.lockAndRelease, ()))
        );
    }

    // ------------------------------------------------------------------------------------------------------------
    // Helpers
    // ------------------------------------------------------------------------------------------------------------

    /// @dev The upgrade scripts' checks, as an external call so that their reverts can be expected.
    function simulateUpgrade(address _diamond, FactoryUpgrade.Facet[] memory specs, FactoryUpgrade.Manifest memory m)
        external
        returns (FactoryUpgrade.Plan memory p)
    {
        p = FactoryUpgrade.plan(_diamond, specs, m);
        FactoryUpgrade.checkManifest(p, m);
        FactoryUpgrade.simulate(p, m, specs);
    }

    /// @dev Checks, simulates and executes the upgrade declared in `FactoryUpgradeManifest`, if any.
    function _applyPendingUpgrade() internal {
        FactoryUpgrade.Manifest memory m = manifest();
        if (FactoryUpgrade.isEmpty(FactoryUpgrade.plan(diamond, FactoryUpgrade.facets(), m))) return;
        _execute(this.simulateUpgrade(diamond, FactoryUpgrade.facets(), m));
    }

    function _upgradeAllActions() internal {
        FactoryUpgrade.Facet[] memory specs =
            _with(_with(_with(FactoryUpgrade.facets(), _adminAdd()), _gettersReplace()), _ownershipRemove());
        FactoryUpgrade.Manifest memory m = _empty();
        m.redeployedFacets = FactoryUpgrade.list("Admin", "Getters", "Ownership");
        m.addedFunctions = FactoryUpgrade.list("upgradeProbe()");
        m.removedFunctions = FactoryUpgrade.list("transferOwnership(address)");

        FactoryUpgrade.Plan memory p = this.simulateUpgrade(diamond, specs, m);
        assertEq(p.cut.length, 5);

        address usdcBefore = address(Getters(diamond).usdc());
        _execute(p);

        assertEq(AdminAddMock(diamond).upgradeProbe(), 42);
        assertEq(address(Getters(diamond).usdc()), usdcBefore);
        assertEq(IERC173(diamond).owner(), owner);
        assertEq(IDiamondLoupe(diamond).facetAddress(Ownership.transferOwnership.selector), address(0));
        assertTrue(FactoryUpgrade.isEmpty(FactoryUpgrade.plan(diamond, specs, _empty())));
    }

    /// @dev A few blocks behind the head: the public Sepolia RPC load balancer serves the head late on some nodes.
    function _forkSepolia() internal {
        vm.createSelectFork("sepolia");
        vm.rollFork(block.number - 8);
    }

    function _execute(FactoryUpgrade.Plan memory p) internal {
        FactoryUpgrade.deploy(p);
        vm.prank(owner);
        IDiamondCut(diamond).diamondCut(p.cut, p.init, p.initCalldata);
    }

    function _expectSimulationRevert(FactoryUpgrade.Manifest memory m, string memory reasonPrefix) internal {
        try this.simulateUpgrade(diamond, FactoryUpgrade.facets(), m) {
            fail();
        } catch Error(string memory reason) {
            assertTrue(vm.contains(reason, reasonPrefix), reason);
        }
    }

    function _empty() internal pure returns (FactoryUpgrade.Manifest memory) {
        return FactoryUpgrade.emptyManifest();
    }

    function _init(bytes memory initCalldata) internal pure returns (FactoryUpgrade.Manifest memory m) {
        m.initCreationCode = type(FactoryUpgradeInitMock).creationCode;
        m.initCalldata = initCalldata;
    }

    function _with(FactoryUpgrade.Facet[] memory specs, FactoryUpgrade.Facet memory replacement)
        internal
        pure
        returns (FactoryUpgrade.Facet[] memory)
    {
        for (uint256 i; i < specs.length; i++) {
            if (keccak256(bytes(specs[i].name)) == keccak256(bytes(replacement.name))) specs[i] = replacement;
        }
        return specs;
    }

    function _adminAdd() internal pure returns (FactoryUpgrade.Facet memory) {
        return FactoryUpgrade.Facet(
            "Admin", MOCKS, "AdminAddMock", type(AdminAddMock).creationCode, type(AdminAddMock).runtimeCode
        );
    }

    function _gettersReplace() internal pure returns (FactoryUpgrade.Facet memory) {
        return FactoryUpgrade.Facet(
            "Getters",
            MOCKS,
            "GettersReplaceMock",
            type(GettersReplaceMock).creationCode,
            type(GettersReplaceMock).runtimeCode
        );
    }

    function _ownershipRemove() internal pure returns (FactoryUpgrade.Facet memory) {
        return FactoryUpgrade.Facet(
            "Ownership",
            MOCKS,
            "OwnershipRemoveMock",
            type(OwnershipRemoveMock).creationCode,
            type(OwnershipRemoveMock).runtimeCode
        );
    }

    function _ownershipMisread() internal pure returns (FactoryUpgrade.Facet memory) {
        return FactoryUpgrade.Facet(
            "Ownership",
            MOCKS,
            "OwnershipMisreadMock",
            type(OwnershipMisreadMock).creationCode,
            type(OwnershipMisreadMock).runtimeCode
        );
    }
}
