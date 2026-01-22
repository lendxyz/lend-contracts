// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract Constants {
    address public tnOwner = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283);
    address public multisigAddress = address(0xC11f4C91a201461a22EEE735E7EF6f07cdecEcbF);
    address public aymAddress = address(0xa036e0f94689B7Bbe514527482EA3D9B412Db9Cf);

    struct FactoryConstructorArgs {
        address eurUsdOracle;
        address lzEndpoint;
        address usdc;
        address backendSigner;
        address admin;
    }

    FactoryConstructorArgs public mnFactArgs = FactoryConstructorArgs(
        address(0xb49f677943BC038e9857d61E7d053CaA2C1734C1), // chainlink EUR/USD oracle
        address(0x1a44076050125825900e736c501f859c50fE728c), // lzEndpoint - Ethereum mainnet
        address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48), // usdc - Ethereum mainnet address
        address(0x499603A70DC410c50A435D0Cd40C656bef4685FD), // backendSigner
        aymAddress
    );

    FactoryConstructorArgs public tnFactArgs = FactoryConstructorArgs(
        address(0x1a81afB8146aeFfCFc5E50e8479e826E7D55b910), // chainlink EUR/USD oracle
        address(0x6EDCE65403992e310A62460808c4b910D972f10f), // lzEndpoint - Sepolia
        address(0x73DC60bb3f14852fF727C6C67B187e61A7BB26E8), // usdc - DummyUSDC address
        tnOwner, // backendSigner - Sepolia testnet deployer address
        tnOwner // admin - Sepolia testnet deployer address
    );

    function getMainnetUsdcAddress() public view returns (address) {
        // Ethereum
        if (block.chainid == 1) {
            return address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
        }

        // Arbitrum
        if (block.chainid == 42161) {
            return address(0xaf88d065e77c8cC2239327C5EDb3A432268e5831);
        }

        // Base
        if (block.chainid == 8453) {
            return address(0x833589fCD6eDb6E08f4c7C32D4f71b54bdA02913);
        }

        // BSC
        if (block.chainid == 56) {
            return address(0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d);
        }

        // Polygon
        if (block.chainid == 137) {
            return address(0x3c499c542cEF5E3811e1192ce70d8cC03d5c3359);
        }

        // Sonic
        if (block.chainid == 146) {
            return address(0x29219dd400f2Bf60E5a23d13Be72B486D4038894);
        }

        // Plume
        if (block.chainid == 98866) {
            return address(0x222365EF19F7947e5484218551B56bb3965Aa7aF);
        }

        // Linea
        if (block.chainid == 59144) {
            return address(0x176211869cA2b568f2A7D4EE941E073a821EE1ff);
        }

        revert("Unknown chain id");
    }

    function getTestnetUsdcAddress() public view returns (address) {
        // Sepolia
        if (block.chainid == 11155111) {
            return address(0x73DC60bb3f14852fF727C6C67B187e61A7BB26E8);
        }

        // Base Sepolia
        if (block.chainid == 84532) {
            return address(0x8cE18070660B07e5392E6072463710BFEd16f92f);
        }

        // Arbitrum Sepolia
        if (block.chainid == 421614) {
            return address(0xd960fbD1217EF083bf1F56719515d5eDC89832E6);
        }

        // Amoy
        if (block.chainid == 80002) {
            return address(0x3eC9eAE6c5965c814f47B562Ac10b64cf428d71A);
        }

        // BSC Testnet
        if (block.chainid == 97) {
            return address(0x7101aE81F8EBfa0ecAA806033aae64BdC0817c35);
        }

        revert("Unknown chain id");
    }
}
