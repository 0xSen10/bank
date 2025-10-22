// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ERC20Vesting is Ownable {
    IERC20 public immutable token;      // 锁定的 ERC20 token
    address public immutable beneficiary; // 受益人

    uint256 public immutable start;     // 合约部署时间
    uint256 public immutable cliff;     // cliff 时间戳
    uint256 public immutable duration;  // 总释放周期（线性释放部分）
    uint256 public released;            // 已释放的 token 数量
    uint256 public immutable totalAmount; // 总锁仓数量

    constructor(
        address _token,
        address _beneficiary,
        uint256 _totalAmount
    ) Ownable(msg.sender) {
        require(_token != address(0), "Token is zero address");
        require(_beneficiary != address(0), "Beneficiary is zero address");
        require(_totalAmount > 0, "Total amount must be > 0");

        token = IERC20(_token);
        beneficiary = _beneficiary;

        start = block.timestamp;
        cliff = start + 12 * 30 days; // 12 个月 cliff
        duration = 24 * 30 days;       // 线性释放 24 个月
        totalAmount = _totalAmount;
    }

    /**
     * @dev 释放当前解锁的 token 给受益人
     */
    function release() external {
        uint256 unreleased = releasableAmount();
        require(unreleased > 0, "No tokens are due");

        released += unreleased;
        token.transfer(beneficiary, unreleased);
    }

    /**
     * @dev 可释放的 token 数量
     */
    function releasableAmount() public view returns (uint256) {
        return vestedAmount() - released;
    }

    /**
     * @dev 当前解锁的 token 总量
     */
    function vestedAmount() public view returns (uint256) {
        if (block.timestamp < cliff) {
            return 0;
        } else if (block.timestamp >= cliff + duration) {
            return totalAmount;
        } else {
            uint256 timeAfterCliff = block.timestamp - cliff;
            return (totalAmount * timeAfterCliff) / duration;
        }
    }
}
