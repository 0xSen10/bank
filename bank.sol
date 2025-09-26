// SPDX-License-Identifier: MIT
pragma solidity  ^0.8.0;

interface IBank {
    function deposit() external payable;
    function withdraw(uint amount) external;
    function getContractBalance() external view returns (uint);
    function getBalance(address user) external view returns (uint);
}

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

    function deposit() public payable virtual {
        require(msg.value > 0,"Deposit amount must be greater than 0");
        balance[msg.sender] += msg.value;
    }

    function withdraw(uint amount) external  onlyOwner{
        require(amount <= address(this).balance,"Iicient contract balance");
        payable(owner).transfer(amount);
    } 

    function getContractBalance() external view returns (uint) {
        return address(this).balance;
    }

    function getBalance(address user) external view returns (uint) {
        return balance[user];
    }
}

contract BigBank is bank {

    uint256 public constant MIN_DEPOSIT = 0.001 ether;

    modifier minDeposit() {
        require(msg.value >= MIN_DEPOSIT, "Deposit must be at least 0.001 ether");
        _;
    }

    function deposit() public payable override minDeposit() {
        super.deposit();
    }

    function  transferAdmin(address newAdmin) external onlyOwner() {
        require(newAdmin != address(0), "Invalid new admin address");
        require(newAdmin != owner, "New admin is already the current admin");
        owner = newAdmin;
    }
}

contract Admin{
    address public owner;

    constructor() {
        owner = msg.sender;
    }

    modifier onlyOwner() {
        require(msg.sender == owner, "Only admin can call this function");
        _;
    }

    function adminWithdraw(IBank bank) external onlyOwner() {
        require(address(bank) != address(0), "Invalid bank address"); 
        require(bank.getContractBalance() > 0, "Bank has no balance to withdraw");
        uint bankBalance = bank.getContractBalance();
        bank.withdraw(bankBalance);
    }
}
