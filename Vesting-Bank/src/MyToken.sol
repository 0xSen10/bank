// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MyToken is ERC20 {
    constructor() ERC20("sen", "ss") {
        // 铸造 2,000,000 个代币给部署者 (带18位小数)
        _mint(msg.sender, 2_000_000 * 10 ** decimals());
    }
}
