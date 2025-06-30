// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts/utils/cryptography/MerkleProof.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendRewards is Ownable {
    //********** Init **********

    IERC20 public token;

    struct ClaimData {
        uint256 epoch;
        uint256 balance;
        bytes32[] merkleProof;
    }

    event Claimed(uint256 indexed opId, address indexed user, uint256 balance);
    event RewardsDistributed(uint256 indexed opId, uint256 indexed epoch, uint256 amount);
    event RewardsTokenUpdated(address indexed newRewardsToken);

    // opId => epoch => merkleRoot
    mapping(uint256 => mapping(uint256 => bytes32)) public epochMerkleRoots;

    // opId => epoch => user => claimed
    mapping(uint256 => mapping(uint256 => mapping(address => bool))) public claimed;

    constructor(address _admin, address _token) Ownable(_admin) {
        token = IERC20(_token);
    }

    fallback() external payable {}
    receive() external payable {}

    //********** Read **********

    function claimStatus(uint256 _opId, address _user, uint256 _begin, uint256 _end)
        external
        view
        returns (bool[] memory)
    {
        uint256 size = 1 + _end - _begin;
        bool[] memory arr = new bool[](size);

        for (uint256 i = 0; i < size; i++) {
            arr[i] = claimed[_opId][_begin + i][_user];
        }

        return arr;
    }

    function merkleRoots(uint256 _opId, uint256 _begin, uint256 _end) external view returns (bytes32[] memory) {
        uint256 size = 1 + _end - _begin;
        bytes32[] memory arr = new bytes32[](size);

        for (uint256 i = 0; i < size; i++) {
            arr[i] = epochMerkleRoots[_opId][_begin + i];
        }

        return arr;
    }

    function verifyClaim(
        uint256 _opId,
        address _user,
        uint256 _epoch,
        uint256 _claimedBalance,
        bytes32[] memory _merkleProof
    ) public view returns (bool valid) {
        bytes32 leaf = keccak256(abi.encodePacked(_user, _claimedBalance));
        return MerkleProof.verify(_merkleProof, epochMerkleRoots[_opId][_epoch], leaf);
    }

    //********** Admin **********

    function distributeRewards(uint256 _opId, uint256 _epoch, bytes32 _merkleRoot, uint256 _totalAllocation)
        external
        onlyOwner
    {
        require(epochMerkleRoots[_opId][_epoch] == bytes32(0), "cannot rewrite merkle root");
        require(token.transferFrom(msg.sender, address(this), _totalAllocation), "ERR_TRANSFER_FAILED");

        epochMerkleRoots[_opId][_epoch] = _merkleRoot;
        emit RewardsDistributed(_opId, _epoch, _totalAllocation);
    }

    function setRewardToken(address _newTokenAddress) public onlyOwner {
        token = IERC20(_newTokenAddress);
        emit RewardsTokenUpdated(_newTokenAddress);
    }

    //********** Claim **********

    function transferRewards(uint256 _opId, address _user, uint256 _balance) private {
        if (_balance > 0) {
            require(token.transfer(_user, _balance), "ERR_TRANSFER_FAILED");
            emit Claimed(_opId, _user, _balance);
        }
    }

    function claimEpoch(
        uint256 _opId,
        address _user,
        uint256 _epoch,
        uint256 _claimedBalance,
        bytes32[] memory _merkleProof
    ) public {
        require(_claimedBalance > 0, "claim balance must be more than 0");
        require(!claimed[_opId][_epoch][_user], "epoch already claimed for this user");
        require(verifyClaim(_opId, _user, _epoch, _claimedBalance, _merkleProof), "Incorrect merkle proof");

        claimed[_opId][_epoch][_user] = true;
        transferRewards(_opId, _user, _claimedBalance);
    }

    function claimEpochs(uint256 _opId, address _user, ClaimData[] memory claims) public {
        uint256 totalBalance = 0;
        ClaimData memory claim;

        for (uint256 i = 0; i < claims.length; i++) {
            claim = claims[i];

            if (!claimed[_opId][claim.epoch][_user]) {
                require(
                    verifyClaim(_opId, _user, claim.epoch, claim.balance, claim.merkleProof), "Incorrect merkle proof"
                );

                totalBalance += claim.balance;
                claimed[_opId][claim.epoch][_user] = true;
            }
        }

        if (totalBalance > 0) {
            transferRewards(_opId, _user, totalBalance);
        }
    }
}
