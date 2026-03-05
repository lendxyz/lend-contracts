// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

interface IPool {
    function supply(address asset, uint256 amount, address onBehalfOf, uint16 referralCode) external;
    function repay(address asset, uint256 amount, uint256 interestRateMode, address onBehalfOf)
        external
        returns (uint256);
    function borrow(address asset, uint256 amount, uint256 interestRateMode, uint16 referralCode, address onBehalfOf)
        external;
}

interface IPoolAddressesProvider {
    function getPool() external view returns (address);
    function getAddress(bytes32 id) external view returns (address);
}

interface IPoolDataProvider {
    function getUserReserveData(address asset, address user)
        external
        view
        returns (
            uint256 currentATokenBalance,
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            uint256 principalStableDebt,
            uint256 scaledVariableDebt,
            uint256 stableBorrowRate,
            uint256 liquidityIndex,
            uint256 variableBorrowIndex,
            uint256 stableRateLastUpdated
        );
}
