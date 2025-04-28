// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Pausable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

contract LendDebt is ERC1155, Ownable, ERC1155Pausable, ERC1155Burnable, ERC1155Supply {
    mapping(uint256 => uint256) maxSupplyForId;

    constructor()
        ERC1155("https://cdn.lend.xyz/token/{id}.json")
        Ownable(msg.sender)
    {}

    function setURI(string memory newuri) public onlyOwner {
        _setURI(newuri);
    }

    function setMaxSupply(uint256 id, uint256 maxSupply) public onlyOwner {
        maxSupplyForId[id] = maxSupply;
    }

    function pause() public onlyOwner {
        _pause();
    }

    function unpause() public onlyOwner {
        _unpause();
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data)
        public
        onlyOwner
    {
        require(totalSupply(id) + amount <= maxSupplyForId[id], "Total supply cap exceeded");
        _mint(account, id, amount, data);
    }

    // The following function is an override required by Solidity.
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }
}
