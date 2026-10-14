// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {LibDiamond} from "src/Factory/lib/LibDiamond.sol";
import {IERC173} from "src/Factory/interfaces/IERC173.sol";

contract Ownership is IERC173 {
    function transferOwnership(address _newOwner) external {
        LibDiamond.enforceIsContractOwner();
        LibDiamond.setContractOwner(_newOwner);
    }

    function owner() external view returns (address owner_) {
        owner_ = LibDiamond.diamondStorage().contractOwner;
    }
}
