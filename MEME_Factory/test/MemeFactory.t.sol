// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "forge-std/Test.sol";
import "../src/MemeFactory.sol";
import "../src/MemeToken.sol";

contract MemeFactoryTest is Test {
    MemeFactory public factory;
    address public projectTreasury = address(0x123);
    address public creator = address(0x456);
    address public minter = address(0x789);
    
    function setUp() public {
        vm.deal(creator, 10 ether);
        vm.deal(minter, 10 ether);
        factory = new MemeFactory(projectTreasury);
    }
    
    function testDeployMeme() public {
        vm.startPrank(creator);
        
        address memeToken = factory.deployMeme("SS", 1000, 100, 0.001 ether);
        
        // Verify meme info
        MemeFactory.MemeInfo memory memeInfo = factory.getMemeInfo(memeToken);
        assertEq(memeInfo.totalSupply, 1000);
        assertEq(memeInfo.mintedSupply, 0);
        assertEq(memeInfo.perMint, 100);
        assertEq(memeInfo.price, 0.001 ether);
        assertTrue(memeInfo.active);
        
        // Verify token properties
        MemeToken token = MemeToken(memeToken);
        assertEq(token.name(), "Meme SS");
        assertEq(token.symbol(), "SS");
        assertEq(token.MAX_SUPPLY(), 1000);
        assertEq(token.MINT_AMOUNT(), 100);
        assertEq(token.MINT_PRICE(), 0.001 ether);
        assertEq(token.owner(), creator);
        
        vm.stopPrank();
    }
    
    function testMintMeme() public {
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("SS", 1000, 100, 0.001 ether);
        vm.stopPrank();
        
        uint256 initialTreasuryBalance = projectTreasury.balance;
        uint256 initialCreatorBalance = creator.balance;
        
        vm.startPrank(minter);
        factory.mintMeme{value: 0.1 ether}(memeToken); // Pay for 100 tokens
        
        // Verify balances
        MemeToken token = MemeToken(memeToken);
        assertEq(token.balanceOf(minter), 100);
        
        // Verify fee distribution
        uint256 expectedPayment = 100 * 0.001 ether; // 0.1 ether
        uint256 expectedProjectFee = expectedPayment / 100; // 0.001 ether (1%)
        uint256 expectedCreatorPayment = expectedPayment - expectedProjectFee; // 0.099 ether (99%)
        
        assertEq(projectTreasury.balance - initialTreasuryBalance, expectedProjectFee);
        assertEq(creator.balance - initialCreatorBalance, expectedCreatorPayment);
        
        vm.stopPrank();
    }
    
    function testMintMemeExactPayment() public {
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("SS", 1000, 100, 0.001 ether);
        vm.stopPrank();
        
        uint256 requiredPayment = 100 * 0.001 ether;
        
        vm.startPrank(minter);
        factory.mintMeme{value: requiredPayment}(memeToken);
        
        MemeToken token = MemeToken(memeToken);
        assertEq(token.balanceOf(minter), 100);
        vm.stopPrank();
    }
    
    function testMintMemeWithExcessPayment() public {
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("SS", 1000, 100, 0.001 ether);
        vm.stopPrank();
        
        uint256 minterInitialBalance = minter.balance;
        uint256 requiredPayment = 100 * 0.001 ether;
        uint256 excessPayment = 0.05 ether;
        
        vm.startPrank(minter);
        factory.mintMeme{value: requiredPayment + excessPayment}(memeToken);
        
        // Should refund excess payment
        assertEq(minter.balance, minterInitialBalance - requiredPayment);
        
        MemeToken token = MemeToken(memeToken);
        assertEq(token.balanceOf(minter), 100);
        vm.stopPrank();
    }
    
    function testMintMemeMultipleTimes() public {
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("SS", 500, 100, 0.001 ether);
        vm.stopPrank();
        
        vm.startPrank(minter);
        // First mint
        factory.mintMeme{value: 0.1 ether}(memeToken);
        MemeToken token = MemeToken(memeToken);
        assertEq(token.balanceOf(minter), 100);
        
        // Second mint
        factory.mintMeme{value: 0.1 ether}(memeToken);
        assertEq(token.balanceOf(minter), 200);
        
        // Third mint
        factory.mintMeme{value: 0.1 ether}(memeToken);
        assertEq(token.balanceOf(minter), 300);
        
        // Fourth mint
        factory.mintMeme{value: 0.1 ether}(memeToken);
        assertEq(token.balanceOf(minter), 400);
        
        // Fifth mint
        factory.mintMeme{value: 0.1 ether}(memeToken);
        assertEq(token.balanceOf(minter), 500); // All tokens minted
        
        vm.stopPrank();
        
        // Verify meme is no longer active
        MemeFactory.MemeInfo memory memeInfo = factory.getMemeInfo(memeToken);
        assertEq(memeInfo.totalSupply, 500);
        assertEq(memeInfo.mintedSupply, 500);
        assertFalse(memeInfo.active);
    }
    
    function testMintMemePartialFinalMint() public {
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("SS", 250, 100, 0.001 ether);
        vm.stopPrank();
        
        vm.startPrank(minter);
        // First mint - 100 tokens
        factory.mintMeme{value: 0.1 ether}(memeToken);
        
        // Second mint - 100 tokens  
        factory.mintMeme{value: 0.1 ether}(memeToken);
        
        // Third mint - only 50 tokens remaining
        factory.mintMeme{value: 0.1 ether}(memeToken);
        
        MemeToken token = MemeToken(memeToken);
        assertEq(token.balanceOf(minter), 250); // All tokens minted
        assertEq(token.totalSupply(), 250);
        
        vm.stopPrank();
    }
    
    function testCannotMintWhenInsufficientPayment() public {
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("SS", 1000, 100, 0.001 ether);
        vm.stopPrank();
        
        vm.startPrank(minter);
        vm.expectRevert("Insufficient payment");
        factory.mintMeme{value: 0.05 ether}(memeToken); // Only half the required payment
        vm.stopPrank();
    }
    
    function testCannotMintWhenAllTokensMinted() public {
    vm.startPrank(creator);
    address memeToken = factory.deployMeme("TEST", 100, 100, 0.001 ether);
    vm.stopPrank();
    
    vm.startPrank(minter);
    factory.mintMeme{value: 0.1 ether}(memeToken); // Mint all tokens
    
    // 修改这里：期望的错误消息改为 "Meme not active"
    vm.expectRevert("Meme not active");
    factory.mintMeme{value: 0.1 ether}(memeToken); // Try to mint again
    vm.stopPrank();
}
    
    function testFeeDistributionAccuracy() public {
        vm.startPrank(creator);
        address memeToken = factory.deployMeme("SS", 1000, 100, 0.001 ether);
        vm.stopPrank();
        
        uint256 initialTreasuryBalance = projectTreasury.balance;
        uint256 initialCreatorBalance = creator.balance;
        
        vm.startPrank(minter);
        factory.mintMeme{value: 0.1 ether}(memeToken);
        vm.stopPrank();
        
        uint256 totalPayment = 100 * 0.001 ether; // 0.1 ether
        uint256 expectedProjectFee = totalPayment / 100; // 0.001 ether
        uint256 expectedCreatorPayment = totalPayment - expectedProjectFee; // 0.099 ether
        
        assertEq(projectTreasury.balance - initialTreasuryBalance, expectedProjectFee);
        assertEq(creator.balance - initialCreatorBalance, expectedCreatorPayment);
    }
    
    function ssGetCreatorMemes() public {
        vm.startPrank(creator);
        
        address meme1 = factory.deployMeme("ss", 1000, 100, 0.001 ether);
        address meme2 = factory.deployMeme("ss", 2000, 200, 0.002 ether);
        address meme3 = factory.deployMeme("ss", 3000, 300, 0.003 ether);
        
        address[] memory creatorMemes = factory.getCreatorMemes(creator);
        assertEq(creatorMemes.length, 3);
        assertEq(creatorMemes[0], meme1);
        assertEq(creatorMemes[1], meme2);
        assertEq(creatorMemes[2], meme3);
        
        vm.stopPrank();
    }
}