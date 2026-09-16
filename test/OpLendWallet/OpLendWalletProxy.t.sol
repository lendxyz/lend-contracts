// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {Options, Upgrades} from "@openzeppelin/foundry-upgrades/Upgrades.sol";
import {OpLendWalletTest} from "./OpLendWallet.t.sol";

contract OpLendWalletProxyTest is Test, OpLendWalletTest {
    function test_UpgradeProxy() public {
        Options memory opts;
        Upgrades.validateUpgrade("OpLendWallet.sol:OpLendWallet", opts);
    }
}
