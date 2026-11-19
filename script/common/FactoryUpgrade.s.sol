// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Vm, VmSafe} from "forge-std/Vm.sol";
import {console} from "forge-std/console.sol";
import {IDiamondCut} from "src/Factory/interfaces/IDiamondCut.sol";
import {IDiamondLoupe} from "src/Factory/interfaces/IDiamondLoupe.sol";
import {IERC165} from "src/Factory/interfaces/IERC165.sol";
import {LibAppStorage} from "src/Factory/lib/Storage.sol";
import {LibDiamond} from "src/Factory/lib/LibDiamond.sol";

import {Admin} from "src/Factory/facets/Admin.sol";
import {Getters} from "src/Factory/facets/Getters.sol";
import {Invest} from "src/Factory/facets/Invest.sol";
import {Operations} from "src/Factory/facets/Operations.sol";
import {Ownership} from "src/Factory/facets/Ownership.sol";

/// @notice Computes, checks and simulates the Factory diamond upgrades.
/// @dev The target state is the build: every external function of the registry facets, read from their artifacts,
///      routed to a facet holding the build's executable code (metadata excluded). The cut is the diff between this
///      target and the live diamond, so it never has to be written by hand:
///      - selector routed nowhere -> Add
///      - selector routed to a facet holding other code -> Replace
///      - selector routed but absent from the build -> Remove
///      Facets are deployed through the deterministic CREATE2 deployer: their address commits to their creation code,
///      so a deployment from another build can never be picked up, and an unchanged facet is never redeployed.
///
///      Every upgrade script runs, before broadcasting anything:
///      1. `checkManifest`: the diff must be exactly the one declared in `FactoryUpgradeManifest`.
///      2. `checkStorageLayout`: the AppStorage layout must extend the one of the deployed version.
///      3. `simulate`: executes the cut as the diamond owner on the fork, then reverts it. Aborts if the cut reverts,
///         writes storage the manifest does not declare, changes the output of an existing view, or leaves the diamond
///         different from the build.
library FactoryUpgrade {
    Vm private constant vm = Vm(address(uint160(uint256(keccak256("hevm cheat code")))));

    /// @dev Deterministic deployment proxy (https://github.com/Arachnid/deterministic-deployment-proxy).
    address internal constant CREATE2_FACTORY = 0x4e59b44847b379578588920cA78FbF26c0B4956C;
    bytes32 internal constant SALT = keccak256("lend.factory.facet");

    /// @dev Bounds of the simulation probes and of the storage slot classification.
    uint256 private constant MAX_PROBED_OPERATIONS = 256;
    uint256 private constant PROBE_AMOUNT = 1_000e6;
    uint256 private constant MAX_STRUCT_SLOTS = 16;
    uint256 private constant MAX_ARRAY_SLOTS = 1024;
    bytes32 private constant REVERTED = keccak256("FactoryUpgrade.reverted");

    /// @notice A facet of the build. `name` identifies it in the manifest, `source`/`contractName` locate its artifact.
    struct Facet {
        string name;
        string source;
        string contractName;
        bytes creationCode;
        bytes runtimeCode;
    }

    /// @notice Declared intent of an upgrade, compared to the computed diff and to the simulated effects.
    struct Manifest {
        // Facets whose selectors move to a new deployment.
        string[] redeployedFacets;
        // Signatures of the functions the cut adds.
        string[] addedFunctions;
        // Signatures of the functions the cut removes.
        string[] removedFunctions;
        // Signatures of existing views whose output may change (new return format, value set by the init).
        string[] changedViews;
        // Storage fields the init may write: "AppStorage.<member>" or "DiamondStorage.<member>".
        string[] initWrites;
        // Existing contracts whose storage the init may write.
        address[] externalWrites;
        // Creation code of the contract delegatecalled after the cut (deployed through CREATE2), empty for none.
        bytes initCreationCode;
        bytes initCalldata;
    }

    struct FacetPlan {
        string name;
        address target;
        bool deploy;
        bytes creationCode;
        bytes4[] selectors;
        string[] signatures;
        bool[] isView;
    }

    struct Plan {
        address diamond;
        FacetPlan[] facets;
        IDiamondCut.FacetCut[] cut;
        string[] added;
        bytes4[] removed;
        string[] redeployed;
        address init;
        bool deployInit;
        bytes initCreationCode;
        bytes initCalldata;
    }

    struct Layout {
        string[] labels;
        uint256[] slots;
    }

    struct Links {
        uint256[] offsets;
        bytes32[] libraryHashes;
    }

    // ------------------------------------------------------------------------------------------------------------
    // Registry
    // ------------------------------------------------------------------------------------------------------------

    /// @notice Facets of the Factory diamond.
    function facets() internal pure returns (Facet[] memory f) {
        f = new Facet[](5);
        f[0] =
            Facet("Admin", "src/Factory/facets/Admin.sol", "Admin", type(Admin).creationCode, type(Admin).runtimeCode);
        f[1] = Facet(
            "Getters",
            "src/Factory/facets/Getters.sol",
            "Getters",
            type(Getters).creationCode,
            type(Getters).runtimeCode
        );
        f[2] = Facet(
            "Invest", "src/Factory/facets/Invest.sol", "Invest", type(Invest).creationCode, type(Invest).runtimeCode
        );
        f[3] = Facet(
            "Operations",
            "src/Factory/facets/Operations.sol",
            "Operations",
            type(Operations).creationCode,
            type(Operations).runtimeCode
        );
        f[4] = Facet(
            "Ownership",
            "src/Factory/facets/Ownership.sol",
            "Ownership",
            type(Ownership).creationCode,
            type(Ownership).runtimeCode
        );
    }

    function emptyManifest() internal pure returns (Manifest memory m) {}

    function list(string memory a) internal pure returns (string[] memory l) {
        l = new string[](1);
        l[0] = a;
    }

    function list(string memory a, string memory b) internal pure returns (string[] memory l) {
        l = new string[](2);
        l[0] = a;
        l[1] = b;
    }

    function list(string memory a, string memory b, string memory c) internal pure returns (string[] memory l) {
        l = new string[](3);
        l[0] = a;
        l[1] = b;
        l[2] = c;
    }

    // ------------------------------------------------------------------------------------------------------------
    // Plan
    // ------------------------------------------------------------------------------------------------------------

    /// @notice Diff between the build (`specs`) and `diamond`, plus the init declared by `m`.
    function plan(address diamond, Facet[] memory specs, Manifest memory m) internal view returns (Plan memory p) {
        p.diamond = diamond;
        p.facets = new FacetPlan[](specs.length);
        for (uint256 i; i < specs.length; i++) {
            p.facets[i] = _facetPlan(diamond, specs[i]);
        }

        bytes4[] memory targetSelectors = _targetSelectors(p.facets);
        p.removed = _removedSelectors(diamond, targetSelectors);
        _diff(p, targetSelectors.length);

        p.initCreationCode = m.initCreationCode;
        p.initCalldata = m.initCalldata;
        if (m.initCreationCode.length != 0) {
            p.init = predict(m.initCreationCode);
            p.deployInit = p.init.code.length == 0;
        } else {
            require(m.initCalldata.length == 0, "FactoryUpgrade: init calldata without init contract");
        }
    }

    function isEmpty(Plan memory p) internal pure returns (bool) {
        return p.cut.length == 0 && p.init == address(0);
    }

    function hasPendingDeployments(Plan memory p) internal pure returns (bool) {
        for (uint256 i; i < p.facets.length; i++) {
            if (p.facets[i].deploy) return true;
        }
        return p.deployInit;
    }

    function predict(bytes memory creationCode) internal pure returns (address) {
        return vm.computeCreate2Address(SALT, keccak256(creationCode), CREATE2_FACTORY);
    }

    /// @notice Deploys the facets and the init contract of `p` missing on chain. Broadcasts when called inside
    ///         `vm.startBroadcast()`.
    function deploy(Plan memory p) internal {
        for (uint256 i; i < p.facets.length; i++) {
            if (p.facets[i].deploy) _create2(p.facets[i].creationCode, p.facets[i].target);
        }
        if (p.deployInit) _create2(p.initCreationCode, p.init);
    }

    // ------------------------------------------------------------------------------------------------------------
    // Checks
    // ------------------------------------------------------------------------------------------------------------

    /// @notice Reverts unless the diff of `p` is exactly the one declared in `m`.
    function checkManifest(Plan memory p, Manifest memory m) internal pure {
        _sameSet("added function", _selectorKeys(p.added), p.added, _selectorKeys(m.addedFunctions), m.addedFunctions);

        bytes32[] memory removedKeys = new bytes32[](p.removed.length);
        string[] memory removedLabels = new string[](p.removed.length);
        for (uint256 i; i < p.removed.length; i++) {
            removedKeys[i] = bytes32(p.removed[i]);
            removedLabels[i] = _selectorLabel(p.removed[i], m.removedFunctions);
        }
        _sameSet("removed function", removedKeys, removedLabels, _selectorKeys(m.removedFunctions), m.removedFunctions);

        _sameSet(
            "redeployed facet", _nameKeys(p.redeployed), p.redeployed, _nameKeys(m.redeployedFacets), m.redeployedFacets
        );
    }

    /// @notice Reverts unless the AppStorage layout of the build extends the one of the deployed version
    ///         (`StorageMirrorLegacy`, pointing at the latest `src/legacy/Factory` snapshot).
    function checkStorageLayout() internal {
        string[] memory inputs = new string[](4);
        inputs[0] = "./test/check-storage.sh";
        inputs[1] = "src/utils/StorageMirrorLegacy.sol:StorageMirrorLegacy";
        inputs[2] = "src/utils/StorageMirror.sol:StorageMirror";
        inputs[3] = "AppStorage";

        string memory result = string(vm.ffi(inputs));
        require(
            _eq(result, "OK"),
            string.concat("FactoryUpgrade: AppStorage layout incompatible with the deployed version: ", result)
        );
    }

    /// @notice Reverts unless the factory of the `rpcAlias` chain already matches the build.
    function requireMatchesBuild(string memory rpcAlias, address diamond, Facet[] memory specs) internal {
        uint256 home = vm.activeFork();
        vm.createSelectFork(rpcAlias);
        // A few blocks behind the head: public RPC load balancers serve the head late on some nodes.
        vm.rollFork(block.number - 8);
        bool upToDate = isEmpty(plan(diamond, specs, emptyManifest()));
        vm.selectFork(home);

        require(
            upToDate,
            string.concat("FactoryUpgrade: the ", rpcAlias, " factory does not match the build, upgrade it first")
        );
    }

    /// @notice Executes `p` as the diamond owner on the current fork, checks its effects, then reverts the state.
    /// @dev Aborts if the cut reverts, if it writes a storage field or an existing contract the manifest does not
    ///      declare (net changes only), if an existing view returns another output for the same input, or if the
    ///      diamond does not match the build afterwards.
    function simulate(Plan memory p, Manifest memory m, Facet[] memory specs) internal {
        (VmSafe.CallerMode mode,,) = vm.readCallers();
        require(mode == VmSafe.CallerMode.None, "FactoryUpgrade: simulate outside broadcasts and pranks");

        Layout memory app = _appLayout();
        uint256 snapshot = vm.snapshotState();

        deploy(p);
        address owner = _owner(p.diamond);
        (bytes[] memory calls, string[] memory callLabels) = _viewCalls(p, m, owner, app);
        bytes32[] memory before = _results(p.diamond, calls);
        address[] memory facetsBefore = IDiamondLoupe(p.diamond).facetAddresses();

        vm.startMappingRecording();
        vm.startStateDiffRecording();
        vm.prank(owner);
        try IDiamondCut(p.diamond).diamondCut(p.cut, p.init, p.initCalldata) {}
        catch (bytes memory reason) {
            console.log("FactoryUpgrade: the simulated diamond cut reverts");
            assembly ("memory-safe") {
                revert(add(reason, 32), mload(reason))
            }
        }
        VmSafe.AccountAccess[] memory accesses = vm.stopAndReturnStateDiff();
        _auditWrites(p, m, accesses, facetsBefore, app);
        vm.stopMappingRecording();

        bytes32[] memory afterCut = _results(p.diamond, calls);
        for (uint256 i; i < calls.length; i++) {
            require(
                before[i] == afterCut[i],
                string.concat("FactoryUpgrade: the upgrade changes the output of ", callLabels[i])
            );
        }

        require(
            isEmpty(plan(p.diamond, specs, emptyManifest())),
            "FactoryUpgrade: the diamond does not match the build after the cut"
        );

        vm.revertToStateAndDelete(snapshot);

        console.log(
            string.concat(
                "Simulation passed: ",
                vm.toString(calls.length),
                " view calls unchanged, no undeclared storage write, diamond matches the build"
            )
        );
    }

    /// @notice Logs `p` for the signers.
    function describe(Plan memory p, Manifest memory m) internal pure {
        console.log("--- FACTORY UPGRADE PLAN ---");
        console.log("Diamond:", p.diamond);
        if (isEmpty(p)) {
            console.log("No change: the diamond matches the build");
            return;
        }

        for (uint256 i; i < p.facets.length; i++) {
            if (p.facets[i].deploy) console.log(string.concat("Deploy ", p.facets[i].name, " at"), p.facets[i].target);
        }
        if (p.deployInit) console.log("Deploy init contract at", p.init);

        for (uint256 i; i < p.cut.length; i++) {
            IDiamondCut.FacetCut memory c = p.cut[i];
            string memory action = c.action == IDiamondCut.FacetCutAction.Add
                ? "Add"
                : c.action == IDiamondCut.FacetCutAction.Replace ? "Replace" : "Remove";
            console.log(
                string.concat(action, " ", vm.toString(c.functionSelectors.length), " selectors ->"), c.facetAddress
            );
            for (uint256 j; j < c.functionSelectors.length; j++) {
                console.log(string.concat("  ", _signatureOf(p, m, c.functionSelectors[j])));
            }
        }

        if (p.init != address(0)) {
            console.log("Init:", p.init);
            console.log(string.concat("Init calldata: ", vm.toString(p.initCalldata)));
        }
    }

    // ------------------------------------------------------------------------------------------------------------
    // Plan internals
    // ------------------------------------------------------------------------------------------------------------

    function _facetPlan(address diamond, Facet memory f) private view returns (FacetPlan memory fp) {
        string memory json = _artifact(f.source, f.contractName);

        fp.name = f.name;
        fp.creationCode = f.creationCode;
        fp.signatures = vm.parseJsonKeys(json, ".methodIdentifiers");
        fp.selectors = new bytes4[](fp.signatures.length);
        fp.isView = new bool[](fp.signatures.length);

        string[] memory views = _strings(json, "$.abi[?(@.stateMutability == 'view')].name");
        string[] memory pures = _strings(json, "$.abi[?(@.stateMutability == 'pure')].name");
        for (uint256 i; i < fp.signatures.length; i++) {
            fp.selectors[i] = bytes4(keccak256(bytes(fp.signatures[i])));
            string memory name = _slice(fp.signatures[i], 0, vm.indexOf(fp.signatures[i], "("));
            fp.isView[i] = _containsString(views, name) || _containsString(pures, name);
        }

        // Keeps a live facet holding the build's executable code: an unchanged facet is never redeployed.
        Links memory links = _links(json);
        bytes32 codeHash = _executableHash(f.runtimeCode, links.offsets);
        address checked;
        for (uint256 i; i < fp.selectors.length; i++) {
            address current = IDiamondLoupe(diamond).facetAddress(fp.selectors[i]);
            if (current == address(0) || current == checked) continue;
            bytes memory code = current.code;
            if (_executableHash(code, links.offsets) == codeHash && _librariesMatch(code, links)) {
                fp.target = current;
                break;
            }
            checked = current;
        }
        if (fp.target == address(0)) fp.target = predict(f.creationCode);
        fp.deploy = fp.target.code.length == 0;
    }

    /// @dev Linked library references of an artifact's runtime code, with the executable hash of each library.
    function _links(string memory json) private view returns (Links memory links) {
        string memory root = "$.deployedBytecode.linkReferences";
        string[] memory sources = _keys(json, root);
        for (uint256 i; i < sources.length; i++) {
            string memory sourcePath = string.concat(root, "['", sources[i], "']");
            string[] memory names = _keys(json, sourcePath);
            for (uint256 j; j < names.length; j++) {
                uint256[] memory starts = _uints(json, string.concat(sourcePath, ".", names[j], "[*].start"));
                bytes memory libraryCode =
                    vm.parseJsonBytes(_artifact(sources[i], names[j]), ".deployedBytecode.object");
                bytes32 libraryHash = _libraryHash(libraryCode);
                for (uint256 k; k < starts.length; k++) {
                    links.offsets = _push(links.offsets, starts[k]);
                    links.libraryHashes = _push(links.libraryHashes, libraryHash);
                }
            }
        }
    }

    /// @dev The libraries linked in `code` hold the build's library code.
    function _librariesMatch(bytes memory code, Links memory links) private view returns (bool) {
        for (uint256 i; i < links.offsets.length; i++) {
            uint256 offset = links.offsets[i];
            if (offset + 20 > code.length) return false;
            bytes32 word;
            assembly ("memory-safe") {
                word := mload(add(add(code, 32), offset))
            }
            if (_libraryHash(address(bytes20(word)).code) != links.libraryHashes[i]) return false;
        }
        return true;
    }

    /// @dev Libraries start with `PUSH20 <own address>` (call protection), zero in the artifact, set at deployment.
    function _libraryHash(bytes memory code) private pure returns (bytes32) {
        uint256[] memory offsets;
        if (code.length > 21 && code[0] == 0x73) offsets = _push(offsets, 1);
        return _executableHash(code, offsets);
    }

    /// @dev Hash of `code` with its CBOR metadata hashes (its own and the ones of the creation codes it embeds) and its
    ///      linked library addresses zeroed. The metadata hashes change with the compilation context (the same facet
    ///      compiled for a test and for a script differs there), the executable code does not.
    function _executableHash(bytes memory code, uint256[] memory linkOffsets) private pure returns (bytes32) {
        bytes memory masked = bytes.concat(code);
        uint256 length = masked.length;

        // a2 64 "ipfs" 58 22 12 20 <32 bytes hash> 64 "solc" 43 <version> 00 33
        for (uint256 i; i + 53 <= length; i++) {
            bytes32 word;
            assembly ("memory-safe") {
                word := mload(add(add(masked, 32), i))
            }
            if (bytes10(word) != bytes10(0xa2646970667358221220)) continue;
            assembly ("memory-safe") {
                mstore(add(add(masked, 42), i), 0)
            }
            i += 52;
        }

        for (uint256 i; i < linkOffsets.length; i++) {
            uint256 offset = linkOffsets[i];
            require(offset + 20 <= length, "FactoryUpgrade: link reference out of the code");
            assembly ("memory-safe") {
                let p := add(add(masked, 32), offset)
                mstore(p, and(mload(p), 0xffffffffffffffffffffffff))
            }
        }
        return keccak256(masked);
    }

    /// @dev Selectors of the build; reverts on a selector in two facets or shadowed by the proxy's own functions.
    function _targetSelectors(FacetPlan[] memory fps) private pure returns (bytes4[] memory selectors) {
        uint256 total;
        for (uint256 i; i < fps.length; i++) {
            total += fps[i].selectors.length;
        }

        selectors = new bytes4[](total);
        uint256 n;
        for (uint256 i; i < fps.length; i++) {
            for (uint256 j; j < fps[i].selectors.length; j++) {
                bytes4 selector = fps[i].selectors[j];
                require(
                    !_containsSelector(selectors, n, selector),
                    string.concat("FactoryUpgrade: selector in two facets: ", fps[i].signatures[j])
                );
                require(
                    !_isProxyFunction(selector),
                    string.concat("FactoryUpgrade: selector shadowed by the proxy: ", fps[i].signatures[j])
                );
                selectors[n++] = selector;
            }
        }
    }

    /// @dev Fills the cut, added functions and redeployed facets of `p`.
    function _diff(Plan memory p, uint256 total) private view {
        p.cut = new IDiamondCut.FacetCut[](2 * p.facets.length + 1);
        p.added = new string[](total);
        p.redeployed = new string[](p.facets.length);

        uint256[3] memory n;
        for (uint256 i; i < p.facets.length; i++) {
            _facetDiff(p, p.facets[i], n);
        }
        if (p.removed.length != 0) {
            p.cut[n[0]++] = IDiamondCut.FacetCut(address(0), IDiamondCut.FacetCutAction.Remove, p.removed);
        }

        (IDiamondCut.FacetCut[] memory cut, string[] memory added, string[] memory redeployed) =
            (p.cut, p.added, p.redeployed);
        (uint256 nCut, uint256 nAdded, uint256 nRedeployed) = (n[0], n[1], n[2]);
        assembly ("memory-safe") {
            mstore(cut, nCut)
            mstore(added, nAdded)
            mstore(redeployed, nRedeployed)
        }
    }

    function _facetDiff(Plan memory p, FacetPlan memory fp, uint256[3] memory n) private view {
        bytes4[] memory adds = new bytes4[](fp.selectors.length);
        bytes4[] memory replaces = new bytes4[](fp.selectors.length);
        uint256 nAdds;
        uint256 nReplaces;

        for (uint256 j; j < fp.selectors.length; j++) {
            address current = IDiamondLoupe(p.diamond).facetAddress(fp.selectors[j]);
            if (current == address(0)) {
                adds[nAdds++] = fp.selectors[j];
                p.added[n[1]++] = fp.signatures[j];
            } else if (current != fp.target) {
                replaces[nReplaces++] = fp.selectors[j];
            }
        }

        if (nAdds != 0) {
            p.cut[n[0]++] = IDiamondCut.FacetCut(fp.target, IDiamondCut.FacetCutAction.Add, _shrink(adds, nAdds));
        }
        if (nReplaces != 0) {
            p.cut[n[0]++] =
                IDiamondCut.FacetCut(fp.target, IDiamondCut.FacetCutAction.Replace, _shrink(replaces, nReplaces));
        }
        if (fp.deploy || nReplaces != 0) p.redeployed[n[2]++] = fp.name;
    }

    function _removedSelectors(address diamond, bytes4[] memory targetSelectors)
        private
        view
        returns (bytes4[] memory removed)
    {
        IDiamondLoupe.Facet[] memory live = IDiamondLoupe(diamond).facets();

        uint256 total;
        for (uint256 i; i < live.length; i++) {
            total += live[i].functionSelectors.length;
        }

        removed = new bytes4[](total);
        uint256 n;
        for (uint256 i; i < live.length; i++) {
            // Functions defined in the proxy itself are immutable.
            if (live[i].facetAddress == diamond) continue;
            for (uint256 j; j < live[i].functionSelectors.length; j++) {
                bytes4 selector = live[i].functionSelectors[j];
                if (!_containsSelector(targetSelectors, targetSelectors.length, selector)) removed[n++] = selector;
            }
        }
        assembly ("memory-safe") {
            mstore(removed, n)
        }
    }

    function _isProxyFunction(bytes4 selector) private pure returns (bool) {
        return selector == IDiamondCut.diamondCut.selector || selector == IDiamondLoupe.facets.selector
            || selector == IDiamondLoupe.facetFunctionSelectors.selector
            || selector == IDiamondLoupe.facetAddresses.selector || selector == IDiamondLoupe.facetAddress.selector
            || selector == IERC165.supportsInterface.selector;
    }

    function _create2(bytes memory creationCode, address expected) private {
        if (expected.code.length != 0) return;
        require(CREATE2_FACTORY.code.length != 0, "FactoryUpgrade: no CREATE2 deployer on this chain");

        (bool success,) = CREATE2_FACTORY.call(abi.encodePacked(SALT, creationCode));
        require(success && expected.code.length != 0, "FactoryUpgrade: CREATE2 deployment failed");
    }

    /// @dev Artifact compiled from `source`: artifact paths of homonymous contracts depend on the other sources, and
    ///      `vm.getArtifactPathByDeployedCode` matches bytecodes fuzzily (it returns legacy copies of the facets).
    function _artifact(string memory source, string memory contractName) private view returns (string memory json) {
        string memory out = string.concat(vm.projectRoot(), "/out");
        string memory suffix = string.concat("/", _basename(source), "/", contractName, ".json");

        string memory guess = string.concat(out, suffix);
        if (vm.exists(guess)) {
            json = vm.readFile(guess);
            if (_compiledFrom(json, source)) return json;
        }

        VmSafe.DirEntry[] memory entries = vm.readDir(out, 6);
        for (uint256 i; i < entries.length; i++) {
            if (entries[i].isDir || !_endsWith(entries[i].path, suffix)) continue;
            json = vm.readFile(entries[i].path);
            if (_compiledFrom(json, source)) return json;
        }

        revert(string.concat("FactoryUpgrade: no artifact for ", source, ":", contractName, ", run forge build"));
    }

    function _compiledFrom(string memory json, string memory source) private pure returns (bool) {
        string[] memory targets = vm.parseJsonKeys(json, ".metadata.settings.compilationTarget");
        return targets.length == 1 && _eq(targets[0], source);
    }

    /// @dev Typed JSON cheatcodes require exactly one match; the untyped one encodes several matches as an array.
    function _strings(string memory json, string memory path) private pure returns (string[] memory values) {
        try vm.parseJsonString(json, path) returns (string memory value) {
            values = new string[](1);
            values[0] = value;
            return values;
        } catch {}
        try vm.parseJson(json, path) returns (bytes memory encoded) {
            if (encoded.length != 0) values = abi.decode(encoded, (string[]));
        } catch {}
    }

    function _uints(string memory json, string memory path) private pure returns (uint256[] memory values) {
        try vm.parseJsonUint(json, path) returns (uint256 value) {
            values = new uint256[](1);
            values[0] = value;
            return values;
        } catch {}
        values = abi.decode(vm.parseJson(json, path), (uint256[]));
    }

    /// @dev Keys of the object at `path`, none if it is empty or missing.
    function _keys(string memory json, string memory path) private pure returns (string[] memory keys) {
        try vm.parseJsonKeys(json, path) returns (string[] memory result) {
            return result;
        } catch {}
    }

    function _push(uint256[] memory array, uint256 value) private pure returns (uint256[] memory result) {
        result = new uint256[](array.length + 1);
        for (uint256 i; i < array.length; i++) {
            result[i] = array[i];
        }
        result[array.length] = value;
    }

    function _push(bytes32[] memory array, bytes32 value) private pure returns (bytes32[] memory result) {
        result = new bytes32[](array.length + 1);
        for (uint256 i; i < array.length; i++) {
            result[i] = array[i];
        }
        result[array.length] = value;
    }

    // ------------------------------------------------------------------------------------------------------------
    // Simulation internals
    // ------------------------------------------------------------------------------------------------------------

    function _owner(address diamond) private view returns (address) {
        return address(uint160(uint256(vm.load(diamond, _diamondSlot(4)))));
    }

    /// @dev Calls of the existing views: every operation id for the views keyed by operation, the owner for the views
    ///      keyed by account.
    function _viewCalls(Plan memory p, Manifest memory m, address owner, Layout memory app)
        private
        view
        returns (bytes[] memory calls, string[] memory labels)
    {
        uint256 ids = uint256(vm.load(p.diamond, _appSlot(app, "operationCount"))) + 2;
        if (ids > MAX_PROBED_OPERATIONS) ids = MAX_PROBED_OPERATIONS;
        bytes32[] memory changed = _selectorKeys(m.changedViews);

        uint256 total;
        for (uint256 i; i < p.facets.length; i++) {
            total += p.facets[i].selectors.length * ids;
        }
        calls = new bytes[](total);
        labels = new string[](total);

        uint256 n;
        for (uint256 i; i < p.facets.length; i++) {
            FacetPlan memory fp = p.facets[i];
            for (uint256 j; j < fp.selectors.length; j++) {
                bytes4 selector = fp.selectors[j];
                if (!fp.isView[j] || _containsKey(changed, bytes32(selector))) continue;
                if (IDiamondLoupe(p.diamond).facetAddress(selector) == address(0)) continue;

                string memory args =
                    _slice(fp.signatures[j], vm.indexOf(fp.signatures[j], "(") + 1, bytes(fp.signatures[j]).length - 1);
                if (_eq(args, "")) {
                    (calls[n], labels[n]) = (abi.encodePacked(selector), fp.signatures[j]);
                    n++;
                } else if (_eq(args, "address")) {
                    (calls[n], labels[n]) = (abi.encodeWithSelector(selector, owner), _label(fp.signatures[j], "owner"));
                    n++;
                } else if (_eq(args, "uint256") || _eq(args, "uint256,uint256") || _eq(args, "uint256,address")) {
                    for (uint256 id; id < ids; id++) {
                        string memory label = _label(fp.signatures[j], string.concat("id ", vm.toString(id)));
                        if (_eq(args, "uint256")) {
                            calls[n] = abi.encodeWithSelector(selector, id);
                        } else if (_eq(args, "uint256,uint256")) {
                            calls[n] = abi.encodeWithSelector(selector, id, PROBE_AMOUNT);
                        } else {
                            calls[n] = abi.encodeWithSelector(selector, id, owner);
                        }
                        labels[n++] = label;
                    }
                }
            }
        }
        assembly ("memory-safe") {
            mstore(calls, n)
            mstore(labels, n)
        }
    }

    function _results(address diamond, bytes[] memory calls) private view returns (bytes32[] memory results) {
        results = new bytes32[](calls.length);
        for (uint256 i; i < calls.length; i++) {
            (bool success, bytes memory output) = diamond.staticcall(calls[i]);
            results[i] = success ? keccak256(output) : REVERTED;
        }
    }

    /// @dev Classifies every slot whose value changed (first previous value vs final value) and reverts on the ones
    ///      outside the cut bookkeeping and the declared init writes.
    function _auditWrites(
        Plan memory p,
        Manifest memory m,
        VmSafe.AccountAccess[] memory accesses,
        address[] memory facetsBefore,
        Layout memory app
    ) private {
        bytes32[] memory allowed = _allowedRoots(m, app);
        bytes32[] memory arrays = _arrayBases(p, facetsBefore);

        uint256 total;
        for (uint256 i; i < accesses.length; i++) {
            total += accesses[i].storageAccesses.length;
        }
        address[] memory seenAccounts = new address[](total);
        bytes32[] memory seenSlots = new bytes32[](total);
        uint256 nSeen;

        for (uint256 i; i < accesses.length; i++) {
            VmSafe.StorageAccess[] memory sas = accesses[i].storageAccesses;
            for (uint256 j; j < sas.length; j++) {
                VmSafe.StorageAccess memory sa = sas[j];
                if (!sa.isWrite || sa.reverted || _seen(seenAccounts, seenSlots, nSeen, sa.account, sa.slot)) continue;
                (seenAccounts[nSeen], seenSlots[nSeen]) = (sa.account, sa.slot);
                nSeen++;

                // Net change only: a slot written then restored (reentrancy lock) is left untouched.
                if (vm.load(sa.account, sa.slot) == sa.previousValue) continue;

                if (sa.account != p.diamond) {
                    require(
                        _created(accesses, sa.account) || _containsAddress(m.externalWrites, sa.account),
                        string.concat(
                            "FactoryUpgrade: the upgrade writes the storage of ",
                            vm.toString(sa.account),
                            ", declare it in externalWrites"
                        )
                    );
                    continue;
                }

                bytes32 root = _root(p.diamond, sa.slot, arrays);
                require(
                    _containsKey(allowed, root),
                    string.concat(
                        "FactoryUpgrade: the upgrade writes undeclared storage ",
                        _rootLabel(root, app),
                        " (slot ",
                        vm.toString(sa.slot),
                        ")"
                    )
                );
            }
        }
    }

    /// @dev Slots the cut maintains (selector routing, facet selectors, facet list) plus the declared init writes.
    function _allowedRoots(Manifest memory m, Layout memory app) private pure returns (bytes32[] memory roots) {
        roots = new bytes32[](3 + m.initWrites.length);
        roots[0] = _diamondSlot(0);
        roots[1] = _diamondSlot(1);
        roots[2] = _diamondSlot(2);

        for (uint256 i; i < m.initWrites.length; i++) {
            string memory field = m.initWrites[i];
            if (_startsWith(field, "AppStorage.")) {
                roots[3 + i] = _appSlot(app, _slice(field, 11, bytes(field).length));
            } else if (_startsWith(field, "DiamondStorage.")) {
                roots[3 + i] = _diamondSlot(_diamondField(_slice(field, 15, bytes(field).length)));
            } else {
                revert(string.concat("FactoryUpgrade: unknown storage field in the manifest: ", field));
            }
        }
    }

    /// @dev (data slot, owning root) of the dynamic arrays of the diamond storage: the facet list and the selectors of
    ///      every facet live before or after the cut. Array elements are not recorded as mapping slots.
    function _arrayBases(Plan memory p, address[] memory facetsBefore) private view returns (bytes32[] memory bases) {
        address[] memory facetsAfter = IDiamondLoupe(p.diamond).facetAddresses();
        uint256 n = facetsBefore.length + facetsAfter.length + p.facets.length;

        bases = new bytes32[](2 * (n + 1));
        bases[0] = keccak256(abi.encode(_diamondSlot(2)));
        bases[1] = _diamondSlot(2);

        uint256 k = 2;
        for (uint256 i; i < n; i++) {
            address facet = i < facetsBefore.length
                ? facetsBefore[i]
                : i < facetsBefore.length + facetsAfter.length
                    ? facetsAfter[i - facetsBefore.length]
                    : p.facets[i - facetsBefore.length - facetsAfter.length].target;
            bases[k++] = keccak256(abi.encode(keccak256(abi.encode(facet, _diamondSlot(1)))));
            bases[k++] = _diamondSlot(1);
        }
    }

    /// @dev Top-level storage slot `slot` belongs to: walks up the recorded mapping slots (allowing struct member
    ///      offsets), then matches the known dynamic arrays.
    function _root(address diamond, bytes32 slot, bytes32[] memory arrays) private returns (bytes32) {
        for (uint256 depth; depth < 8; depth++) {
            bool found;
            for (uint256 offset; offset < MAX_STRUCT_SLOTS && offset <= uint256(slot); offset++) {
                bytes32 parent;
                (found,, parent) = vm.getMappingKeyAndParentOf(diamond, bytes32(uint256(slot) - offset));
                if (found) {
                    slot = parent;
                    break;
                }
            }
            if (!found) break;
        }

        for (uint256 i; i < arrays.length; i += 2) {
            if (uint256(slot) >= uint256(arrays[i]) && uint256(slot) - uint256(arrays[i]) < MAX_ARRAY_SLOTS) {
                return arrays[i + 1];
            }
        }
        return slot;
    }

    function _rootLabel(bytes32 root, Layout memory app) private pure returns (string memory) {
        uint256 diamondBase = uint256(LibDiamond.DIAMOND_STORAGE_POSITION);
        if (uint256(root) >= diamondBase && uint256(root) - diamondBase < 5) {
            return string.concat("DiamondStorage.", _diamondFieldName(uint256(root) - diamondBase));
        }

        uint256 appBase = uint256(LibAppStorage.APP_STORAGE_POSITION);
        if (uint256(root) >= appBase) {
            string memory label;
            for (uint256 i; i < app.slots.length; i++) {
                if (uint256(root) - appBase != app.slots[i]) continue;
                label = bytes(label).length == 0 ? app.labels[i] : string.concat(label, "|", app.labels[i]);
            }
            if (bytes(label).length != 0) return string.concat("AppStorage.", label);
        }
        return "outside AppStorage and DiamondStorage";
    }

    function _created(VmSafe.AccountAccess[] memory accesses, address account) private pure returns (bool) {
        for (uint256 i; i < accesses.length; i++) {
            if (accesses[i].kind == VmSafe.AccountAccessKind.Create && accesses[i].account == account) return true;
        }
        return false;
    }

    function _seen(address[] memory accounts, bytes32[] memory slots, uint256 n, address account, bytes32 slot)
        private
        pure
        returns (bool)
    {
        for (uint256 i; i < n; i++) {
            if (accounts[i] == account && slots[i] == slot) return true;
        }
        return false;
    }

    // ------------------------------------------------------------------------------------------------------------
    // Storage layouts
    // ------------------------------------------------------------------------------------------------------------

    /// @dev AppStorage members of the build, from the `StorageMirror` storage layout.
    function _appLayout() private view returns (Layout memory app) {
        string memory json = _artifact("src/utils/StorageMirror.sol", "StorageMirror");
        string memory typeKey = vm.parseJsonString(json, ".storageLayout.storage[0].type");
        string memory members = string.concat("$.storageLayout.types['", typeKey, "'].members[*]");

        app.labels = _strings(json, string.concat(members, ".label"));
        string[] memory slots = _strings(json, string.concat(members, ".slot"));
        app.slots = new uint256[](slots.length);
        for (uint256 i; i < slots.length; i++) {
            app.slots[i] = vm.parseUint(slots[i]);
        }
    }

    function _appSlot(Layout memory app, string memory label) private pure returns (bytes32) {
        for (uint256 i; i < app.labels.length; i++) {
            if (_eq(app.labels[i], label)) {
                return bytes32(uint256(LibAppStorage.APP_STORAGE_POSITION) + app.slots[i]);
            }
        }
        revert(string.concat("FactoryUpgrade: unknown storage field in the manifest: AppStorage.", label));
    }

    function _diamondSlot(uint256 index) private pure returns (bytes32) {
        return bytes32(uint256(LibDiamond.DIAMOND_STORAGE_POSITION) + index);
    }

    /// @dev Members of `LibDiamond.DiamondStorage`, in order (EIP-2535 reference layout).
    function _diamondFieldName(uint256 index) private pure returns (string memory) {
        if (index == 0) return "selectorToFacetAndPosition";
        if (index == 1) return "facetFunctionSelectors";
        if (index == 2) return "facetAddresses";
        if (index == 3) return "supportedInterfaces";
        return "contractOwner";
    }

    function _diamondField(string memory name) private pure returns (uint256) {
        for (uint256 i; i < 5; i++) {
            if (_eq(_diamondFieldName(i), name)) return i;
        }
        revert(string.concat("FactoryUpgrade: unknown storage field in the manifest: DiamondStorage.", name));
    }

    // ------------------------------------------------------------------------------------------------------------
    // Sets and strings
    // ------------------------------------------------------------------------------------------------------------

    /// @dev Reverts on the first element of `computed` missing from `declared`, then on the reverse.
    function _sameSet(
        string memory kind,
        bytes32[] memory computed,
        string[] memory computedLabels,
        bytes32[] memory declared,
        string[] memory declaredLabels
    ) private pure {
        for (uint256 i; i < computed.length; i++) {
            require(
                _containsKey(declared, computed[i]),
                string.concat(
                    "FactoryUpgrade: undeclared ", kind, " ", computedLabels[i], ", declare it in the manifest"
                )
            );
        }
        for (uint256 i; i < declared.length; i++) {
            require(
                _containsKey(computed, declared[i]),
                string.concat("FactoryUpgrade: declared ", kind, " ", declaredLabels[i], " is not in the diff")
            );
        }
    }

    function _selectorKeys(string[] memory signatures) private pure returns (bytes32[] memory keys) {
        keys = new bytes32[](signatures.length);
        for (uint256 i; i < signatures.length; i++) {
            keys[i] = bytes32(bytes4(keccak256(bytes(signatures[i]))));
        }
    }

    function _nameKeys(string[] memory names) private pure returns (bytes32[] memory keys) {
        keys = new bytes32[](names.length);
        for (uint256 i; i < names.length; i++) {
            keys[i] = keccak256(bytes(names[i]));
        }
    }

    function _selectorLabel(bytes4 selector, string[] memory signatures) private pure returns (string memory) {
        for (uint256 i; i < signatures.length; i++) {
            if (bytes4(keccak256(bytes(signatures[i]))) == selector) return signatures[i];
        }
        return vm.toString(abi.encodePacked(selector));
    }

    function _signatureOf(Plan memory p, Manifest memory m, bytes4 selector) private pure returns (string memory) {
        for (uint256 i; i < p.facets.length; i++) {
            for (uint256 j; j < p.facets[i].selectors.length; j++) {
                if (p.facets[i].selectors[j] == selector) return p.facets[i].signatures[j];
            }
        }
        return _selectorLabel(selector, m.removedFunctions);
    }

    function _label(string memory signature, string memory input) private pure returns (string memory) {
        return string.concat(signature, " [", input, "]");
    }

    function _shrink(bytes4[] memory array, uint256 n) private pure returns (bytes4[] memory) {
        assembly ("memory-safe") {
            mstore(array, n)
        }
        return array;
    }

    function _containsSelector(bytes4[] memory array, uint256 n, bytes4 value) private pure returns (bool) {
        for (uint256 i; i < n; i++) {
            if (array[i] == value) return true;
        }
        return false;
    }

    function _containsKey(bytes32[] memory array, bytes32 value) private pure returns (bool) {
        for (uint256 i; i < array.length; i++) {
            if (array[i] == value) return true;
        }
        return false;
    }

    function _containsAddress(address[] memory array, address value) private pure returns (bool) {
        for (uint256 i; i < array.length; i++) {
            if (array[i] == value) return true;
        }
        return false;
    }

    function _containsString(string[] memory array, string memory value) private pure returns (bool) {
        for (uint256 i; i < array.length; i++) {
            if (_eq(array[i], value)) return true;
        }
        return false;
    }

    function _eq(string memory a, string memory b) private pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }

    function _startsWith(string memory s, string memory prefix) private pure returns (bool) {
        return bytes(s).length >= bytes(prefix).length && _eq(_slice(s, 0, bytes(prefix).length), prefix);
    }

    function _endsWith(string memory s, string memory suffix) private pure returns (bool) {
        uint256 length = bytes(s).length;
        return length >= bytes(suffix).length && _eq(_slice(s, length - bytes(suffix).length, length), suffix);
    }

    function _basename(string memory path) private pure returns (string memory) {
        string[] memory parts = vm.split(path, "/");
        return parts[parts.length - 1];
    }

    function _slice(string memory s, uint256 start, uint256 end) private pure returns (string memory) {
        bytes memory result = new bytes(end - start);
        for (uint256 i; i < result.length; i++) {
            result[i] = bytes(s)[start + i];
        }
        return string(result);
    }
}
