// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

library LendUtils {
    error InvalidSignatureLength();

    function getEURUSDOraclePrice(address oracle) public view returns (uint256 eurUsd) {
        (, int256 eurUsdRaw,,,) = AggregatorV3Interface(oracle).latestRoundData();
        uint8 oracleDecimals = AggregatorV3Interface(oracle).decimals();
        int256 scaled = eurUsdRaw;
        if (oracleDecimals < 6) {
            scaled *= int256(10 ** uint256(6 - oracleDecimals));
        } else if (oracleDecimals > 6) {
            scaled /= int256(10 ** uint256(oracleDecimals - 6));
        }
        eurUsd = uint256(scaled);
    }

    function uintToString(uint256 value) internal pure returns (string memory) {
        if (value == 0) return "0";

        uint256 temp = value;
        uint256 digits;

        while (temp != 0) {
            digits++;
            temp /= 10;
        }

        bytes memory buffer = new bytes(digits);

        while (value != 0) {
            digits -= 1;
            buffer[digits] = bytes1(uint8(48 + uint256(value % 10)));
            value /= 10;
        }

        return string(buffer);
    }

    function computeEthSignedHash(bytes32 messageHash) internal pure returns (bytes32) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (sig.length != 65) revert InvalidSignatureLength();
        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }
    }

    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory signature) internal pure returns (address) {
        (bytes32 r, bytes32 s, uint8 v) = splitSignature(signature);
        return ecrecover(ethSignedMessageHash, v, r, s);
    }
}
