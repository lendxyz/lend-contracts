// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import {LendOperation} from "../../opLend.sol";

contract LendRestitutionV1 is Initializable, OwnableUpgradeable, UUPSUpgradeable {
    IERC20 public usdc;

    struct Restitution {
        address opLend;
        uint256 sharesAmount;
        uint256 usdcAmount;
    }

    mapping(uint256 => Restitution) public restitutions;
    mapping(uint256 => uint256) public claimedAmount;
    mapping(uint256 => uint256) public opLendReturned;

    event RestitutionClaimed(uint256 indexed opId, address indexed user, uint256 usdcAmount, uint256 opLendAmount);
    event RestitutionFinished(uint256 indexed opId);
    event RestitutionDistributed(uint256 indexed opId, uint256 usdcAmount, uint256 usdcPerOpLend);

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(address _admin, address _usdc) public initializer {
        __Ownable_init(_admin);
        __UUPSUpgradeable_init();

        usdc = IERC20(_usdc);
    }

    function _authorizeUpgrade(address newImplementation) internal override onlyOwner {}

    fallback() external payable {}
    receive() external payable {}

    //********** Admin **********

    function setUsdcAddress(address _usdc) public onlyOwner {
        usdc = IERC20(_usdc);
    }

    function withdrawRestitution(uint256 _id, address _destination) public onlyOwner {
        Restitution storage restitution = restitutions[_id];
        require(!isFinished(_id), "Already claimed all");

        uint256 amountLeft = restitution.usdcAmount - claimedAmount[_id];

        claimedAmount[_id] = restitution.usdcAmount;
        opLendReturned[_id] = restitution.sharesAmount;

        require(usdc.transfer(_destination, amountLeft));

        emit RestitutionFinished(_id);
    }

    function emergencyWithdraw(address _asset, address _destination) public onlyOwner {
        require(_asset != address(usdc), "Cannot withdraw USDC, use withdrawRestitution instead");

        if (_asset == address(0)) {
            (bool sent,) = _destination.call{value: address(this).balance}("");
            require(sent, "Failed to send Ether");
            return;
        }

        require(IERC20(_asset).transfer(_destination, IERC20(_asset).balanceOf(address(this))));
    }

    function restituteFunds(uint256 _id, address _opLend, uint256 _usdcAmount) public onlyOwner {
        require(restitutions[_id].sharesAmount == 0, "Cannot overwrite previous restitution");
        require(_opLend != address(0), "OpLend cannot be address(0)");
        require(_usdcAmount > 0, "USDC amount cannot be zero");

        uint256 sharesAmount = LendOperation(address(_opLend)).MAX_SUPPLY();
        restitutions[_id] = Restitution({opLend: _opLend, sharesAmount: sharesAmount, usdcAmount: _usdcAmount});

        require(usdc.transferFrom(msg.sender, address(this), _usdcAmount), "Failed to transfer USDC");
        emit RestitutionDistributed(_id, _usdcAmount, getUsdcPerOpLend(_id, 1e6));
    }

    //********** Read **********

    function isFinished(uint256 _id) private view returns (bool) {
        Restitution storage restitution = restitutions[_id];

        uint256 amountLeftUsdc = restitution.usdcAmount - claimedAmount[_id];
        require(amountLeftUsdc > 0, "Already claimed all");

        uint256 amountLeftOpLend = restitution.sharesAmount - opLendReturned[_id];
        require(amountLeftOpLend > 0, "Already claimed all");

        return amountLeftOpLend == 0 || amountLeftUsdc == 0;
    }

    function getUsdcPerOpLend(uint256 _id, uint256 _amount) public view returns (uint256) {
        Restitution storage restitution = restitutions[_id];

        if (restitution.sharesAmount == 0) {
            return 0;
        }

        return restitution.usdcAmount * _amount / restitution.sharesAmount;
    }

    function availableRestitution(uint256 _id, address _user) public view returns (uint256) {
        if (isFinished(_id)) {
            return 0;
        }

        LendOperation opLend = LendOperation(restitutions[_id].opLend);
        uint256 userBalance = opLend.balanceOf(_user);
        return getUsdcPerOpLend(_id, userBalance);
    }

    //********** Write **********

    function claimRestitution(uint256 _id, uint256 _amount) public {
        Restitution storage restitution = restitutions[_id];
        require(restitution.usdcAmount > 0, "Operation has not been restitued yet");
        require(!isFinished(_id), "Restitution period ended");

        LendOperation opLend = LendOperation(restitution.opLend);

        uint256 userBalance = opLend.balanceOf(msg.sender);
        require(userBalance >= _amount, "Not enough balance");

        uint256 claimable = getUsdcPerOpLend(_id, _amount);

        require(claimable > 0, "Nothing to claim for this address");

        claimedAmount[_id] += claimable;
        opLendReturned[_id] += _amount;

        require(opLend.transferFrom(msg.sender, address(this), _amount));
        require(usdc.transfer(msg.sender, claimable));

        emit RestitutionClaimed(_id, msg.sender, claimable, _amount);

        if (isFinished(_id)) {
            emit RestitutionFinished(_id);
        }
    }
}
