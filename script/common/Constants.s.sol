// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.27;

contract Constants {
    address public testnetOwner = address(0x5Ea84Ad53887CFc467D27e14B6F9EEb5a1C8a283);
    address public dummyUsdc = address(0x73DC60bb3f14852fF727C6C67B187e61A7BB26E8);
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
        dummyUsdc, // usdc - DummyUSDC address
        testnetOwner, // backendSigner - Sepolia testnet deployer address
        testnetOwner // admin - Sepolia testnet deployer address
    );
}
