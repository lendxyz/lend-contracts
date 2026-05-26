// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

/// @custom:oz-upgrades-from src/legacy/Oracle/PriceOracleV1.sol:PriceOracleV1
contract PriceOracle is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    struct Price {
        uint256 lastRound;
        uint256 opId;
        uint256 priceEur;
        uint256 priceUsd;
    }

    struct PriceStorage {
        uint256 lastRound;
        uint256 price;
    }

    event PriceUpdated(uint256 indexed opId, uint256 newPrice);

    error InvalidSignature();
    error InvalidSignatureLength();

    address internal backendSigner;
    address internal eurUsdOracle;

    mapping(string => bool) private usedNonces;
    mapping(uint256 => mapping(address => uint256)) private addressToOpId;
    mapping(uint256 => PriceStorage) private opIdToPrice;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address signer, address oracle) public initializer {
        __Ownable_init(admin);
        __UUPSUpgradeable_init();

        backendSigner = signer;
        eurUsdOracle = oracle;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    fallback() external payable {}
    receive() external payable {}

    /**
     * Admin functions ***
     */
    function setBackendSigner(address signer) public onlyOwner {
        require(signer != address(0), "Signer cannot be zero address");
        backendSigner = signer;
    }

    function setEurUsdOracle(address oracle) public onlyOwner {
        require(oracle != address(0), "Oracle cannot be zero address");
        eurUsdOracle = oracle;
    }

    /**
     * Oracle functions ***
     */
    function convertEurToUsd(uint256 eurAmount) internal view returns (uint256) {
        (uint80 roundId, int256 eurUsdRaw,, uint256 updatedAt, uint80 answeredInRound) =
            AggregatorV3Interface(eurUsdOracle).latestRoundData();

        require(eurUsdRaw > 0, "Oracle: non-positive price");
        require(answeredInRound >= roundId, "Oracle: stale round");
        require(updatedAt != 0, "Oracle: incomplete round");
        require(block.timestamp - updatedAt <= 25 hours, "Oracle: stale price");

        uint8 oracleDecimals = AggregatorV3Interface(eurUsdOracle).decimals();
        int256 scaled = eurUsdRaw;

        if (oracleDecimals < 6) {
            scaled *= int256(10 ** uint256(6 - oracleDecimals));
        } else if (oracleDecimals > 6) {
            scaled /= int256(10 ** uint256(oracleDecimals - 6));
        }

        return eurAmount * uint256(scaled) / 1e6;
    }

    function getLastRound(uint256 chainId, address opLend) public view returns (Price memory) {
        uint256 opId = addressToOpId[chainId][opLend];

        return
            Price(opIdToPrice[opId].lastRound, opId, opIdToPrice[opId].price, convertEurToUsd(opIdToPrice[opId].price));
    }

    function getLastRoundEurOnly(uint256 chainId, address opLend) public view returns (PriceStorage memory) {
        return opIdToPrice[addressToOpId[chainId][opLend]];
    }

    function publishNewRound(uint256 opId, uint256 newPrice, string calldata nonce, bytes memory signature) public {
        bool isSignatureValid = verifySignature(opId, newPrice, nonce, signature);
        if (!isSignatureValid) revert InvalidSignature();

        opIdToPrice[opId] = PriceStorage(block.timestamp, newPrice);

        emit PriceUpdated(opId, newPrice);
    }

    /**
     * Signature verification functions ***
     */
    function verifySignature(uint256 opId, uint256 newPrice, string calldata nonce, bytes memory signature)
        internal
        returns (bool)
    {
        if (usedNonces[nonce]) {
            return false;
        }

        bytes32 messageHash = keccak256(abi.encodePacked(opId, newPrice, nonce));
        bytes32 ethSignedMessageHash = computeEthSignedHash(messageHash);
        address recovered = recoverSigner(ethSignedMessageHash, signature);
        bool isValid = recovered == backendSigner;

        if (isValid) {
            usedNonces[nonce] = true;
        }

        return isValid;
    }

    function computeEthSignedHash(bytes32 messageHash) internal pure returns (bytes32 signedHash) {
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
