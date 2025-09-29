// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";
contract TokenBank {
    ERC20 public token;
    constructor(address tokenAddress) {
        token = ERC20(tokenAddress);
    }
    mapping(address => uint256) public balances;


    function deposit(uint256 amount) external virtual  {
        require(amount > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);

    }

    function withdraw(uint256 amount) external virtual  {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
    }
}