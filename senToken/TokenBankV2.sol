// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./TokenBank.sol";
import "./SenERC20.sol";


contract TokenBankV2 is TokenBank,ITokenReceiver {
    mapping(address => uint256) public deposits;
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    
    constructor(address _token) TokenBank(_token) {}
    

    function tokensReceived(
        address sender,
        address recipient,
        uint256 amount,
        bytes calldata data
    ) external returns (bool)
    {
        require(msg.sender == address(token), "TokenBankV2: Only accepted token can call this function");
        
        // 确保接收方是这个合约地址
        require(recipient == address(this), "TokenBankV2: Invalid recipient");
        
        // 记录用户存款
        deposits[sender] += amount;
        
        // 触发存款事件
        emit Deposit(sender, amount);

        return true;
    }
    
    function withdraw(uint256 amount) public override {
        require(amount > 0, "TokenBankV2: Withdraw amount must be greater than 0");
        require(deposits[msg.sender] >= amount, "TokenBankV2: Insufficient deposited balance");

        deposits[msg.sender] -= amount;
        bool success = token.transfer(msg.sender, amount);
        require(success, "TokenBankV2: Token transfer failed");

        emit Withdraw(msg.sender, amount);
    }

    function deposit(uint256 amount) public override {
        require(amount > 0, "TokenBankV2: Deposit amount must be greater than 0");
        bool success = token.transferFrom(msg.sender, address(this), amount);
        require(success, "Token transfer failed");
    
        balances[msg.sender] += amount;  
        deposits[msg.sender] += amount;
        emit Deposit(msg.sender, amount);
    }

    function transferWithCallback(
        address recipient,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        require(balances[msg.sender] >= amount, "Insufficient balance");
        
        // 如果目标地址是合约，调用 tokensReceived
        if (isContract(recipient)) {
            bool received = ITokenReceiver(recipient).tokensReceived(msg.sender, recipient, amount, data);
            require(received, "ERC20: token receiver rejected");
        }
        balances[msg.sender] -= amount;
        balances[recipient] += amount;
        return true;
    }
    
    // 检查地址是否为合约
    function isContract(address account) internal view returns (bool) {
        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }
}
