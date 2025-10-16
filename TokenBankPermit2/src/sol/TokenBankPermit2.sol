// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IERC20PermitLite {
    function permit(
        address owner,
        address spender,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external;
}

// Permit2 接口定义
interface IPermit2 {
    struct PermitTransferFrom {
        TokenPermissions permitted;
        uint256 nonce;
        uint256 deadline;
    }

    struct TokenPermissions {
        address token;
        uint256 amount;
    }

    struct SignatureTransferDetails {
        address to;
        uint256 requestedAmount;
    }

    function permitTransferFrom(
        PermitTransferFrom memory permit,
        SignatureTransferDetails calldata transferDetails,
        address owner,
        bytes calldata signature
    ) external;
}

contract TokenBank {

    IERC20 public token;
    address public owner;
    IERC20PermitLite public permitToken;
    IPermit2 public permit2;
    
    // Permit2 合约地址 (预部署在多个测试网)
    address public constant PERMIT2_ADDRESS = 0x000000000022D473030F116dDEE9F6B43aC78BA3;

    // 映射  地址  - 数量
    mapping(address => uint256) public deposits;

    constructor(address _tokenAddress){
        owner = msg.sender;
        token = IERC20(_tokenAddress);
        permitToken = IERC20PermitLite(_tokenAddress);
        permit2 = IPermit2(PERMIT2_ADDRESS);
    }

    modifier onlyOwner {
        require(owner == msg.sender, "Illegal permission"); 
        _;
    }
    
    // 通知事件
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event OwnerWithdraw(address indexed admin, uint256 amount);
    
    // deposit() : 需要记录每个地址的存入数量；
    function deposit(uint256 amount) external returns (bool){
        // 参数鉴权
        require(amount > 0, "Amount must be greater than 0");
        require(token.balanceOf(msg.sender) >= amount, "Insufficient balance");
        // 查询授权额度
        uint256 allowedAmount = token.allowance(msg.sender, address(this));
        require(allowedAmount >= amount, "Insufficient authorization limit");

        // 进行转账
        token.transferFrom(msg.sender, address(this), amount);
        // 记录用户存款
        deposits[msg.sender] += amount;
        
        emit Deposit(msg.sender, amount);
        return true;
    }


    // withdraw（）: 用户可以提取自己的之前存入的 token。
    function withdraw(uint256 amount) external returns (bool){
        // 参数鉴权
        require(amount > 0, "Amount must be greater than 0");
        require(deposits[msg.sender] >= amount, "Insufficient balance");

        // 记录用户提取
        deposits[msg.sender] -= amount;

        // 进行转账 从合约转回给用户
        bool success = token.transfer(msg.sender, amount);
        require(success, "Token transfer failed");
        emit Withdraw(msg.sender, amount);
        return true;
    }


    // 管理员可以提取所有的Token (ownerWithdraw 方法)。
    function ownerWithdraw() external onlyOwner returns (bool){
        uint256 bankBalance = token.balanceOf(address(this));
        require(bankBalance > 0, "No tokens to withdraw");

        // 进行转账
        bool success = token.transfer(owner, bankBalance);
        require(success, "Token transfer failed");

        emit OwnerWithdraw(msg.sender, bankBalance);
        return true;
    }

    // 检查用户的授权额度
    function getAllowance(address user) external view returns (uint256) {
        return token.allowance(user, address(this));
    }
    
    // 检查用户存款
    function getDeposit(address user) external view returns (uint256) {
        return deposits[user];
    }
    
    // 检查银行总存款
    function getBankBalance() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    // 离线存款
    function permitDeposit(
        address owner_,
        uint256 value,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external {
        require(value > 0, "Invalid amount");
        require(block.timestamp <= deadline, "Signature expired");
        require(token.balanceOf(msg.sender) >= value, "insufficient token balance");
        // 签名授权
        permitToken.permit(owner_, address(this), value, deadline, v, r, s);
        // 转入用户余额
        bool success = token.transferFrom(owner_, address(this), value);
        require(success, "transfer failed");
        deposits[owner_] += value;
        emit Deposit(owner_, value);
    }

    // Permit2 存款方法
    function depositWithPermit2(
        IPermit2.PermitTransferFrom memory permit,
        bytes calldata signature,
        address depositor
    ) external {
        require(permit.permitted.amount > 0, "Invalid amount");
        require(block.timestamp <= permit.deadline, "Signature expired");
        require(permit.permitted.token == address(token), "Invalid token");
        
        // 创建转账详情
        IPermit2.SignatureTransferDetails memory transferDetails = IPermit2.SignatureTransferDetails({
            to: address(this),
            requestedAmount: permit.permitted.amount
        });
        
        // 通过 Permit2 执行转账
        permit2.permitTransferFrom(permit, transferDetails, depositor, signature);
        
        // 记录存款
        deposits[depositor] += permit.permitted.amount;
        emit Deposit(depositor, permit.permitted.amount);
    }


}