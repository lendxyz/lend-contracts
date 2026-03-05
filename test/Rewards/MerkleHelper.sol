// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {CompleteMerkle} from "murky/CompleteMerkle.sol";

contract MerkleHelper {
    CompleteMerkle m = new CompleteMerkle();

    function _generateLeaf(address user, uint256 balance) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked(user, balance));
    }

    function getRoot(address[] memory users, uint256[] memory balances) public view returns (bytes32) {
        bytes32[] memory leaves = new bytes32[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            leaves[i] = _generateLeaf(users[i], balances[i]);
        }
        return m.getRoot(leaves);
    }

    function getProof(address[] memory users, uint256[] memory balances, uint256 index)
        public
        view
        returns (bytes32[] memory)
    {
        bytes32[] memory leaves = new bytes32[](users.length);
        for (uint256 i = 0; i < users.length; i++) {
            leaves[i] = _generateLeaf(users[i], balances[i]);
        }
        return m.getProof(leaves, index);
    }
}
