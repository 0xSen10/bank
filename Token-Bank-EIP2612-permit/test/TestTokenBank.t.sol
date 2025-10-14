// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "forge-std/Test.sol";
import "forge-std/console.sol";
import "../src/tokenbank.sol"; // 根据您的实际路径调整
import "../src/ERC20Permit.sol"; // 根据您的实际路径调整

contract TokenBankTest is Test {
    ERC20Permit public token;
    TokenBank public bank;
    
    address public owner = address(0x1);
    address public user1 = address(0x2);
    address public user2 = address(0x3);
    address public user3 = address(0x4);

    function setUp() public {
        vm.prank(owner);
        token = new ERC20Permit("senERC20", "SS" );
        
        bank = new TokenBank(address(token));
    }

    // ========== ERC20Permit 测试用例 ==========

    // 测试1: 构造函数初始化
    function test_Constructor() public {
        assertEq(token.name(), "senERC20", "Token name should be correct");
        assertEq(token.symbol(), "SS", "Token symbol should be correct");
        assertEq(token.decimals(), 18, "Token decimals should be 18");
        assertEq(token.totalSupply(), 100000000 * 10**18, "Total supply should be correct");
        assertEq(token.balanceOf(owner), 100000000 * 10**18, "Owner should have all tokens");
    }

    // 测试2: 转账成功
    function test_Transfer_Success() public {
        uint256 transferAmount = 1000 * 10**18;
        
        vm.prank(owner);
        token.transfer(user1, transferAmount);

        assertEq(token.balanceOf(owner), 100000000 * 10**18 - transferAmount, "Owner balance should decrease");
        assertEq(token.balanceOf(user1), transferAmount, "User1 balance should increase");
    }

    // 测试3: 转账失败 - 余额不足
    function test_Transfer_InsufficientBalance() public {
        uint256 excessiveAmount = 100000001 * 10**18; // 超过总供应量
        
        vm.prank(owner);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transfer(user1, excessiveAmount);
    }

    // 测试4: 授权成功
    function test_Approve_Success() public {
        uint256 approveAmount = 5000 * 10**18;
        
        vm.prank(owner);
        token.approve(user1, approveAmount);

        assertEq(token.allowance(owner, user1), approveAmount, "Allowance should be set correctly");
    }

    // 测试5: transferFrom 成功
    function test_TransferFrom_Success() public {
        uint256 approveAmount = 3000 * 10**18;
        uint256 transferAmount = 2000 * 10**18;
        
        // 所有者授权给user1
        vm.prank(owner);
        token.approve(user1, approveAmount);

        // user1 使用授权从owner转账给user2
        vm.prank(user1);
        token.transferFrom(owner, user2, transferAmount);

        assertEq(token.balanceOf(owner), 100000000 * 10**18 - transferAmount, "Owner balance should decrease");
        assertEq(token.balanceOf(user2), transferAmount, "User2 balance should increase");
        assertEq(token.allowance(owner, user1), approveAmount - transferAmount, "Allowance should decrease");
    }

    // 测试6: transferFrom 失败 - 授权不足
    function test_TransferFrom_InsufficientAllowance() public {
        uint256 approveAmount = 1000 * 10**18;
        uint256 transferAmount = 2000 * 10**18; // 超过授权金额
        
        vm.prank(owner);
        token.approve(user1, approveAmount);

        vm.prank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        token.transferFrom(owner, user2, transferAmount);
    }

    // 测试7: transferFrom 失败 - 余额不足
    function test_TransferFrom_InsufficientBalance() public {
        // user1 没有代币，但owner授权给它
        uint256 approveAmount = 1000 * 10**18;
        
        vm.prank(owner);
        token.approve(user1, approveAmount);

        // user1 尝试从user3转账（user3没有代币）
        vm.prank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds balance");
        token.transferFrom(user3, user2, 100 * 10**18);
    }

    // 测试8: 余额查询
    function test_BalanceOf() public {
        assertEq(token.balanceOf(owner), 100000000 * 10**18, "Owner balance should be correct");
        assertEq(token.balanceOf(user1), 0, "New user balance should be 0");
    }

    // 测试9: 授权查询
    function test_Allowance() public {
        assertEq(token.allowance(owner, user1), 0, "Initial allowance should be 0");
        
        uint256 approveAmount = 500 * 10**18;
        vm.prank(owner);
        token.approve(user1, approveAmount);
        
        assertEq(token.allowance(owner, user1), approveAmount, "Allowance should be set correctly");
    }

    // ========== TokenBank 测试用例 ==========

    // 测试10: 存款成功
    function test_Deposit_Success() public {
        uint256 depositAmount = 5000 * 10**18;
        
        // 先给user1转账并授权
        vm.prank(owner);
        token.transfer(user1, depositAmount);
        
        vm.prank(user1);
        token.approve(address(bank), depositAmount);

        // 存款
        vm.prank(user1);
        bank.deposit(depositAmount);

        assertEq(bank.balances(user1), depositAmount, "Bank balance should be correct");
        assertEq(token.balanceOf(user1), 0, "User token balance should be 0 after deposit");
        assertEq(token.balanceOf(address(bank)), depositAmount, "Bank should hold the tokens");
    }

    // 测试11: 存款失败 - 金额为0
    function test_Deposit_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("Deposit amount must be greater than 0");
        bank.deposit(0);
    }

    // 测试12: 存款失败 - 授权不足
    function test_Deposit_InsufficientAllowance() public {
        uint256 depositAmount = 1000 * 10**18;
        
        // user1 没有授权给银行
        vm.prank(user1);
        vm.expectRevert("ERC20: transfer amount exceeds allowance");
        bank.deposit(depositAmount);
    }

    // 测试13: 取款成功
    function test_Withdraw_Success() public {
        uint256 depositAmount = 3000 * 10**18;
        
        // 准备：存款
        vm.prank(owner);
        token.transfer(user1, depositAmount);
        vm.prank(user1);
        token.approve(address(bank), depositAmount);
        vm.prank(user1);
        bank.deposit(depositAmount);

        uint256 initialBankBalance = token.balanceOf(address(bank));
        uint256 initialUserBalance = token.balanceOf(user1);

        // 取款
        vm.prank(user1);
        bank.withdraw(depositAmount);

        assertEq(bank.balances(user1), 0, "Bank balance should be 0 after withdraw");
        assertEq(token.balanceOf(user1), depositAmount, "User should get tokens back");
        assertEq(token.balanceOf(address(bank)), 0, "Bank should have no tokens left");
    }

    // 测试14: 取款失败 - 余额不足
    function test_Withdraw_InsufficientBalance() public {
        uint256 withdrawAmount = 1000 * 10**18;
        
        vm.prank(user1);
        vm.expectRevert("Insufficient balance");
        bank.withdraw(withdrawAmount);
    }

    // 测试15: 取款失败 - 金额为0
    function test_Withdraw_ZeroAmount() public {
        vm.prank(user1);
        vm.expectRevert("Withdraw amount must be greater than 0");
        bank.withdraw(0);
    }

    // 测试16: 多个用户存款取款
    function test_MultipleUsers_DepositWithdraw() public {
        uint256 user1Amount = 2000 * 10**18;
        uint256 user2Amount = 3000 * 10**18;
        
        // 给用户分配代币
        vm.prank(owner);
        token.transfer(user1, user1Amount);
        vm.prank(owner);
        token.transfer(user2, user2Amount);

        // 授权
        vm.prank(user1);
        token.approve(address(bank), user1Amount);
        vm.prank(user2);
        token.approve(address(bank), user2Amount);

        // 存款
        vm.prank(user1);
        bank.deposit(user1Amount);
        vm.prank(user2);
        bank.deposit(user2Amount);

        // 验证存款后状态
        assertEq(bank.balances(user1), user1Amount, "User1 bank balance should be correct");
        assertEq(bank.balances(user2), user2Amount, "User2 bank balance should be correct");
        assertEq(token.balanceOf(address(bank)), user1Amount + user2Amount, "Bank total tokens should be correct");

        // 取款
        vm.prank(user1);
        bank.withdraw(user1Amount);
        vm.prank(user2);
        bank.withdraw(user2Amount);

        // 验证取款后状态
        assertEq(bank.balances(user1), 0, "User1 bank balance should be 0");
        assertEq(bank.balances(user2), 0, "User2 bank balance should be 0");
        assertEq(token.balanceOf(address(bank)), 0, "Bank should have no tokens left");
        assertEq(token.balanceOf(user1), user1Amount, "User1 should have tokens back");
        assertEq(token.balanceOf(user2), user2Amount, "User2 should have tokens back");
    }

    // 测试17: 事件测试 - Transfer
    function test_Transfer_Event() public {
        uint256 transferAmount = 1000 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        vm.prank(owner);
        token.transfer(user1, transferAmount);
    }

    // 测试18: 事件测试 - Approval
    function test_Approval_Event() public {
        uint256 approveAmount = 5000 * 10**18;
        
        vm.expectEmit(true, true, false, true);
        
        vm.prank(owner);
        token.approve(user1, approveAmount);
    }

    // 模糊测试: 随机金额转账
    function testFuzz_Transfer_RandomAmount(uint256 amount) public {
        // 限制金额在合理范围内
        amount = bound(amount, 1, token.balanceOf(owner) / 2);
        
        vm.prank(owner);
        token.transfer(user1, amount);

        assertEq(token.balanceOf(user1), amount, "User1 should receive the transferred amount");
        assertEq(token.balanceOf(owner), 100000000 * 10**18 - amount, "Owner balance should decrease");
    }

    // 模糊测试: 随机金额存款取款
    function testFuzz_DepositWithdraw_RandomAmount(uint256 amount) public {
        // 限制金额在合理范围内
        amount = bound(amount, 1, 10000 * 10**18);
        
        // 准备
        vm.prank(owner);
        token.transfer(user1, amount);
        vm.prank(user1);
        token.approve(address(bank), amount);

        // 存款
        vm.prank(user1);
        bank.deposit(amount);
        assertEq(bank.balances(user1), amount, "Bank balance should match deposit amount");

        // 取款
        vm.prank(user1);
        bank.withdraw(amount);
        assertEq(bank.balances(user1), 0, "Bank balance should be 0 after withdraw");
        assertEq(token.balanceOf(user1), amount, "User should get tokens back");
    }

    // 边界测试: 最大金额转账
    function test_Transfer_MaxAmount() public {
        uint256 maxAmount = token.balanceOf(owner);
        
        vm.prank(owner);
        token.transfer(user1, maxAmount);

        assertEq(token.balanceOf(owner), 0, "Owner balance should be 0");
        assertEq(token.balanceOf(user1), maxAmount, "User1 should have all tokens");
    }
}