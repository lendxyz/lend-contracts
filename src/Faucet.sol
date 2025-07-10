// SPDX-License-Identifier: MIT
pragma solidity ^0.8.27;

import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract LendFaucet is Ownable {
    IERC20 public token;
    uint256 public constant TOKEN_AMOUNT = 20000 * 10 ** 6;
    uint256 public constant ETH_AMOUNT = 0.01 ether;
    uint256 public constant COOLDOWN = 1 days;

    mapping(address => uint256) public lastClaimed;

    constructor(address _initialOwner, address _token) Ownable(_initialOwner) {
        token = IERC20(_token);
    }

    receive() external payable {}

    function claim() external onlyOwner {
        require(
            block.timestamp - lastClaimed[msg.sender] >= COOLDOWN,
            "Claim cooldown not reached"
        );

        require(address(this).balance >= ETH_AMOUNT, "Not enough ETH in faucet");
        require(token.transfer(msg.sender, TOKEN_AMOUNT), "Token transfer failed");

        lastClaimed[msg.sender] = block.timestamp;

        (bool sent, ) = msg.sender.call{value: ETH_AMOUNT}("");
        require(sent, "ETH transfer failed");
    }

    function withdrawETH(uint256 amount) external onlyOwner {
        require(address(this).balance >= amount, "Insufficient ETH");
        payable(owner()).transfer(amount);
    }

    function withdrawTokens(uint256 amount) external onlyOwner {
        require(token.transfer(owner(), amount), "Token withdrawal failed");
    }
}
