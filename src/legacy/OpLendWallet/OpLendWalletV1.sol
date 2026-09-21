// SPDX-License-Identifier: MIT
pragma solidity 0.8.30;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {AggregatorV3Interface} from "@chainlink/contracts/src/v0.8/shared/interfaces/AggregatorV3Interface.sol";
import {LendOperation} from "../../opLend.sol";

contract OpLendWalletV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    address internal backendSigner;

    error InvalidSignature();

    event Redeemed(uint256 indexed opId, address indexed user, uint256 opLendAmount);
    event AdminRedeemed(uint256 indexed opId, address indexed user, uint256 opLendAmount);

    mapping(string => bool) private usedNonces;
    mapping(address => uint256) private addressToOpId;
    mapping(uint256 => address) private opIdToAddress;

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
        require(opLend.code.length > 0, "Provided address is not a contract");

        addressToOpId[opLend] = opId;
        opIdToAddress[opId] = opLend;
    }

    function registerOpLendAddresses(uint256[] calldata opIds, address[] calldata opLends) public onlyOwner {
        require(opIds.length == opLends.length, "Length missmatch");

        for (uint256 i = 0; i < opIds.length; i++) {
            addressToOpId[opLends[i]] = opIds[i];
        }
    }

    function adminRedeem(uint256 opId, address destination, uint256 amount) public onlyOwner {
        require(opIdToAddress[opId] != address(0), "Invalid opId");
        LendOperation opLend = LendOperation(opIdToAddress[opId]);

        uint256 balance = opLend.balanceOf(address(this));
        require(balance >= amount, "Not enough opLend");
        require(opLend.transfer(destination, amount), "Failed to transfer opLend");

        emit AdminRedeemed(opId, destination, amount);
    }

    /**
     * Redeem functions ***
     */
    function _redeem(
        uint256 opId,
        address destination,
        uint256 amount,
        string memory rNonce,
        bytes memory rSignature,
        string memory tNonce,
        bytes memory tSignature,
        bool shouldWl
    ) private {
        require(opIdToAddress[opId] != address(0), "Invalid opId");
        LendOperation opLend = LendOperation(opIdToAddress[opId]);

        uint256 balance = opLend.balanceOf(address(this));
        require(balance >= amount, "Not enough opLend");
        require(verifySignature(opId, destination, amount, rNonce, rSignature));

        if (shouldWl) {
            opLend.whitelistUser(destination, tNonce, tSignature);
        }

        require(opLend.transfer(destination, amount), "Failed to transfer opLend");

        emit Redeemed(opId, destination, amount);
    }

    function redeem(uint256 opId, address destination, uint256 amount, string calldata nonce, bytes memory signature)
        public
    {
        return _redeem(opId, destination, amount, nonce, signature, "", new bytes(0), false);
    }

    function whitelistAndRedeem(
        uint256 opId,
        address destination,
        uint256 amount,
        string calldata tNonce,
        bytes memory tSignature,
        string calldata rNonce,
        bytes memory rSignature
    ) public {
        return _redeem(opId, destination, amount, rNonce, rSignature, tNonce, tSignature, true);
    }

    /**
     * Signature verification functions ***
     */
    function verifySignature(
        uint256 opId,
        address destination,
        uint256 amount,
        string memory nonce,
        bytes memory signature
    ) internal returns (bool) {
        if (usedNonces[nonce]) {
            return false;
        }

        bytes32 messageHash = keccak256(abi.encodePacked("OP_REDEEM", opId, block.chainid, destination, amount, nonce));
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
