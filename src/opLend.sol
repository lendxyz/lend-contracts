// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IOFT, OFTCore} from "@layerzerolabs/oft-evm/contracts/OFTCore.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {SignatureHelper} from "./SignatureHelper.sol";

contract LendOperation is Ownable, SignatureHelper, ERC20, OFTCore {
    uint256 public immutable MAX_SUPPLY;
    uint8 private immutable DECIMALS = 6;

    mapping(address => bool) public whitelisted;

    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        uint256 maxSupply,
        address lzEndpoint,
        address lzDelegate,
        address backendSigner
    )
        OFTCore(DECIMALS, lzEndpoint, lzDelegate)
        SignatureHelper(backendSigner)
        ERC20(name, symbol)
        Ownable(initialOwner)
    {
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

    function whitelistUser(address user, string calldata nonce, bytes memory signature) public {
        bool isSignatureValid = verifySignatureTransfer(user, nonce, signature);
        require(isSignatureValid, "Invalid signature");
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
     * @param _amountLD The amount of tokens to send in local decimals.
     * @param _minAmountLD The minimum amount to send in local decimals.
     * @param _dstEid The destination chain ID.
     * @return amountSentLD The amount sent in local decimals.
     * @return amountReceivedLD The amount received in local decimals on the remote.
     */
    function _debit(address _from, uint256 _amountLD, uint256 _minAmountLD, uint32 _dstEid)
        internal
        virtual
        override
        returns (uint256 amountSentLD, uint256 amountReceivedLD)
    {
        require(whitelisted[_from] == true, "User is not whitelisted");
        (amountSentLD, amountReceivedLD) = _debitView(_amountLD, _minAmountLD, _dstEid);

        // @dev In NON-default OFT, amountSentLD could be 100, with a 10% fee, the amountReceivedLD amount is 90,
        // therefore amountSentLD CAN differ from amountReceivedLD.

        // @dev Default OFT burns on src.
        _burn(_from, amountSentLD);
    }

    /**
     * @dev Credits tokens to the specified address.
     * @param _to The address to credit the tokens to.
     * @param _amountLD The amount of tokens to credit in local decimals.
     * @dev _srcEid The source chain ID.
     * @return amountReceivedLD The amount of tokens ACTUALLY received in local decimals.
     */
    function _credit(address _to, uint256 _amountLD, uint32 /*_srcEid*/ )
        internal
        virtual
        override
        returns (uint256 amountReceivedLD)
    {
        if (_to == address(0x0)) _to = address(0xdead); // _mint(...) does not support address(0x0)
        whitelisted[_to] = true;
        // @dev Default OFT mints on dst.
        _mint(_to, _amountLD);
        // @dev In the case of NON-default OFT, the _amountLD MIGHT not be == amountReceivedLD.
        return _amountLD;
    }

    function sharedDecimals() public pure override returns (uint8) {
        return DECIMALS;
    }
}
