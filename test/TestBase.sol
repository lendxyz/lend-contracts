// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LendFactory} from "../src/Factory.sol";
import {LendDebt} from "../src/dLend.sol";
import {USDC} from "../src/DummyUSDC.sol";
import {LendOperation} from "../src/opLend.sol";

contract TestBase is Test {
    uint256 initialUSDCBalance = 1_000_000_000 * 10 ** 6;
    uint8 sharesDecimal = 18;
    uint256 totalSharesAmount = 1_000_000 * 10 ** sharesDecimal;
    uint256 eurAmountPerShare = 2;
    uint256 sharePriceEur = eurAmountPerShare * 10 ** sharesDecimal;
    uint256 sharesToBuy = 100 * 10 ** sharesDecimal;

    uint256 maxEurUsdcRange = 14; // 1.4 USD per EUR
    uint256 minEurUsdcRange = 10; // 1.0 USD per EUR

    USDC public usdc = new USDC();
    LendFactory public factory;
    LendDebt public dLend;

    address EURUSDOracle = address(0xb49f677943BC038e9857d61E7d053CaA2C1734C1); // ETH mainnet address
    address lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c); // ETH mainnet endpoint

    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");

    function mintUSDC() public {
        vm.prank(admin);
        usdc.mint(address(user), initialUSDCBalance);
        usdc.mint(address(user2), initialUSDCBalance);
    }

    function createOperation() public returns (address) {
        vm.prank(admin);
        return factory.createOperation("Test operation", totalSharesAmount, sharePriceEur, sharesDecimal);
    }

    function setupContracts() public {
        vm.deal(admin, 10 ether);
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
        vm.startPrank(admin);

        factory = new LendFactory(address(admin), address(usdc), EURUSDOracle, lzEndpoint);
        dLend = new LendDebt(address(factory));
        factory.setDLendAddress(address(dLend));

        vm.stopPrank();
    }

    function setUp() public virtual {
        setupContracts();
    }
}
