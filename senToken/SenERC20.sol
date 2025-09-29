// SPDX-License-Identifier: MIT
pragma solidity ^0.8.10;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/token/ERC20/ERC20.sol";

interface ITokenReceiver {
    function tokensReceived(
        address sender,
        address recipient,
        uint256 amount,
        bytes calldata data
    ) external returns (bool);
}

contract senERC20 is ERC20 {
    event TransferWithCallback(
        address indexed from,
        address indexed to,
        uint256 value,
        bytes data
    );
    
    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol) {
        // 初始化时给部署者一些代币
        _mint(msg.sender, 1000000 * 10 ** _decimals);
    }
    
    // 带 Hook 的转账函数
    function transferWithCallback(
        address recipient,
        uint256 amount,
        bytes calldata data
    ) external returns (bool) {
        bool success = transfer(recipient, amount);
        require(success, "ERC20WithHook: transfer failed");
        
        // 如果目标地址是合约，调用 tokensReceived
        if (isContract(recipient)) {
            bool received = ITokenReceiver(recipient).tokensReceived(msg.sender, recipient, amount, data);
            require(received, "ERC20: token receiver rejected");
        }
        
        emit TransferWithCallback(msg.sender, recipient, amount, data);
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