// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/Address.sol";
import "./interfaces/IPancakeRouter02.sol";
import "./interfaces/IPancakeFactory.sol";

contract TheSpartansToken is Context, IERC20, Ownable {
    using Address for address;

    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    mapping(address => bool) private isExcludedFromFee;
    mapping (address => bool) public isPairAddress;
    mapping(address => bool) public blacklist;

    address public immutable uniswapV2Pair;

    IPancakeRouter02 public immutable pancakeV2Router;
    
    address public marketingWallet;

    address public poolWallet;

    string private constant _name = "The Spartans";
    string private constant _symbol = "TSP";
    uint8 private constant _decimals = 18;

    uint256 private _totalSupply = 10000000 * 10**uint256(_decimals);
    uint256 private _poolReward = 200;
    uint256 private _marketingReward = 100;
    uint256 private _timeEnableTrade;

    event EventExcludeAddress(address indexed account);
    event EventRemoveExcludeAddress(address indexed account);

    constructor(
        address router_,
        address marketingWallet_
    ) {
        _balances[_msgSender()] = _balances[_msgSender()] + _totalSupply;
        emit Transfer(address(0), _msgSender(), _totalSupply);

        IPancakeRouter02 _pancakeV2Router = IPancakeRouter02(router_);
        address _uniswapV2Pair = IPancakeFactory(_pancakeV2Router.factory()).createPair(address(this), _pancakeV2Router.WETH());

        isPairAddress[_uniswapV2Pair] = true;
        uniswapV2Pair = _uniswapV2Pair;
        pancakeV2Router = _pancakeV2Router;
        isExcludedFromFee[msg.sender] = true;
        marketingWallet = marketingWallet_;
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address owner) public view override returns (uint256) {
        return _balances[owner];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function increaseAllowance(address spender, uint256 addedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] + addedValue
        );
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue)
        public
        virtual
        returns (bool)
    {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender] - subtractedValue
        );
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _approve(sender, _msgSender(), _allowances[sender][_msgSender()] - amount);
        _transfer(sender, recipient, amount);
        return true;
    }

    function findPercent(uint256 value, uint256 fee)
        public
        pure
        returns (uint256)
    {
        uint256 roundValue = ceil(value, fee);
        uint256 TPercent = roundValue * fee / 10000;
        return TPercent;
    }

    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) private {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        require(
            amount <= _balances[sender],
            "ERC20: amount must be less or equal to balance"
        );
        require(!blacklist[sender] && !blacklist[recipient]);

        if (msg.sender != owner()) {
            require(block.timestamp >= _timeEnableTrade);
        }
        uint256 tokensToTransfer = amount;

        if (isExcludedFromFee[sender] != true) {
            uint256 poolFee = findPercent(amount, _poolReward);
            _balances[poolWallet] = _balances[poolWallet] + poolFee;
            tokensToTransfer = tokensToTransfer - poolFee;

            emit Transfer(sender, poolWallet, poolFee);
        }

        if (isExcludedFromFee[sender] != true && (isPairAddress[sender] || isPairAddress[recipient])) {
            uint256 marketingFee = findPercent(amount, _marketingReward);
            _balances[marketingWallet] = _balances[marketingWallet] + marketingFee;
            tokensToTransfer = tokensToTransfer - marketingFee;

            emit Transfer(sender, marketingWallet, marketingFee);
        }

        _balances[sender] = _balances[sender] - amount;
        _balances[recipient] = _balances[recipient] + tokensToTransfer;
        emit Transfer(sender, recipient, tokensToTransfer);
    }

    function multiTransfer(address[] memory receivers, uint256[] memory amounts)
        public
    {
        for (uint256 i = 0; i < receivers.length; i++) {
            transfer(receivers[i], amounts[i]);
        }
    }

    function _mint(address account, uint256 amount) internal {
        require(amount != 0);
        _balances[account] = _balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }

    /******** DEV FUNCTION */
    function multiBlacklist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            blacklist[addresses[i]] = true;
        }
    }

    function multiRemoveFromBlacklist(address[] calldata addresses) external onlyOwner {
        for (uint256 i = 0; i < addresses.length; i++) {
            blacklist[addresses[i]] = false;
        }
    }

    function setPoolWallet(address poolWallet_) external onlyOwner {
        poolWallet = poolWallet_;
    }

    function setMarketingWallet(address marketingWallet_) external onlyOwner {
        marketingWallet = marketingWallet_;
    }

    function setPoolReward(uint256 reward) external onlyOwner {
        _poolReward = reward;
    }

    function setMarketingReward(uint256 reward) external onlyOwner {
        _marketingReward = reward;
    }

    function excludeAddress(address account) external onlyOwner {
        isExcludedFromFee[account] = true;
        emit EventExcludeAddress(account);
    }

    function removeExcludedAddress(address account) external onlyOwner {
        delete isExcludedFromFee[account];
        emit EventRemoveExcludeAddress(account);
    }

    function setEnableTradingTime(uint256 timeEnableTrade_) external onlyOwner {
        _timeEnableTrade = timeEnableTrade_;
    }

    function ceil(uint256 a, uint256 m) internal pure returns (uint256) {
        return ((a + m - 1) / m) * m;
    }
}