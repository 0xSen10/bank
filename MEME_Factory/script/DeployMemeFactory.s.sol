// script/DeployMemeFactory.s.sol
pragma solidity ^0.8.19;

import "forge-std/Script.sol";
import "../src/MemeFactory.sol";

contract DeployMemeFactory is Script {
    function run() external {
        uint256 deployerPrivateKey = vm.envUint("PRIVATE_KEY");
        address projectTreasury = vm.envAddress("PROJECT_TREASURY");
        
        vm.startBroadcast(deployerPrivateKey);
        
        MemeFactory factory = new MemeFactory(projectTreasury);
        
        console.log("MemeFactory deployed at:", address(factory));
        console.log("MemeToken implementation:", factory.memeTokenImplementation());
        console.log("Project Treasury:", projectTreasury);
        
        vm.stopBroadcast();
    }
}