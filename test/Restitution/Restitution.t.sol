// SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.27;

import {Test} from "forge-std/Test.sol";
import {TestBase} from "../TestBase.t.sol";
import {LendOperation} from "../../src/opLend.sol";

contract RestitutionTest is Test, TestBase {
    uint256 opId = 1;
    uint256 restAmount = 1_000_000e6;
    uint256 userShares;

    LendOperation restOpLend;

    function setUp() public virtual override(TestBase) {
        super.setUp();

        userShares = totalSharesAmount / 2;
        deal(address(usdc), admin, restAmount);
    }

    //********** Fixtures **********

    function createOpRestitution() public {
        restOpLend = LendOperation(createOperation());

        vm.startPrank(admin);
        usdc.approve(address(restitution), type(uint256).max);

        deal(address(usdc), admin, restAmount);
        deal(address(restOpLend), user, userShares);
        deal(address(restOpLend), user2, userShares);

        restitution.restituteFunds(opId, address(restOpLend), restAmount);

        factory.opLendWhitelistUser(opId, user, true);
        factory.opLendWhitelistUser(opId, user2, true);
        factory.opLendWhitelistUser(opId, address(restitution), true);
        vm.stopPrank();

        vm.prank(user);
        restOpLend.approve(address(restitution), type(uint256).max);

        vm.prank(user2);
        restOpLend.approve(address(restitution), type(uint256).max);
    }

    function newOpLend(uint256 _maxSupply) public returns (LendOperation op) {
        vm.startPrank(admin);
        op = new LendOperation(admin, "Standalone op", "SOP", _maxSupply, mnFactArgs.lzEndpoint, admin, backendSigner);
        op.whitelistUserAdmin(address(restitution), true);
        vm.stopPrank();
    }

    function giveShares(LendOperation _op, address _to, uint256 _amount) public {
        vm.prank(admin);
        _op.mint(_to, _amount);

        vm.prank(_to);
        _op.approve(address(restitution), type(uint256).max);
    }

    function fundRestitution(uint256 _id, address _opLend, uint256 _usdcAmount) public {
        deal(address(usdc), admin, usdc.balanceOf(admin) + _usdcAmount);

        vm.startPrank(admin);
        usdc.approve(address(restitution), type(uint256).max);
        restitution.restituteFunds(_id, _opLend, _usdcAmount);
        vm.stopPrank();
    }

    //********** Accessors **********

    function restitutionOpLend(uint256 _id) public view returns (address opLend) {
        (opLend,,) = restitution.restitutions(_id);
    }

    function restitutionShares(uint256 _id) public view returns (uint256 sharesAmount) {
        (, sharesAmount,) = restitution.restitutions(_id);
    }

    function restitutionUsdc(uint256 _id) public view returns (uint256 usdcAmount) {
        (,, usdcAmount) = restitution.restitutions(_id);
    }
}
