// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";

// TODO: add Upgrade path decorator and legacy code snapshot when deployed
contract OpLendWallet is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address internal backendSigner;

    error InvalidSignature();

    mapping(string => bool) private usedNonces;
    mapping(address => uint256) private addressToOpId;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address signer) public initializer {
        __Ownable_init(admin);
        __UUPSUpgradeable_init();

        backendSigner = signer;
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

    function registerOpLendAddress(uint256 opId, address opLend) public onlyOwner {
        addressToOpId[opLend] = opId;
    }

    function registerOpLendAddresses(uint256[] calldata opIds, address[] calldata opLends) public onlyOwner {
        require(opIds.length == opLends.length, "Length missmatch");

        for (uint256 i = 0; i < opIds.length; i++) {
            addressToOpId[opLends[i]] = opIds[i];
        }
    }

    // TODO
    // adminRedeem -> enable admin to redeem arbitrary balance (multisig only; can select destination)

    /**
     * Custody functions ***
     */

    // TODO
    // redeem -> enables user to redeem their managed balance (works with backend signature; emits `Redeemed` event)

    /**
     * Signature verification functions ***
     */
    function verifySignature(
        uint256 opId,
        address user,
        address destination,
        uint256 amount,
        string calldata nonce,
        bytes memory signature
    ) internal returns (bool) {
        if (usedNonces[nonce]) {
            return false;
        }

        bytes32 messageHash = keccak256(abi.encodePacked(opId, block.chainid, user, destination, amount, nonce));
        bytes32 ethSignedMessageHash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", messageHash));
        address recovered = recoverSigner(ethSignedMessageHash, signature);
        bool isValid = recovered == backendSigner;

        if (isValid) {
            usedNonces[nonce] = true;
        }

        return isValid;
    }

    function recoverSigner(bytes32 ethSignedMessageHash, bytes memory sig) internal pure returns (address) {
        if (sig.length != 65) revert InvalidSignature();

        bytes32 r;
        bytes32 s;
        uint8 v;

        assembly {
            r := mload(add(sig, 32))
            s := mload(add(sig, 64))
            v := byte(0, mload(add(sig, 96)))
        }

        return ecrecover(ethSignedMessageHash, v, r, s);
    }
}
