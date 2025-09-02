// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.13;

import {Test, console} from "forge-std/Test.sol";
import {LendFactory} from "../src/Factory.sol";
import {USDC} from "../src/DummyUSDC.sol";
import {LendOperation} from "../src/opLend.sol";

contract TestBase is Test {
    uint256 initialUsdcBalance = 1_000_000_000 * 10 ** 6;
    uint8 sharesDecimal = 6;
    uint256 totalSharesAmount = 1_000_000 * 10 ** sharesDecimal;
    uint256 eurAmountPerShare = 2;
    uint256 sharePriceEur = eurAmountPerShare * 10 ** sharesDecimal;
    uint256 sharesToBuy = 163 * 10 ** sharesDecimal;

    uint256 maxEurUsdcRange = 14; // 1.4 USD per EUR
    uint256 minEurUsdcRange = 10; // 1.0 USD per EUR

    USDC public usdc;
    LendFactory public factory;

    address eurUsdOracle = address(0xb49f677943BC038e9857d61E7d053CaA2C1734C1); // ETH mainnet address
    address lzEndpoint = address(0x1a44076050125825900e736c501f859c50fE728c); // ETH mainnet endpoint

    address backendSigner;
    uint256 backendSignerPk;

    address admin = makeAddr("admin");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");

    string testNonce = "QSfd8gQE4WYzO29";

    function mintUsdc() public {
        vm.startPrank(admin);
        usdc.mint(address(user), initialUsdcBalance);
        usdc.mint(address(user2), initialUsdcBalance);
        vm.stopPrank();
    }

    function getMintSignature(address _user, uint256 _opId, uint256 _amount, string memory _nonce)
        public
        returns (bytes memory)
    {
        vm.startPrank(backendSigner);

        bytes32 digest = keccak256(abi.encodePacked(_opId, _user, _amount, _nonce));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendSignerPk, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        return signature;
    }

    function createOperation() public returns (address) {
        vm.startPrank(admin);

        address op = factory.createOperation("Test operation", totalSharesAmount, sharePriceEur);
        factory.startOperation(1);

        vm.stopPrank();

        return op;
    }

    function setupContracts() public {
        vm.deal(admin, 10 ether);
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
        vm.startPrank(admin);

        (address _backendSigner, uint256 _backendSignerPk) = makeAddrAndKey("backend");

        backendSigner = _backendSigner;
        backendSignerPk = _backendSignerPk;

        usdc = new USDC();
        factory = new LendFactory(address(admin), address(usdc), eurUsdOracle, lzEndpoint, address(backendSigner));

        vm.stopPrank();
    }

    function setUp() public virtual {
        setupContracts();
    }
}
