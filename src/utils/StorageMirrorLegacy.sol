// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {AppStorage} from "../legacy/Factory/FactoryV1/lib/Storage.sol";

// This contract is never deployed.
// Its only purpose is to force the compiler to generate a storage layout.
contract StorageMirrorLegacy {
    AppStorage s;
}
