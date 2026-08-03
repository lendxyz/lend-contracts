// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {Script, console} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Constants} from "../common/Constants.s.sol";
import {LendRestitution} from "../../src/Restitution.sol";
import {USDC} from "../../src/testnet/DummyUSDC.sol";

contract DeployRestitutionTestnet is Script, Constants {
    function setUp() public {}

    function run() public {
        vm.createSelectFork("sepolia");
        vm.startBroadcast();

        address usdcAddress = getTestnetUsdcAddress();

        // Deploy the implementation contract
        LendRestitution implementation = new LendRestitution();

        // Prepare initializer data
        bytes memory initData = abi.encodeCall(LendRestitution.initialize, (tnOwner, usdcAddress));

        // Deploy the proxy and initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        USDC usdc = USDC(usdcAddress);
        usdc.approve(address(proxy), type(uint256).max);

        // DEMO RESTITUTION:
        // Mint mock usdc:
        // LendRestitution restitution = LendRestitution(payable(address(proxy)));
        // usdc.mint(tnOwner, 1_000_000e6);
        //
        // Args: opId - opLend token address - USDC amount
        // restitution.restituteFunds(1, 0x0000000000000000000000000000000000000000, 1_000_000e6);

        vm.stopBroadcast();

        console.log("Restitution implementation:", address(implementation));
        console.log("Restitution proxy:", address(proxy));
    }
}
