// SPDX-License-Identifier: MIT
// code from : https://book.getfoundry.sh/reference/cheatcodes/sign-delegation#signature

pragma solidity ^0.8.17;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { TokenBank } from "./TokenBank.sol";

contract SimpleDelegateContract {
    event Executed(address indexed to, uint256 value, bytes data);
 
    struct Call {
        bytes data;
        address to;
        uint256 value;
    }

    // ERC20 Approve 
    // TokenBank Deposit
    function execute(Call[] memory calls) external payable {
        for (uint256 i = 0; i < calls.length; i++) {
            Call memory op = calls[i];
            (bool success, bytes memory result) = op.to.delegatecall(op.data);
            require(success, string(result));
            emit Executed(op.to, op.value, op.data);
        }
    }

    receive() external payable {}


    event Log(string message);

    function initialize() external payable {
        emit Log('Hello, world!');
    }
    
    function ping() external {
        emit Log('Pong!');
    }

    function approveAndDeposit(address token, address tokenbank, uint256 amount) external {
        IERC20(token).approve(tokenbank, amount);
        TokenBank(tokenbank).deposit(amount);
    }
}