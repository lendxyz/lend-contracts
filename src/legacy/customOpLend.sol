// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract CustomOpLend is Ownable, ERC20 {
    uint256 public immutable MAX_SUPPLY;
    uint8 private immutable DECIMALS = 6;

    mapping(address => bool) public whitelisted;

    constructor(
        address initialOwner,
        string memory name,
        string memory symbol,
        uint256 maxSupply
    ) ERC20(name, symbol) Ownable(initialOwner) {
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

    function customBridge(uint256 amount) external {
        whitelisted[msg.sender] = true;
        _mint(msg.sender, amount);
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
}
