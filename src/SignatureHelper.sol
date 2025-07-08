// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

abstract contract SignatureHelper {
    address internal backendSigner;

    mapping(uint256 => mapping(address => uint256)) mintAllowance;
    mapping(string => bool) usedNonces;

    constructor(address _backendSigner) {
        backendSigner = _backendSigner;
    }

    function verifySignatureMint(
        address _user,
        uint256 _amount,
        uint256 _opId,
        string calldata _nonce,
        bytes memory _signature
    ) internal returns (bool) {
        if (usedNonces[_nonce]) {
            return false;
        }

        bytes32 messageHash = keccak256(abi.encodePacked(_opId, _user, _amount, _nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        address recovered = ecrecover(ethSignedMessageHash, v, r, s);
        bool isValid = recovered == backendSigner;

        if (isValid) {
            usedNonces[_nonce] = true;
            mintAllowance[_opId][_user] += _amount;
        }

        return isValid;
    }

    function splitSignature(bytes memory sig) private pure returns (bytes32 r, bytes32 s, uint8 v) {
        require(sig.length == 65, "invalid signature length");

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function verifySignatureTransfer(address _user, string calldata _nonce, bytes memory _signature)
        internal
        returns (bool)
    {
        if (usedNonces[_nonce]) {
            return false;
        }

        bytes32 messageHash = keccak256(abi.encodePacked(_user, _nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(_signature);
        address recovered = ecrecover(ethSignedMessageHash, v, r, s);
        bool isValid = recovered == backendSigner;

        if (isValid) {
            usedNonces[_nonce] = true;
        }

        return isValid;
    }
}
