// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Utils} from "./Utils.sol";

// TODO: adapt to use state from libAppStorage
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
        bytes32 ethSignedMessageHash = Utils.computeEthSignedHash(messageHash);
        address recovered = Utils.recoverSigner(ethSignedMessageHash, _signature);
        bool isValid = recovered == backendSigner;

        if (isValid) {
            usedNonces[_nonce] = true;
            mintAllowance[_opId][_user] += _amount;
        }

        return isValid;
    }

    function verifySignatureTransfer(address _user, string calldata _nonce, bytes memory _signature)
        internal
        returns (bool)
    {
        if (usedNonces[_nonce]) {
            return false;
        }

        bytes32 messageHash = keccak256(abi.encodePacked(_user, _nonce));
        bytes32 ethSignedMessageHash = Utils.computeEthSignedHash(messageHash);
        address recovered = Utils.recoverSigner(ethSignedMessageHash, _signature);
        bool isValid = recovered == backendSigner;

        if (isValid) {
            usedNonces[_nonce] = true;
        }

        return isValid;
    }
}
