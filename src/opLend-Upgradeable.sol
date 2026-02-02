// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {
    SendParam, MessagingFee, MessagingReceipt, OFTReceipt
} from "@layerzerolabs/oft-evm/contracts/interfaces/IOFT.sol";
import {ERC20Upgradeable} from "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import {OFTCoreUpgradeable} from "@layerzerolabs/oft-evm-upgradeable/contracts/oft/OFTCoreUpgradeable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import {UUPSUpgradeable} from "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";

// TODO: integrate the new pattern in factory for deploy and upgrade

contract LendOperationUpgradeable is
    Initializable,
    OwnableUpgradeable,
    ERC20Upgradeable,
    OFTCoreUpgradeable,
    UUPSUpgradeable
{
    uint256 public MAX_SUPPLY;
    uint8 private _decimals;
    address internal backendSigner;

    mapping(string => bool) private usedNonces;
    mapping(address => bool) public whitelisted;

    error InvalidSignature();
    error InvalidSignatureLength();

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(
        address initialOwner,
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address lzEndpoint,
        address lzDelegate,
        address signer
    ) public initializer {
        __Ownable_init(initialOwner);
        __ERC20_init(name, symbol);
        __OFTCore_init(6, lzEndpoint, lzDelegate); // Hardcoded 6 decimals as per original
        __UUPSUpgradeable_init();

        _decimals = 6;
        backendSigner = signer;
        MAX_SUPPLY = maxSupply;
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Total supply cap exceeded");
        whitelisted[to] = true;
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) {
        return _decimals;
    }

    function adminBurn(address user, uint256 value) public onlyOwner {
        _burn(user, value);
    }

    function updateBackendSigner(address newSigner) public onlyOwner {
        backendSigner = newSigner;
    }

    function whitelistUser(address user, string calldata nonce, bytes memory signature) public {
        bool isSignatureValid = verifySignature(user, nonce, signature);
        if (!isSignatureValid) revert InvalidSignature();
        whitelisted[user] = true;
    }

    function whitelistUserAdmin(address user, bool state) public onlyOwner {
        whitelisted[user] = state;
    }

    function verifySignature(address _user, string calldata _nonce, bytes memory _signature) internal returns (bool) {
        if (usedNonces[_nonce]) return false;

        bytes32 messageHash = keccak256(abi.encodePacked(block.chainid, _user, _nonce));
        bytes32 ethSignedMessageHash = computeEthSignedHash(messageHash);
        address recovered = recoverSigner(ethSignedMessageHash, _signature);

        bool isValid = recovered == backendSigner;
        if (isValid) {
            usedNonces[_nonce] = true;
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

    function transfer(address to, uint256 value) public override returns (bool) {
        address owner = _msgSender();
        require(whitelisted[owner] == true, "Source address is not whitelisted");
        require(whitelisted[to] == true, "Destination address is not whitelisted");
        _transfer(owner, to, value);
        return true;
    }

    function transferFrom(address from, address to, uint256 value) public override returns (bool) {
        require(whitelisted[from] == true, "Source address is not whitelisted");
        require(whitelisted[to] == true, "Destination address is not whitelisted");
        address spender = _msgSender();
        _spendAllowance(from, spender, value);
        _transfer(from, to, value);
        return true;
    }

    function token() public view returns (address) {
        return address(this);
    }

    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    function send(SendParam calldata _sendParam, MessagingFee calldata _fee, address _refundAddress)
        external
        payable
        override
        returns (MessagingReceipt memory msgReceipt, OFTReceipt memory oftReceipt)
    {
        address to = address(uint160(uint256(_sendParam.to)));
        require(whitelisted[to], "Destination user is not whitelisted");
        return _send(_sendParam, _fee, _refundAddress);
    }

    function _debit(address _from, uint256 _amountLd, uint256 _minAmountLd, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLd, uint256 amountReceivedLd)
    {
        require(whitelisted[_from] == true, "User is not whitelisted");
        (amountSentLd, amountReceivedLd) = _debitView(_amountLd, _minAmountLd, _dstEid);
        _burn(_from, amountSentLd);
    }

    function _credit(address _to, uint256 _amountLd, uint32 /*_srcEid*/ )
        internal
        virtual
        override
        returns (uint256 amountReceivedLd)
    {
        if (_to == address(0x0)) _to = address(0xdead);
        whitelisted[_to] = true;
        _mint(_to, _amountLd);
        return _amountLd;
    }

    function sharedDecimals() public pure override returns (uint8) {
        return 6;
    }

    function batchSetPeers(uint32[] calldata _eids, bytes32[] calldata _peers) external onlyOwner {
        require(_eids.length == _peers.length, "Length mismatch");
        for (uint256 i = 0; i < _eids.length; i++) {
            setPeer(_eids[i], _peers[i]);
        }
    }
}
