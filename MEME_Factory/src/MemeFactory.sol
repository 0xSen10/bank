// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./MemeToken.sol";
import "@openzeppelin/contracts/proxy/Clones.sol";

contract MemeFactory {
    using Clones for address;
    
    address public immutable memeTokenImplementation;
    address public projectTreasury;
    
    struct MemeInfo {
        address tokenAddress;
        address creator;
        uint256 totalSupply;
        uint256 mintedSupply;
        uint256 perMint;
        uint256 price;
        bool active;
    }
    
    mapping(address => MemeInfo) public memes;
    mapping(address => address[]) public creatorMemes;
    
    event MemeDeployed(
        address indexed tokenAddress,
        address indexed creator,
        string symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    );
    
    event MemeMinted(
        address indexed tokenAddress,
        address indexed minter,
        uint256 amount,
        uint256 payment
    );
    
    constructor(address _projectTreasury) {
        memeTokenImplementation = address(new MemeToken());
        projectTreasury = _projectTreasury;
    }
    
    function deployMeme(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price
    ) external returns (address) {
        require(totalSupply > 0, "Total supply must be > 0");
        require(perMint > 0, "Per mint must be > 0");
        require(perMint <= totalSupply, "Per mint exceeds total supply");
        require(price > 0, "Price must be > 0");
        
        // Create deterministic salt
        bytes32 salt = keccak256(abi.encodePacked(
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender,
            block.timestamp
        ));
        
        address tokenAddress = Clones.cloneDeterministic(memeTokenImplementation, salt);
        
        // Initialize the token
        string memory name = string(abi.encodePacked("Meme ", symbol));
        MemeToken(tokenAddress).initialize(
            name,
            symbol,
            totalSupply,
            perMint,
            price,
            msg.sender, // 创建者作为所有者
            address(this) // 工厂合约地址
        );
        
        // Store meme info
        MemeInfo memory newMeme = MemeInfo({
            tokenAddress: tokenAddress,
            creator: msg.sender,
            totalSupply: totalSupply,
            mintedSupply: 0,
            perMint: perMint,
            price: price,
            active: true
        });
        
        memes[tokenAddress] = newMeme;
        creatorMemes[msg.sender].push(tokenAddress);
        
        emit MemeDeployed(tokenAddress, msg.sender, symbol, totalSupply, perMint, price);
        
        return tokenAddress;
    }
    
    function mintMeme(address tokenAddress) external payable {
    MemeInfo storage meme = memes[tokenAddress];
    require(meme.active, "Meme not active");
    require(meme.mintedSupply < meme.totalSupply, "All tokens minted");
    
    uint256 mintAmount = meme.perMint;
    if (meme.mintedSupply + mintAmount > meme.totalSupply) {
        mintAmount = meme.totalSupply - meme.mintedSupply;
    }
    
    uint256 requiredPayment = mintAmount * meme.price;
    require(msg.value >= requiredPayment, "Insufficient payment");
    
    // Distribute fees
    uint256 projectFee = requiredPayment / 100; // 1% to project
    uint256 creatorPayment = requiredPayment - projectFee; // 99% to creator
    
    // Transfer payments
    (bool success1, ) = projectTreasury.call{value: projectFee}("");
    (bool success2, ) = meme.creator.call{value: creatorPayment}("");
    require(success1 && success2, "Payment transfer failed");
    
    // Refund excess payment
    if (msg.value > requiredPayment) {
        (bool success3, ) = msg.sender.call{value: msg.value - requiredPayment}("");
        require(success3, "Refund failed");
    }
    
    // 使用新的 mintByFactory 函数
    MemeToken(tokenAddress).mintByFactory(msg.sender, mintAmount);
    meme.mintedSupply += mintAmount;
    
    // Disable minting if all tokens are minted
    // 注意：这里我们只更新工厂的状态，不调用代币的 disableMinting
    if (meme.mintedSupply >= meme.totalSupply) {
        meme.active = false;
        // 不调用 MemeToken(tokenAddress).disableMinting()，因为只有所有者可以调用
    }
    
    emit MemeMinted(tokenAddress, msg.sender, mintAmount, requiredPayment);
}
    
    function getMemeInfo(address tokenAddress) external view returns (MemeInfo memory) {
        return memes[tokenAddress];
    }
    
    function getCreatorMemes(address creator) external view returns (address[] memory) {
        return creatorMemes[creator];
    }
    
    function predictMemeAddress(
        string memory symbol,
        uint256 totalSupply,
        uint256 perMint,
        uint256 price,
        address creator
    ) external view returns (address) {
        bytes32 salt = keccak256(abi.encodePacked(
            symbol,
            totalSupply,
            perMint,
            price,
            creator,
            block.timestamp
        ));
        return Clones.predictDeterministicAddress(memeTokenImplementation, salt);
    }
}