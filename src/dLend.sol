// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {ERC1155} from "@openzeppelin/contracts/token/ERC1155/ERC1155.sol";
import {ERC1155Burnable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Burnable.sol";
import {ERC1155Pausable} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Pausable.sol";
import {ERC1155Supply} from "@openzeppelin/contracts/token/ERC1155/extensions/ERC1155Supply.sol";
import {AccessControl} from "@openzeppelin/contracts/access/AccessControl.sol";

contract LendDebt is ERC1155, ERC1155Pausable, ERC1155Burnable, ERC1155Supply, AccessControl {
    address public FACTORY_ADDRESS;
    mapping(uint256 => uint256) public maxSupplyForId;
    mapping(uint256 => uint256) public totalMintedTokens;

    bytes32 public constant FACTORY_ROLE = keccak256("FACTORY_ROLE");
    bytes32 public constant ADMIN_ROLE = keccak256("ADMIN_ROLE");

    constructor(address factory, address admin) ERC1155("https://cdn.lend.xyz/token/{id}.json") {
        FACTORY_ADDRESS = factory;

        _grantRole(FACTORY_ROLE, factory);
        _grantRole(ADMIN_ROLE, admin);
    }

    function setURI(string memory newuri) public onlyRole(ADMIN_ROLE) {
        _setURI(newuri);
    }

    function setMaxSupply(uint256 id, uint256 maxSupply) public onlyRole(FACTORY_ROLE) {
        maxSupplyForId[id] = maxSupply;
    }

    function pause() public onlyRole(ADMIN_ROLE) {
        _pause();
    }

    function unpause() public onlyRole(ADMIN_ROLE) {
        _unpause();
    }

    function adminBurn(address user, uint256 id, uint256 value) public onlyRole(FACTORY_ROLE) {
        _burn(user, id, value);
        totalMintedTokens[id] -= value;
    }

    function mint(address account, uint256 id, uint256 amount, bytes memory data) public onlyRole(FACTORY_ROLE) {
        require(totalMintedTokens[id] + amount <= maxSupplyForId[id], "Total supply cap exceeded");

        totalMintedTokens[id] += amount;
        _mint(account, id, amount, data);
    }

    function safeTransferFrom(address from, address to, uint256 id, uint256 value, bytes memory data)
        public
        virtual
        override
    {
        require(to == FACTORY_ADDRESS, "Can only be transfered to Lend factory");
        super._safeTransferFrom(from, to, id, value, data);
    }

    function safeBatchTransferFrom(
        address from,
        address to,
        uint256[] memory ids,
        uint256[] memory values,
        bytes memory data
    ) public virtual override {
        require(to == FACTORY_ADDRESS, "Can only be transfered to Lend factory");
        super._safeBatchTransferFrom(from, to, ids, values, data);
    }

    // The following function is an override required by Solidity.
    function _update(address from, address to, uint256[] memory ids, uint256[] memory values)
        internal
        override(ERC1155, ERC1155Pausable, ERC1155Supply)
    {
        super._update(from, to, ids, values);
    }

    function supportsInterface(bytes4 interfaceId)
        public
        view
        virtual
        override(ERC1155, AccessControl)
        returns (bool)
    {
        return super.supportsInterface(interfaceId);
    }
}
