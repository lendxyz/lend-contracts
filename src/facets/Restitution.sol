// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {LibDiamond} from "../lib/LibDiamond.sol";
import {Events} from "../lib/Utils.sol";
import {Operation, AppStorage, LibAppStorage} from "../lib/Storage.sol";
import {LendOperation} from "../opLend.sol";

contract Restitution {
    function restituteFunds(uint256 id, uint256 amount) external {
        LibDiamond.enforceIsContractOwner();

        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        if (s.usdc.allowance(msg.sender, address(this)) < amount) revert Events.InsufficientAllowance();

        require(s.usdc.transferFrom(msg.sender, address(this), amount), Events.TransferFailed());

        s.restituedAmount[id] = amount;

        emit Events.RestitutionDistributed(id, amount);
    }

    function claimRestituedFunds(uint256 id) external {
        AppStorage storage s = LibAppStorage.appStorage();

        if (id > s.operationCount) revert Events.OpNotExist();
        if (s.restituedAmount[id] == 0) revert Events.RestitutionNotOpened();

        LendOperation opLend = LendOperation(s.operations[id].opToken);

        uint256 userBalance = opLend.balanceOf(msg.sender);
        require(userBalance > 0, "User has no opLend");

        uint256 usdcAmount = (userBalance * s.restituedAmount[id]) / opLend.MAX_SUPPLY();

        require(s.usdc.transfer(msg.sender, usdcAmount), Events.TransferFailed());
        opLend.adminBurn(msg.sender, userBalance);

        emit Events.ClaimedRestitution(msg.sender, id, usdcAmount);
    }
}
