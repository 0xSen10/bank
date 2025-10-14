// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./ERC20Permit.sol";

contract TokenBank {
    ERC20Permit public token;
    
    constructor(address tokenAddress) {
        token = ERC20Permit(tokenAddress);
    }
    
    mapping(address => uint256) public balances;

    function deposit(uint256 amount) external {
        require(amount > 0, "Deposit amount must be greater than 0");
        balances[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    function withdraw(uint256 amount) external {
        require(amount > 0, "Withdraw amount must be greater than 0");
        require(balances[msg.sender] >= amount, "Insufficient balance");
        balances[msg.sender] -= amount;
        token.transfer(msg.sender, amount);
    }

    /**
     * @dev 使用离线签名授权进行存款
     * @param amount 存款金额
     * @param deadline 签名过期时间
     * @param v, r, s 签名的 ECDSA 参数
     */
    function permitDeposit(
        uint256 amount,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(amount > 0, "Deposit amount must be greater than 0");
        
        // 1. 使用 permit 授权给 TokenBank 合约
        token.permit(msg.sender, address(this), amount, deadline, v, r, s);
        
        // 2. 执行存款操作
        balances[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }

    /**
     * @dev 带最大金额检查的 permit 存款（推荐使用）
     * @param amount 实际存款金额
     * @param maxAmount 签名授权的最大金额（用于防止重放攻击）
     * @param deadline 签名过期时间
     * @param v, r, s 签名的 ECDSA 参数
     */
    function permitDepositWithMax(
        uint256 amount,
        uint256 maxAmount,
        uint256 deadline,
        uint8 v, 
        bytes32 r,
        bytes32 s
    ) external {
        require(amount > 0, "Deposit amount must be greater than 0");
        require(amount <= maxAmount, "Amount exceeds signed maximum");
        
        // 1. 使用 permit 授权最大金额给 TokenBank 合约
        token.permit(msg.sender, address(this), maxAmount, deadline, v, r, s);
        
        // 2. 执行存款操作（只使用实际需要的金额）
        balances[msg.sender] += amount;
        token.transferFrom(msg.sender, address(this), amount);
    }
}