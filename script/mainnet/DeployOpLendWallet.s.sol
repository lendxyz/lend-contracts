// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Script} from "forge-std/Script.sol";
import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Constants} from "script/common/Constants.s.sol";
import {OpLendWallet} from "src/OpLendWallet.sol";

contract DeployOpLendWallet is Script, Constants {
    function run() external {
        vm.startBroadcast();

        // Deploy the implementation contract
        OpLendWallet implementation = new OpLendWallet();

        // Prepare initializer data
        bytes memory initData = abi.encodeCall(OpLendWallet.initialize, (aymAddress, mnFactArgs.backendSigner));

        // Deploy the proxy and initialize
        ERC1967Proxy proxy = new ERC1967Proxy(address(implementation), initData);

        OpLendWallet(payable(proxy)).transferOwnership(Constants.multisigAddress);

        vm.stopBroadcast();
    }
}
