// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "forge-std/Test.sol";
import "../src/MyToken.sol";
import "../src/Vesting.sol";

contract VestingTest is Test {
    MyToken public token;
    ERC20Vesting public vesting;
    
    address public beneficiary = address(0x123);
    address public owner = address(0x456);
    uint256 public constant TOTAL_VESTING_AMOUNT = 1_000_000 * 10**18; // 100万代币
    
    // 时间常量
    uint256 public constant MONTH = 30 days;
    uint256 public constant CLIFF_MONTHS = 12;
    uint256 public constant VESTING_MONTHS = 24;
    
    function setUp() public {
        // 部署代币合约
        token = new MyToken();
        
        // 部署归属合约
        vm.prank(owner);
        vesting = new ERC20Vesting(
            address(token),
            beneficiary,
            TOTAL_VESTING_AMOUNT
        );
        
        // 将100万代币从部署者转移到归属合约
        token.transfer(address(vesting), TOTAL_VESTING_AMOUNT);
    }
    
    function testInitialState() public {
        console.log(unicode"=== 初始状态测试 ===");
        console.log(unicode"代币合约地址:", address(token));
        console.log(unicode"归属合约地址:", address(vesting));
        console.log(unicode"受益人地址:", beneficiary);
        console.log(unicode"归属合约代币余额:", token.balanceOf(address(vesting)) / 10**18, unicode"百万");
        console.log(unicode"已释放数量:", vesting.released() / 10**18, unicode"个");
        console.log(unicode"总锁仓量:", vesting.totalAmount() / 10**18, unicode"个");
        
        assertEq(token.balanceOf(address(vesting)), TOTAL_VESTING_AMOUNT);
        assertEq(vesting.released(), 0);
        assertEq(vesting.beneficiary(), beneficiary);
        //assertEq(vesting.token(), address(token));
    }
    
    function testCliffPeriod() public {
        console.log(unicode"\n=== Cliff期测试 (0-12个月) ===");
        
        // 测试第1个月
        vm.warp(block.timestamp + 1 * MONTH);
        uint256 releasable = vesting.releasableAmount();
        uint256 vested = vesting.vestedAmount();
        
        console.log(unicode"第1个月 - 可释放:", releasable / 10**18, unicode"个");
        console.log(unicode"第1个月 - 已归属:", vested / 10**18, unicode"个");
        assertEq(releasable, 0);
        assertEq(vested, 0);
        
        // 测试第6个月
        vm.warp(block.timestamp + 5 * MONTH); // 总共6个月
        releasable = vesting.releasableAmount();
        vested = vesting.vestedAmount();
        
        console.log(unicode"第6个月 - 可释放:", releasable / 10**18, unicode"个");
        console.log(unicode"第6个月 - 已归属:", vested / 10**18, unicode"个");
        assertEq(releasable, 0);
        assertEq(vested, 0);
        
        // 测试第11个月（仍在cliff期内）
        vm.warp(block.timestamp + 5 * MONTH); // 总共11个月
        releasable = vesting.releasableAmount();
        vested = vesting.vestedAmount();
        
        console.log(unicode"第11个月 - 可释放:", releasable / 10**18, unicode"个");
        console.log(unicode"第11个月 - 已归属:", vested / 10**18, unicode"个");
        assertEq(releasable, 0);
        assertEq(vested, 0);
    }
    
    function testVestingStart() public {
        console.log(unicode"\n=== 线性释放开始测试 (第13个月) ===");
        
        // 跳到第13个月（cliff期结束）
        vm.warp(block.timestamp + (CLIFF_MONTHS + 1) * MONTH);
        
        uint256 releasable = vesting.releasableAmount();
        uint256 vested = vesting.vestedAmount();
        uint256 monthlyAmount = TOTAL_VESTING_AMOUNT / VESTING_MONTHS;
        
        console.log(unicode"第13个月 - 可释放:", releasable / 10**18, unicode"个");
        console.log(unicode"第13个月 - 已归属:", vested / 10**18, unicode"个");
        console.log(unicode"预期每月解锁:", monthlyAmount / 10**18, unicode"个 (1/24)");
        
        // 使用近似相等来避免舍入误差
        assertApproxEqRel(releasable, monthlyAmount, 0.0001e18); // 允许0.01%的误差
        assertApproxEqRel(vested, monthlyAmount, 0.0001e18);
        
        // 测试释放
        uint256 beneficiaryBalanceBefore = token.balanceOf(beneficiary);
        vm.prank(beneficiary);
        vesting.release();
        uint256 beneficiaryBalanceAfter = token.balanceOf(beneficiary);
        uint256 actualReleased = beneficiaryBalanceAfter - beneficiaryBalanceBefore;
        
        console.log(unicode"实际释放了:", actualReleased / 10**18, unicode"个");
        console.log(unicode"释放后受益人余额:", beneficiaryBalanceAfter / 10**18, unicode"个");
        console.log(unicode"释放后归属合约余额:", token.balanceOf(address(vesting)) / 10**18, unicode"个");
        console.log(unicode"已释放总量:", vesting.released() / 10**18, unicode"个");
        
        assertApproxEqRel(actualReleased, monthlyAmount, 0.0001e18);
        assertEq(vesting.released(), actualReleased);
    }
    
    function testMonthlyVesting() public {
        console.log(unicode"\n=== 月度释放测试 ===");
        
        // 跳到第13个月开始
        vm.warp(block.timestamp + (CLIFF_MONTHS + 1) * MONTH);
        
        uint256 totalReleased = 0;
        uint256 monthlyAmount = TOTAL_VESTING_AMOUNT / VESTING_MONTHS;
        
        console.log(unicode"每月理论释放量:", monthlyAmount / 10**18, unicode"个");
        
        for (uint256 i = 1; i <= VESTING_MONTHS; i++) {
            uint256 currentMonth = CLIFF_MONTHS + i;
            uint256 releasable = vesting.releasableAmount();
            uint256 vested = vesting.vestedAmount();
            
            console.log(unicode"第%d个月 - 可释放: %d 个, 已归属: %d 个", 
                       currentMonth, 
                       releasable / 10**18, 
                       vested / 10**18);
            
            // 每月释放
            uint256 beneficiaryBalanceBefore = token.balanceOf(beneficiary);
            vm.prank(beneficiary);
            vesting.release();
            uint256 beneficiaryBalanceAfter = token.balanceOf(beneficiary);
            uint256 actualReleased = beneficiaryBalanceAfter - beneficiaryBalanceBefore;
            totalReleased += actualReleased;
            
            console.log(unicode"  实际释放了 %d 个代币给受益人", actualReleased / 10**18);
            console.log(unicode"  累计释放: %d 个", totalReleased / 10**18);
            
            // 使用近似相等检查
            if (i < VESTING_MONTHS) {
                assertApproxEqRel(actualReleased, monthlyAmount, 0.0001e18);
            }
            
            // 跳到下个月
            vm.warp(block.timestamp + 1 * MONTH);
        }
        
        // 最终检查 - 确保总释放量等于总锁仓量
        console.log(unicode"\n最终状态:");
        console.log(unicode"受益人总余额:", token.balanceOf(beneficiary) / 10**18, unicode"个");
        console.log(unicode"归属合约余额:", token.balanceOf(address(vesting)) / 10**18, unicode"个");
        console.log(unicode"已释放总量:", vesting.released() / 10**18, unicode"个");
        console.log(unicode"总锁仓量:", TOTAL_VESTING_AMOUNT / 10**18, unicode"个");
        
        assertEq(token.balanceOf(beneficiary), TOTAL_VESTING_AMOUNT);
        assertEq(token.balanceOf(address(vesting)), 0);
        assertEq(vesting.released(), TOTAL_VESTING_AMOUNT);
    }
    
    function testCompleteVesting() public {
        console.log(unicode"\n=== 完整归属期测试 ===");
        
        // 直接跳到归属期结束（12 + 24 = 36个月后）
        vm.warp(block.timestamp + (CLIFF_MONTHS + VESTING_MONTHS) * MONTH);
        
        uint256 releasable = vesting.releasableAmount();
        uint256 vested = vesting.vestedAmount();
        
        console.log(unicode"第36个月 - 可释放:", releasable / 10**18, unicode"个");
        console.log(unicode"第36个月 - 已归属:", vested / 10**18, unicode"个");
        
        assertEq(releasable, TOTAL_VESTING_AMOUNT);
        assertEq(vested, TOTAL_VESTING_AMOUNT);
        
        // 一次性释放所有代币
        vm.prank(beneficiary);
        vesting.release();
        
        console.log(unicode"最终受益人余额:", token.balanceOf(beneficiary) / 10**18, unicode"个");
        console.log(unicode"最终归属合约余额:", token.balanceOf(address(vesting)) / 10**18, unicode"个");
        
        assertEq(token.balanceOf(beneficiary), TOTAL_VESTING_AMOUNT);
        assertEq(token.balanceOf(address(vesting)), 0);
    }
    
    function testPartialVesting() public {
        console.log(unicode"\n=== 部分释放测试 ===");
        
        // 跳到第18个月（cliff结束后6个月）
        vm.warp(block.timestamp + (CLIFF_MONTHS + 6) * MONTH);
        
        uint256 releasable = vesting.releasableAmount();
        uint256 vested = vesting.vestedAmount();
        uint256 expectedVested = (TOTAL_VESTING_AMOUNT * 6) / VESTING_MONTHS;
        
        console.log(unicode"第18个月 - 可释放:", releasable / 10**18, unicode"个");
        console.log(unicode"第18个月 - 已归属:", vested / 10**18, unicode"个");
        console.log(unicode"预期已归属:", expectedVested / 10**18, unicode"个 (6/24)");
        
        // 使用近似相等
        assertApproxEqRel(vested, expectedVested, 0.0001e18);
        assertApproxEqRel(releasable, expectedVested, 0.0001e18);
        
        // 释放
        vm.prank(beneficiary);
        vesting.release();
        
        console.log(unicode"释放后受益人余额:", token.balanceOf(beneficiary) / 10**18, unicode"个");
        assertApproxEqRel(token.balanceOf(beneficiary), expectedVested, 0.0001e18);
    }
    
    function testVestingPrecision() public {
        console.log(unicode"\n=== 精度测试 ===");
        
        // 计算每月理论释放量
        uint256 monthlyExact = TOTAL_VESTING_AMOUNT / VESTING_MONTHS;
        console.log(unicode"每月理论释放量:", monthlyExact);
        console.log(unicode"每月释放量(以代币计):", monthlyExact / 10**18, unicode"个");
        
        // 计算总释放量
        uint256 totalFromMonthly = monthlyExact * VESTING_MONTHS;
        console.log(unicode"24个月总释放量:", totalFromMonthly);
        console.log(unicode"总锁仓量:", TOTAL_VESTING_AMOUNT);
        console.log(unicode"舍入误差:", (TOTAL_VESTING_AMOUNT - totalFromMonthly) / 10**18, unicode"个");
        
        // 显示舍入误差
        if (totalFromMonthly < TOTAL_VESTING_AMOUNT) {
            console.log(unicode"注意: 由于整数除法舍入，最后一个月会释放剩余的所有代币");
        }
    }
}