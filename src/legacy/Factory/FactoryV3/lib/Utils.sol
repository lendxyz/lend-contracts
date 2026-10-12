// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {Events} from "./Events.sol";

library Utils {
    function getEurUsdOraclePrice(address oracle) public view returns (uint256 eurUsd) {
        (uint80 roundId, int256 eurUsdRaw,, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(oracle).latestRoundData();

        require(eurUsdRaw > 0, "Oracle: non-positive price");
        require(answeredInRound >= roundId, "Oracle: stale round");
        require(updatedAt != 0, "Oracle: incomplete round");
        require(block.timestamp - updatedAt <= 25 hours, "Oracle: stale price");

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

    function computeEthSignedHash(bytes32 messageHash) internal pure returns (bytes32 signedHash) {
        return keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
    }

    function splitSignature(bytes memory sig) internal pure returns (bytes32 r, bytes32 s, uint8 v) {
        if (sig.length != 65) revert Events.InvalidSignatureLength();
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
