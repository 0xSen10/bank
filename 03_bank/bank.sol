// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.0;

contract bank{
    mapping (address => uint) public balance;

    address public owner;

    struct Depositor {
        address depositorAddress;
        uint256 amount;
    }

    Depositor[3] public topDepositors;

    constructor() {
        owner = msg.sender;
        for (uint i = 0; i < 3; i++) {
            topDepositors[i] = Depositor(address(0),0);
        }
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only admin can call this function");
        _;
    }

    receive() external payable {  
        deposit();
    }

    fallback() external payable { 
        deposit();
    } 

    function deposit() public payable {
        require(msg.value > 0,"Deposit amount must be greater than 0");
        balance[msg.sender] += msg.value;
        _updataTopDepositors(msg.sender,balance[msg.sender]);
    }

    function withdraw(uint amount) external  onlyOwner{
        require(amount < address(this).balance,"Iicient contract balance");
        payable(owner).transfer(amount);
    } 

    function getContractBalance() external view returns (uint) {
        return address(this).balance;
    }

    function getBalance(address user) external view returns (uint) {
        return balance[user];
    }

    function getTopDepositors() external view returns (Depositor[3] memory) {
        return topDepositors;
    }

    function _updataTopDepositors(address depositor,uint newAmount) private {
        if (newAmount < topDepositors[2].amount) {
            return; 
        }
        int256 existingIndex = -1;
        for (uint256 i = 0; i < 3; i++) {
            if (topDepositors[i].depositorAddress == depositor) {
                existingIndex = int256(i);
                break;
            }
        }
        
        // 如果用户已经在排行榜中，更新金额并重新排序
        if (existingIndex >= 0) {
            topDepositors[uint256(existingIndex)].amount = newAmount;
            _sortTopDepositors();
        } else {
            // 新用户，找到插入位置
            for (uint256 i = 0; i < 3; i++) {
                if (newAmount > topDepositors[i].amount) {
                    // 将新用户插入到当前位置，后面的依次后移
                    _shiftDepositors(i);
                    topDepositors[i] = Depositor(depositor, newAmount);
                    break;
                }
            }
        }
    }

    function _sortTopDepositors() private {
        for (uint i = 0; i < 2 ;i ++) {
            for (uint j = 0; j<2 ;j++) {
                if (topDepositors[j].amount < topDepositors[j + 1].amount) {
                    Depositor memory temp = topDepositors[j];
                    topDepositors[j] = topDepositors[j + 1];
                    topDepositors[j + 1] = temp;
                }
            }
        }
    }

    function _shiftDepositors(uint256 startIndex) private {
        for (uint256 i = 2; i > startIndex; i--) {
            topDepositors[i] = topDepositors[i - 1];
        }
    }
}
