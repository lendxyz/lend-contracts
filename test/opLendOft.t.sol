// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.22;

import "forge-std/console.sol";

import {Packet} from "@layerzerolabs/lz-evm-protocol-v2/contracts/interfaces/ISendLib.sol";
import {OptionsBuilder} from "@layerzerolabs/oapp-evm/contracts/oapp/libs/OptionsBuilder.sol";
import {MessagingFee} from "@layerzerolabs/oapp-evm/contracts/oapp/OApp.sol";
import {MessagingReceipt} from "@layerzerolabs/oapp-evm/contracts/oapp/OAppSender.sol";
import {TestHelperOz5} from "@layerzerolabs/test-devtools-evm-foundry/contracts/TestHelperOz5.sol";

import {LendOperation} from "../src/opLend.sol";
import {TestBase} from "./TestBase.sol";

/// @notice Unit test for LendOperation using the TestHelper.
/// @dev Inherits from TestHelper to utilize its setup and utility functions.
contract OpLendOftTest is TestHelperOz5, TestBase {
    using OptionsBuilder for bytes;

    // Declaration of mock endpoint IDs.
    uint16 aEid = 1;
    uint16 bEid = 2;

    // Declaration of mock contracts.
    LendOperation opLend_a; // OApp A
    LendOperation opLend_b; // OApp B

    function beforeTestSetup() public pure returns (bytes[] memory beforeTestCalldata) {
        beforeTestCalldata = new bytes[](4);
        beforeTestCalldata[0] = abi.encodePacked(this.mintUSDC.selector);
        beforeTestCalldata[1] = abi.encodePacked(this.setupContracts.selector);
        beforeTestCalldata[2] = abi.encodePacked(this.createOperation.selector);
        beforeTestCalldata[3] = abi.encodePacked(this.setupLzEndpoints.selector);
    }

    /// @notice Calls setUp from TestHelper and initializes contract instances for testing.
    function setupLzEndpoints() public {
        // Setup function to initialize 2 Mock Endpoints with Mock MessageLib.
        setUpEndpoints(2, LibraryType.UltraLightNode);

        // Initializes 2 opLEND OFT; one on chain A, one on chain B.
        address[] memory sender = setupOApps(type(LendOperation).creationCode, 1, 2);
        opLend_a = LendOperation(payable(sender[0]));
        opLend_b = LendOperation(payable(sender[1]));
    }

    function setUp() public override(TestBase, TestHelperOz5) {
        super.setUp();
    }

    // TODO: test multichain transfer here
    function test_TransferOFT() public {}
}
