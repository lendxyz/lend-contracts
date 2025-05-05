// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LendFactory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";
import {DummyUSDC} from "../src/DummyUSDC.sol";
import {LendOperation} from "../src/opLend.sol";

contract TestBase is Test {
    uint256 initialUSDCBalance = UINT256_MAX;
    uint8 sharesDecimal = 18;
    uint256 totalSharesAmount = 1_000_000 * 10 ** sharesDecimal;
    uint256 eurAmountPerShare = 2;
    uint256 sharePriceEur = eurAmountPerShare * 10 ** sharesDecimal;
    uint256 sharesToBuy = 100 * 10 ** sharesDecimal;

    uint256 maxEurUsdcRange = 14; // 1.4 USD per EUR
    uint256 minEurUsdcRange = 10; // 1.0 USD per EUR

    DummyUSDC public usdc;
    LendFactory public factory;
    LendDebt public dLend;

    address EURUSDOracle = 0xb49f677943BC038e9857d61E7d053CaA2C1734C1; // ETH mainnet address

    address admin = makeAddr("admin");
    address user = makeAddr("user");

    function mintUSDC() public {
        vm.prank(admin);
        usdc.mint(address(user), initialUSDCBalance);
    }

    function createOperation() public returns (address) {
        vm.prank(admin);
        return factory.createOperation("Test operation", totalSharesAmount, sharePriceEur, sharesDecimal);
    }

    function setUp() public {
        vm.deal(admin, 10 ether);
        vm.deal(user, 10 ether);
        vm.startPrank(admin);

        usdc = new DummyUSDC();
        factory = new LendFactory(address(admin), address(usdc), EURUSDOracle);
        dLend = LendDebt(factory.dLEND());

        vm.stopPrank();
    }
}
