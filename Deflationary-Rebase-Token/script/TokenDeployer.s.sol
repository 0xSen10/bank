// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "../src/DeflationaryToken.sol";
import "../src/DeflationOrchestrator.sol";

contract TokenDeployer {
    function deployDeflationaryToken() public returns (address, address) {
        // 部署代币合约
        DeflationaryToken token = new DeflationaryToken();
        token.initialize("Deflation Token", "DEFL", 18, msg.sender);
        
        // 部署Orchestrator合约
        DeflationOrchestrator orchestrator = new DeflationOrchestrator(address(token));
        
        return (address(token), address(orchestrator));
    }
}