// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {LendOperation} from "./opLend.sol";

// TODO: deploy and manage opLend on other chains than Ethereum
contract OFTManager is Ownable {
    constructor(address _admin, address _token) Ownable(_admin) {}

    fallback() external payable {}
    receive() external payable {}
}
