// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

import {ERC1967Proxy} from "@openzeppelin/contracts/proxy/ERC1967/ERC1967Proxy.sol";
import {Test, console} from "forge-std/Test.sol";

// Helpers
import {Constants} from "../script/common/Constants.s.sol";
import {FactoryDiamondCuts} from "../script/common/FactoryDiamondCuts.s.sol";

// Misc contracts
import {USDC} from "../src/testnet/DummyUSDC.sol";
import {LendOperation} from "../src/opLend.sol";
import {LendRewards} from "../src/Rewards.sol";

// Factory contracts
import {ILendFactory} from "../src/interfaces/IFactory.sol";
import {IDiamondCut} from "../src/interfaces/IDiamondCut.sol";
import {LendFactory} from "../src/DiamondProxy.sol";
import {Admin} from "../src/facets/Admin.sol";
import {Getters} from "../src/facets/Getters.sol";
import {Invest} from "../src/facets/Invest.sol";
import {Operations} from "../src/facets/Operations.sol";
import {Ownership} from "../src/facets/Ownership.sol";

contract TestBase is Test, FactoryDiamondCuts, Constants {
    uint256 initialUsdcBalance = 1_000_000_000e6;
    uint8 sharesDecimal = 6;
    uint256 totalSharesAmount = 1_000_000 * 10 ** sharesDecimal;
    uint256 eurAmountPerShare = 2;
    uint256 sharePriceEur = eurAmountPerShare * 10 ** sharesDecimal;
    uint256 sharesToBuy = 163 * 10 ** sharesDecimal;

    uint256 maxEurUsdcRange = 14; // 1.4 USD per EUR
    uint256 minEurUsdcRange = 10; // 1.0 USD per EUR

    USDC public usdc;
    ILendFactory public factory;
    LendRewards public rewards;

    address backendSigner;
    uint256 backendSignerPk;

    address admin = makeAddr("lend-admin");
    address user = makeAddr("user");
    address user2 = makeAddr("user2");
    address user3 = makeAddr("user3");

    address[] rewardUsers;
    uint256[] rewardAmounts;

    string testNonce = "QSfd8gQE4WYzO29";

    function mintUsdc() public {
        vm.startPrank(admin);

        deal(address(usdc), address(admin), initialUsdcBalance);
        deal(address(usdc), address(user), initialUsdcBalance);
        deal(address(usdc), address(user2), initialUsdcBalance);

        vm.stopPrank();
    }

    function getMintSignature(address _user, uint256 _opId, uint256 _amount, string memory _nonce)
        public
        returns (bytes memory)
    {
        vm.startPrank(backendSigner);

        bytes32 digest = keccak256(abi.encodePacked(address(factory), block.chainid, _opId, _user, _amount, _nonce));
        bytes32 hash = keccak256(abi.encodePacked("\x19Ethereum Signed Message:\n32", digest));
        (uint8 v, bytes32 r, bytes32 s) = vm.sign(backendSignerPk, hash);
        bytes memory signature = abi.encodePacked(r, s, v);

        vm.stopPrank();

        return signature;
    }

    function getTransferSignature(address _user, string memory _nonce) public returns (bytes memory) {
        vm.startPrank(backendSigner);

        bytes32 digest = keccak256(abi.encodePacked(block.chainid, _user, _nonce));
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

    function deployRewards() public {
        LendRewards implementation = new LendRewards();
        ERC1967Proxy rewardsProxy = new ERC1967Proxy(
            address(implementation), abi.encodeCall(LendRewards.initialize, (address(admin), address(usdc)))
        );

        rewards = LendRewards(payable(rewardsProxy));
        rewardUsers = [address(user), address(user2), address(user3)];
        rewardAmounts = [100e6, 200e6, 300e6];
    }

    function deployDiamond() public {
        Admin adminFacet = new Admin();
        Getters gettersFacet = new Getters();
        Invest investFacet = new Invest();
        Operations operationsFacet = new Operations();
        Ownership ownershipFacet = new Ownership();

        LendFactory diamond = new LendFactory(
            address(admin), address(usdc), mnFactArgs.eurUsdOracle, mnFactArgs.lzEndpoint, address(backendSigner)
        );

        IDiamondCut.FacetCut[] memory cut = getAllFacets(
            address(adminFacet),
            address(gettersFacet),
            address(investFacet),
            address(operationsFacet),
            address(ownershipFacet)
        );

        diamond.diamondCut(cut, address(0), ""); // Perform cut

        factory = ILendFactory(address(diamond));
    }

    function setupContracts() public virtual {
        vm.deal(admin, 10 ether);
        vm.deal(user, 10 ether);
        vm.deal(user2, 10 ether);
        vm.startPrank(admin);

        (address _backendSigner, uint256 _backendSignerPk) = makeAddrAndKey("backend");

        backendSigner = _backendSigner;
        backendSignerPk = _backendSignerPk;
        usdc = USDC(getMainnetUsdcAddress());

        deployDiamond();
        deployRewards();

        vm.stopPrank();
    }

    function setUp() public virtual {
        setupContracts();
    }
}
