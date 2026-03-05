// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {LibAppStorage} from "../../src/Factory/lib/Storage.sol";
import {TestBase} from "../TestBase.t.sol";

contract FactoryStorageTest is Test, TestBase {
    function test_StorageNamespaceIntegrity() public pure {
        bytes32 expectedHash = keccak256("lend.factory.appstorage");

        assertEq(LibAppStorage.APP_STORAGE_POSITION, expectedHash, "Incorrect namespace Hash");
    }

    function test_NoStorageShiftsLibAppStorage() public {
        string[] memory inputs = new string[](4);
        inputs[0] = "./test/check-storage.sh";
        inputs[1] = "src/utils/StorageMirrorLegacy.sol:StorageMirrorLegacy";
        inputs[2] = "src/utils/StorageMirror.sol:StorageMirror";
        inputs[3] = "AppStorage";

        string memory res = string(vm.ffi(inputs));
        assertEq(res, "OK", res);
    }
}
