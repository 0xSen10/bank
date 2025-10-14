// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract MemeToken is ERC20 {
    uint256 public MAX_SUPPLY;
    uint256 public MINT_AMOUNT;
    uint256 public MINT_PRICE;
    
    bool public mintingEnabled;
    bool public initialized;
    
    string private _tokenName;
    string private _tokenSymbol;
    address public owner;
    address public factory;
    
    modifier onlyOwner() {
        require(msg.sender == owner, "Not owner");
        _;
    }
    
    modifier onlyFactory() {
        require(msg.sender == factory, "Not factory");
        _;
    }
    
    constructor() ERC20("sen", "ss") {
        // 只在构造函数中设置基本状态，不设置 mintingEnabled
        // 实际的初始化在 initialize 中进行
    }
    
    function initialize(
        string memory _name,
        string memory _symbol,
        uint256 maxSupply,
        uint256 mintAmount,
        uint256 mintPrice,
        address initialOwner,
        address factoryAddress
    ) external {
        require(!initialized, "Already initialized");
        initialized = true;
        
        MAX_SUPPLY = maxSupply;
        MINT_AMOUNT = mintAmount;
        MINT_PRICE = mintPrice;
        _tokenName = _name;
        _tokenSymbol = _symbol;
        factory = factoryAddress;
        
        // 确保铸造是启用的
        mintingEnabled = true;
        
        // 转移所有权给初始所有者
        owner = initialOwner;
    }
    
    function mintByFactory(address to, uint256 amount) external onlyFactory {
        require(mintingEnabled, "Minting disabled");
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
        
        // 如果达到最大供应量，自动禁用铸造
        if (totalSupply() == MAX_SUPPLY) {
            mintingEnabled = false;
        }
    }
    
    function mint(address to, uint256 amount) external onlyOwner {
        require(mintingEnabled, "Minting disabled");
        require(totalSupply() + amount <= MAX_SUPPLY, "Exceeds max supply");
        _mint(to, amount);
        
        if (totalSupply() == MAX_SUPPLY) {
            mintingEnabled = false;
        }
    }
    
    function disableMinting() external onlyOwner {
        mintingEnabled = false;
    }
    
    function transferOwnership(address newOwner) external onlyOwner {
        require(newOwner != address(0), "Invalid owner");
        owner = newOwner;
    }
    
    function name() public view override returns (string memory) {
        return _tokenName;
    }
    
    function symbol() public view override returns (string memory) {
        return _tokenSymbol;
    }
    
    function getTokenInfo() external view returns (
        string memory tokenName,
        string memory tokenSymbol,
        uint256 maxSupply,
        uint256 currentSupply,
        uint256 mintAmount,
        uint256 mintPrice,
        bool isMintingEnabled
    ) {
        return (
            name(),
            symbol(),
            MAX_SUPPLY,
            totalSupply(),
            MINT_AMOUNT,
            MINT_PRICE,
            mintingEnabled
        );
    }
}