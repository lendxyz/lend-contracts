// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import "forge-std/console.sol";

import {TestBase} from "./TestBase.t.sol";

contract RewardsTest is TestBase {
    function beforeTestSetup() public pure returns (bytes[] memory beforeTestCalldata) {
        beforeTestCalldata = new bytes[](2);
        beforeTestCalldata[0] = abi.encodePacked(this.setupContracts.selector);
        beforeTestCalldata[1] = abi.encodePacked(this.mintUsdc.selector);
    }
}
