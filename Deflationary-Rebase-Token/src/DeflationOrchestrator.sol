// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "./DeflationaryToken.sol";

contract DeflationOrchestrator {
    DeflationaryToken public token;
    address public owner;

    event RebaseExecuted(uint256 timestamp, uint256 newTotalSupply);

    modifier onlyOwner() {
        require(msg.sender == owner, "Not authorized");
        _;
    }

    constructor(address tokenAddress) {
        token = DeflationaryToken(tokenAddress);
        owner = msg.sender;
    }

    function executeRebase() external onlyOwner() returns (bool) {
        uint256 newTotalSupply = token.rebase();
        emit RebaseExecuted(block.timestamp, newTotalSupply);
        return true;
    }

    // 检查是否可以执行rebase
    function shouldRebase() public view returns (bool) {
        return block.timestamp >= token.nextRebaseTime();
    }

    // 获取下次rebase信息
   function getRebaseInfo() public view returns (
    uint256 currentSupply,
    uint256 nextRebaseTimestamp,
    bool canRebaseNow
) {
    currentSupply = token.totalSupply();
    nextRebaseTimestamp = token.nextRebaseTime();
    canRebaseNow = shouldRebase();
}
}