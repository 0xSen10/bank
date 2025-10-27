// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/proxy/utils/Initializable.sol";

contract DeflationaryToken is Initializable {
    string private _name;
    string private _symbol;
    uint8 private _decimals;

    //Rebase相关变量
    uint256 private _totalSupply;   // 总供应量
    uint256 private _gonsPerFragment; // 每个片段的gons数量
    uint256 private _totalGons; // 总gons数量

    // 余额映射（存储的是gons，不是实际代币数量）
    mapping(address => uint256) private _gonBalances; // 地址到gons余额的映射
    mapping(address => mapping(address => uint256)) private _allowedFragments; // 允许的片段映射

    //时间相关变量
    uint256 public lastRebaseTime;
    uint256 public constant REBASE_INTERVAL = 365 days; // 每年
    uint256 public constant INITIAL_SUPPLY = 100_000_000 * 10**18;
    uint256 public constant DEFLATION_RATE = 99; // 99% = 下降1%
    uint256 private constant MAX_UINT256 = ~uint256(0); // 最大uint256值
    uint256 private constant MAX_SUPPLY = MAX_UINT256 / 10**36; // 最大供应量限制

    event LogRebase(uint256 indexed epoch, uint256 totalSupply);
    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(address indexed owner, address indexed spender, uint256 value);

    function initialize(
        string memory name_,
        string memory symbol_,
        uint8 decimals_,
        address owner_
         ) public initializer {
        _name = name_;
        _symbol = symbol_;
        _decimals = decimals_;

        _totalSupply = INITIAL_SUPPLY;
        _totalGons = MAX_SUPPLY;
        _gonsPerFragment = _totalGons / _totalSupply;

        // 将所有初始代币分配给部署者
        _gonBalances[owner_] = _totalGons;

        lastRebaseTime = block.timestamp;

        emit Transfer(address(0), owner_, _totalSupply);
    }

    function rebase() public returns (uint256) {
        require(block.timestamp >= lastRebaseTime + REBASE_INTERVAL, "Rebase: Too soon to rebase");
        // 计算通缩后的总供应量 
        uint256 newTotalSupply = (_totalSupply * DEFLATION_RATE) /100;
        // 更新gonsPerFragment以实现通缩
        _gonsPerFragment = _totalGons / newTotalSupply;
        _totalSupply = newTotalSupply;

        // 更新最后一次rebase时间
        lastRebaseTime = block.timestamp;
        emit LogRebase(block.timestamp, _totalSupply);
        return _totalSupply;
    }

    // 获取实际余额（考虑通缩后）
    function balanceOf(address who) public view returns (uint256) {
        return _gonBalances[who] / _gonsPerFragment;
    }

    //获取gons余额（内部使用）
    function gonBalanceOf(address who) public view returns (uint256) {
        return _gonBalances[who];
    }

    function transfer(address to,uint256 value) public returns (bool) {
        uint256 gonValue = value * _gonsPerFragment;
        require(_gonBalances[msg.sender] >= gonValue, "Transfer: insufficient balance");

        _gonBalances[msg.sender] = _gonBalances[msg.sender] - gonValue;
        _gonBalances[to] = _gonBalances[to] + gonValue;

        emit Transfer(msg.sender, to, value);
        return true;
    }

    function transferFrom(address from,address to,uint256 value) public returns (bool) {
        uint256 gonValue = value * _gonsPerFragment; // 转换为gons
        require(_gonBalances[from] >= gonValue, "TransferFrom: insufficient balance");
        require(_allowedFragments[from][msg.sender] >= value, "TransferFrom: allowance exceeded");

        _gonBalances[from] = _gonBalances[from] - gonValue;
        _gonBalances[to] = _gonBalances[to] + gonValue;
        _allowedFragments[from][msg.sender] = _allowedFragments[from][msg.sender] - value;

        emit Transfer(from, to, value);
        return true;
    }

    function approve(address spender, uint256 value) public returns (bool) {
        _allowedFragments[msg.sender][spender] = value;
        emit Approval(msg.sender, spender, value);
        return true;
    }

    // 查询授权额度
    function allowance(address owner_, address spender) public view returns (uint256) {
        return _allowedFragments[owner_][spender];
    }

    // 获取总供应量
    function totalSupply() public view returns (uint256) {
        return _totalSupply;
    }

    function name() public view returns (string memory) {
        return _name;
    }   
    function symbol() public view returns (string memory) {
        return _symbol;
    }
    function decimals() public view returns (uint8) {
        return _decimals;
    }

    // 获取当前gonsPerFragment
    function gonsPerFragment() public view returns (uint256) {
        return _gonsPerFragment;
    }

    // 获取下一次rebase时间
    function nextRebaseTime() public view returns (uint256) {
        return lastRebaseTime + REBASE_INTERVAL;
    }
}