// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC1363} from "@openzeppelin/contracts/token/ERC20/extensions/ERC1363.sol";
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {ERC20Burnable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import {ERC20Pausable} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Pausable.sol";
import {ERC20Permit} from "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LendOperation is ERC20, ERC20Burnable, ERC20Pausable, Ownable, ERC1363, ERC20Permit {
    uint256 public immutable MAX_SUPPLY;

    constructor(address initialOwner, string memory name, string memory symbol, uint256 maxSupply)
        ERC20(name, symbol)
        Ownable(initialOwner)
        ERC20Permit(name)
    {
        MAX_SUPPLY = maxSupply;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address to, uint256 amount) public onlyOwner {
        require(totalSupply() + amount <= MAX_SUPPLY, "Total supply cap exceeded");
        _mint(to, amount);
    }

    function decimals() public view virtual override returns (uint8) { 
        return 18;
    }

    // The following function is an override required by Solidity.
    function _update(address from, address to, uint256 value)
        internal
        override(ERC20, ERC20Pausable)
    {
        super._update(from, to, value);
    }
}
