// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Permit.sol";

contract EipToken is ERC20, ERC20Permit {

    constructor(string memory name_, string memory symbol_, uint256 totalSupply)
        ERC20(name_, symbol_)
        ERC20Permit(name_)
    {
        if(totalSupply > 0){
            _mint(msg.sender, totalSupply * 10 ** 18);
        }
    }

}