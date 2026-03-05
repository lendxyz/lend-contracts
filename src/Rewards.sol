// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {IPoolDataProvider, IPoolAddressesProvider, IPool} from "./interfaces/AaveInterfaces.sol";

/// @custom:oz-upgrades-from src/legacy/Rewards/RewardsV1.sol:LendRewardsV1
contract LendRewards is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IERC20 public rewardToken;

    struct ClaimData {
        uint256 epoch;
        uint256 balance;
        bytes32[] merkleProof;
    }

    event RewardTokenUpdated(address indexed newRewardsToken);
    event EmergencyWithdrawn(address token, uint256 amount);

    // Operation rewards
    event Claimed(uint256 indexed opId, address indexed user, uint256 balance);
    event RewardsDistributed(uint256 indexed opId, uint256 indexed epoch, uint256 amount);

    // Referral rewards
    event ClaimedRef(address indexed user, uint256 balance);
    event RefRewardsDistributed(uint256 indexed epoch, uint256 amount);

    // Operation merkle states
    // opId => epoch => merkleRoot
    mapping(uint256 => mapping(uint256 => bytes32)) public opMerkleRoot;
    // opId => epoch => user => claimed
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public opClaimed;

    // Referral merkle states
    // epoch => merkleRoot
    mapping(uint256 => bytes32) public refMerkleRoot;
    // epoch => user => claimed
    mapping(uint256 => mapping(address => bool)) public refClaimed;

    IPoolAddressesProvider public aaveAddressProvider;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address admin, address rewardTokenAddress) public initializer {
        __Ownable_init(admin);
        __UUPSUpgradeable_init();

        rewardToken = IERC20(rewardTokenAddress);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    fallback() external payable {}
    receive() external payable {}

    //********** Read **********

    function getUsdcBalanceOwed(address user) public view returns (uint256, uint256) {
        require(address(aaveAddressProvider) != address(0), "AAVE module not initialized");

        bytes32 dataProviderId = "DATA_PROVIDER";
        address dataProviderAddress = aaveAddressProvider.getAddress(dataProviderId);

        (
            , // currentATokenBalance
            uint256 currentStableDebt,
            uint256 currentVariableDebt,
            , // principalStableDebt
            , // scaledVariableDebt
            , // stableBorrowRate
            , // liquidityIndex
            , // variableBorrowIndex
        ) = IPoolDataProvider(dataProviderAddress).getUserReserveData(address(rewardToken), user);

        return (currentStableDebt, currentVariableDebt);
    }

    function opClaimStatus(uint256 _opId, address _user, uint256 _begin, uint256 _end)
        external
        view
        returns (bool[] memory)
    {
        uint256 size = 1 + _end - _begin;
        bool[] memory arr = new bool[](size);

        for (uint256 i = 0; i < size; i++) {
            arr[i] = opClaimed[_opId][_begin + i][_user];
        }

        return arr;
    }

    function refClaimStatus(address _user, uint256 _begin, uint256 _end) external view returns (bool[] memory) {
        uint256 size = 1 + _end - _begin;
        bool[] memory arr = new bool[](size);

        for (uint256 i = 0; i < size; i++) {
            arr[i] = refClaimed[_begin + i][_user];
        }

        return arr;
    }

    function opMerkleRoots(uint256 _opId, uint256 _begin, uint256 _end) external view returns (bytes32[] memory) {
        uint256 size = 1 + _end - _begin;
        bytes32[] memory arr = new bytes32[](size);

        for (uint256 i = 0; i < size; i++) {
            arr[i] = opMerkleRoot[_opId][_begin + i];
        }

        return arr;
    }

    function refMerkleRoots(uint256 _begin, uint256 _end) external view returns (bytes32[] memory) {
        uint256 size = 1 + _end - _begin;
        bytes32[] memory arr = new bytes32[](size);

        for (uint256 i = 0; i < size; i++) {
            arr[i] = refMerkleRoot[_begin + i];
        }

        return arr;
    }

    function verifyOpClaim(
        uint256 _opId,
        address _user,
        uint256 _epoch,
        uint256 _claimedBalance,
        bytes32[] memory _merkleProof
    ) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _claimedBalance));
        return MerkleProof.verify(_merkleProof, opMerkleRoot[_opId][_epoch], leaf);
    }

    function verifyRefClaim(address _user, uint256 _epoch, uint256 _claimedBalance, bytes32[] memory _merkleProof)
        public
        view
        returns (bool valid)
    {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _claimedBalance));
        return MerkleProof.verify(_merkleProof, refMerkleRoot[_epoch], leaf);
    }

    //********** Admin **********

    function distributeOpRewards(uint256 _opId, uint256 _epoch, bytes32 _merkleRoot, uint256 _totalAllocation)
        external
        onlyOwner
    {
        require(opMerkleRoot[_opId][_epoch] == bytes32(0), "cannot rewrite merkle root");
        require(rewardToken.transferFrom(msg.sender, address(this), _totalAllocation), "ERR_TRANSFER_FAILED");

        opMerkleRoot[_opId][_epoch] = _merkleRoot;
        emit RewardsDistributed(_opId, _epoch, _totalAllocation);
    }

    function distributeRefRewards(uint256 _epoch, bytes32 _merkleRoot, uint256 _totalAllocation) external onlyOwner {
        require(refMerkleRoot[_epoch] == bytes32(0), "cannot rewrite merkle root");
        require(rewardToken.transferFrom(msg.sender, address(this), _totalAllocation), "ERR_TRANSFER_FAILED");

        refMerkleRoot[_epoch] = _merkleRoot;
        emit RefRewardsDistributed(_epoch, _totalAllocation);
    }

    function setRewardToken(address _newTokenAddress) public onlyOwner {
        rewardToken = IERC20(_newTokenAddress);
        emit RewardTokenUpdated(_newTokenAddress);
    }

    function setAaveAddressProvider(address _newAddress) public onlyOwner {
        aaveAddressProvider = IPoolAddressesProvider(_newAddress);
    }

    function emergencyWithdraw(address _token) public onlyOwner {
        require(_token != address(rewardToken), "Cannot emergency withdraw reward token");

        if (_token == address(0)) {
            (bool sent,) = owner().call{value: address(this).balance}("");
            require(sent, "Failed to send Ether");
        } else {
            IERC20 token = IERC20(_token);
            require(token.transfer(owner(), token.balanceOf(address(this))), "Failed to send token");
        }
    }

    //********** Claim utils **********

    function transferRewards(uint256 _opId, address _user, uint256 _balance, bool isOp) private {
        if (_balance > 0) {
            require(rewardToken.transfer(_user, _balance), "ERR_TRANSFER_FAILED");
            if (isOp) {
                emit Claimed(_opId, _user, _balance);
            } else {
                emit ClaimedRef(_user, _balance);
            }
        }
    }

    function claimAndRepay(uint256 _opId, address _user, uint256 _totalBalance) private {
        if (_totalBalance > 0) {
            // --- Debt Calculation ---
            (uint256 stableDebt, uint256 varDebt) = getUsdcBalanceOwed(_user);
            uint256 totalDebt = stableDebt + varDebt;

            // No debt case
            if (totalDebt == 0) {
                transferRewards(_opId, _user, _totalBalance, true);
                return;
            }

            uint256 amountToRepay = _totalBalance > totalDebt ? totalDebt : _totalBalance;
            uint256 remainingToUser = _totalBalance > amountToRepay ? _totalBalance - amountToRepay : 0;

            // --- Execution ---
            address aavePool = aaveAddressProvider.getPool();
            require(rewardToken.approve(aavePool, amountToRepay), "AAVE <> USDC approval failed");

            uint256 remainingRepayPower = amountToRepay;

            // Repay Stable Debt
            if (stableDebt > 0 && remainingRepayPower > 0) {
                uint256 stableRepay = remainingRepayPower > stableDebt ? stableDebt : remainingRepayPower;
                IPool(aavePool).repay(address(rewardToken), stableRepay, 1, _user);
                remainingRepayPower -= stableRepay;
            }

            // Repay Variable Debt
            if (varDebt > 0 && remainingRepayPower > 0) {
                IPool(aavePool).repay(address(rewardToken), remainingRepayPower, 2, _user);
            }

            // Send leftover rewards if debt was fully repayed
            if (remainingToUser > 0) {
                require(rewardToken.transfer(_user, remainingToUser), "ERR_TRANSFER_FAILED");
            }

            emit Claimed(_opId, _user, _totalBalance);
        }
    }

    //********** Operation rewards **********

    function claimOpEpoch(
        uint256 _opId,
        address _user,
        uint256 _epoch,
        uint256 _claimedBalance,
        bytes32[] memory _merkleProof
    ) public {
        require(_claimedBalance > 0, "claim balance must be more than 0");
        require(!opClaimed[_opId][_epoch][_user], "epoch already claimed for this user");
        require(verifyOpClaim(_opId, _user, _epoch, _claimedBalance, _merkleProof), "Incorrect merkle proof");

        opClaimed[_opId][_epoch][_user] = true;
        transferRewards(_opId, _user, _claimedBalance, true);
    }

    function claimOpEpochs(uint256 _opId, address _user, ClaimData[] memory claims) public {
        uint256 totalBalance = 0;
        ClaimData memory claim;

        for (uint256 i = 0; i < claims.length; i++) {
            claim = claims[i];

            if (!opClaimed[_opId][claim.epoch][_user]) {
                require(
                    verifyOpClaim(_opId, _user, claim.epoch, claim.balance, claim.merkleProof), "Incorrect merkle proof"
                );

                totalBalance += claim.balance;
                opClaimed[_opId][claim.epoch][_user] = true;
            }
        }

        if (totalBalance > 0) {
            transferRewards(_opId, _user, totalBalance, true);
        }
    }

    //********** AAVE module **********

    function claimOpEpochAndRepay(
        uint256 _opId,
        address _user,
        uint256 _epoch,
        uint256 _claimedBalance,
        bytes32[] memory _merkleProof
    ) public {
        require(address(aaveAddressProvider) != address(0), "AAVE module not initialized");
        require(_claimedBalance > 0, "claim balance must be more than 0");
        require(!opClaimed[_opId][_epoch][_user], "epoch already claimed for this user");
        require(verifyOpClaim(_opId, _user, _epoch, _claimedBalance, _merkleProof), "Incorrect merkle proof");

        opClaimed[_opId][_epoch][_user] = true;
        claimAndRepay(_opId, _user, _claimedBalance);
    }

    function claimOpEpochsAndRepay(uint256 _opId, address _user, ClaimData[] memory claims) public {
        require(address(aaveAddressProvider) != address(0), "AAVE module not initialized");

        uint256 totalBalance = 0;
        ClaimData memory claim;

        for (uint256 i = 0; i < claims.length; i++) {
            claim = claims[i];

            if (!opClaimed[_opId][claim.epoch][_user]) {
                require(
                    verifyOpClaim(_opId, _user, claim.epoch, claim.balance, claim.merkleProof), "Incorrect merkle proof"
                );

                totalBalance += claim.balance;
                opClaimed[_opId][claim.epoch][_user] = true;
            }
        }

        claimAndRepay(_opId, _user, totalBalance);
    }

    //********** Referral rewards **********

    function claimRefEpoch(address _user, uint256 _epoch, uint256 _claimedBalance, bytes32[] memory _merkleProof)
        public
    {
        require(_claimedBalance > 0, "claim balance must be more than 0");
        require(!refClaimed[_epoch][_user], "epoch already claimed for this user");
        require(verifyRefClaim(_user, _epoch, _claimedBalance, _merkleProof), "Incorrect merkle proof");

        refClaimed[_epoch][_user] = true;
        transferRewards(0, _user, _claimedBalance, false);
    }

    function claimRefEpochs(address _user, ClaimData[] memory claims) public {
        uint256 totalBalance = 0;
        ClaimData memory claim;

        for (uint256 i = 0; i < claims.length; i++) {
            claim = claims[i];

            if (!refClaimed[claim.epoch][_user]) {
                require(verifyRefClaim(_user, claim.epoch, claim.balance, claim.merkleProof), "Incorrect merkle proof");

                totalBalance += claim.balance;
                refClaimed[claim.epoch][_user] = true;
            }
        }

        if (totalBalance > 0) {
            transferRewards(0, _user, totalBalance, false);
        }
    }
}
