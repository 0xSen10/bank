// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../lib/forge-std/src/Script.sol";
import "../src/ERC20Permit.sol";
import "../src/TokenBank.sol";

contract DeployTokenSystem is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address deployer = vm.addr(deployerPrivateKey);
        
        vm.startBroadcast(deployerPrivateKey);
        
        // 1. 先部署 ERC20Permit（根据你的构造函数，只有 name 和 symbol）
        ERC20Permit token = new ERC20Permit(
            "senERC20",          // name
            "SS"                 // symbol
        );
        
        // 2. 部署后调用 mint 函数来铸造代币
        token.mint(1000000 * 10 ** 18);
        
        // 3. 再部署 TokenBank，并传入 token 地址
        TokenBank bank = new TokenBank(address(token));
        
        vm.stopBroadcast();
        
        console.log("ERC20Permit deployed at:", address(token));
        console.log("TokenBank deployed at:", address(bank));
        console.log("Deployer address:", deployer);
        console.log("Token balance of deployer:", token.balanceOf(deployer));
    }
}