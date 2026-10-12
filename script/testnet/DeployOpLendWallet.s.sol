// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Constants} from "script/common/Constants.s.sol";
import {OpLendWallet} from "src/OpLendWallet.sol";
import {USDC} from "src/testnet/DummyUSDC.sol";

contract DeployOpLendWalletTestnet is Script, Constants {
    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        // Deploy the implementation contract
        OpLendWallet implementation = new OpLendWallet();

        // Prepare initializer data
        bytes memory initData = abi.encodeCall(OpLendWallet.initialize, (tnOwner, tnFactArgs.backendSigner));

        // Deploy the proxy and initialize
        new ERC1967Proxy(address(implementation), initData);

        vm.stopBroadcast();
    }
}
