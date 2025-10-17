// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IOFT, OFTCore} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LendOperation is Ownable, ERC20, OFTCore {
    uint256 public immutable MAX_SUPPLY;
    uint8 private immutable DECIMALS = 6;
    address internal backendSigner;

    mapping(string => bool) usedNonces;
    mapping(address => bool) public whitelisted;

    error InvalidSignature();
    error InvalidSignatureLength();

    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address lzEndpoint,
        address lzDelegate,
        address signer
    ) OFTCore(DECIMALS, lzEndpoint, lzDelegate) ERC20(name, symbol) Ownable(initialOwner) {
        backendSigner = signer;
        MAX_SUPPLY = maxSupply;
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Total supply cap exceeded");
        whitelisted[to] = true;
        _mint(to, amount);
    }

    function decimals() public pure virtual override returns (uint8) {
        return DECIMALS;
    }

    function adminBurn(address user, uint256 value) public onlyOwner {
        _burn(user, value);
    }

    // TODO: testing
    function whitelistUser(address user, string calldata nonce, bytes memory signature) public {
        bool isSignatureValid = verifySignature(user, nonce, signature);
        if (!isSignatureValid) revert InvalidSignature();
        whitelisted[user] = true;
    }

    function verifySignature(address _user, string calldata _nonce, bytes memory _signature) internal returns (bool) {
        if (usedNonces[_nonce]) {
            return false;
        }

        bytes32 messageHash = keccak256(abi.encodePacked(_user, _nonce));
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

    /**
     * LZ functions ***
     */

    /**
     * @dev Retrieves the address of the underlying ERC20 implementation.
     * @return The address of the OFT token.
     *
     * @dev In the case of OFT, address(this) and erc20 are the same contract.
     */
    function token() public view returns (address) {
        return address(this);
    }

    /**
     * @notice Indicates whether the OFT contract requires approval of the 'token()' to send.
     * @return requiresApproval Needs approval of the underlying token implementation.
     *
     * @dev In the case of OFT where the contract IS the token, approval is NOT required.
     */
    function approvalRequired() external pure virtual returns (bool) {
        return false;
    }

    /**
     * @dev Burns tokens from the sender's specified balance.
     * @param _from The address to debit the tokens from.
     * @param _amountLd The amount of tokens to send in local decimals.
     * @param _minAmountLd The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLd The amount sent in local decimals.
     * @return amountReceivedLd The amount received in local decimals on the remote.
     */
    function _debit(address _from, uint256 _amountLd, uint256 _minAmountLd, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLd, uint256 amountReceivedLd)
    {
        require(whitelisted[_from] == true, "User is not whitelisted");
        (amountSentLd, amountReceivedLd) = _debitView(_amountLd, _minAmountLd, _dstEid);

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        _burn(_from, amountSentLd);
    }

    /**
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLd The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLd The amount of tokens ACTUALLY received in local decimals.
     */
    function _credit(address _to, uint256 _amountLd, uint32 /*_srcEid*/ )
        internal
        virtual
        override
        returns (uint256 amountReceivedLd)
    {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        whitelisted[_to] = true;
        // @dev Default OFT mints on dst.
        _mint(_to, _amountLd);
        // @dev In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
        return _amountLd;
    }

    function sharedDecimals() public pure override returns (uint8) {
        return DECIMALS;
    }

    function batchSetPeers(uint32[] calldata _eids, bytes32[] calldata _peers) external onlyOwner {
        require(_eids.length == _peers.length, "Length mismatch");
        for (uint256 i = 0; i < _eids.length; i++) {
            setPeer(_eids[i], _peers[i]);
        }
    }
}
