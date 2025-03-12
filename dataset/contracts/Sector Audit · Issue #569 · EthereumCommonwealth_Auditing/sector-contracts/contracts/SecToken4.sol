// SPDX-License-Identifier: NONE

pragma solidity ^0.8.8;

import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "./lib/SafeMathInt.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract Sector is IERC20 {
    using SafeMath for uint256;
    using SafeMathInt for int256;
    using SafeMathInt for uint256;
    
    uint256 constant internal magnitude = 2**128; // For calculating precise amount for small ether dividend
    uint256 internal DividendPerShare; // Amount of dividend ether per share. Calculated according to decimals
    mapping(address => int256) internal DividendCorrections; // To correct dividend while transferring
    mapping(address => uint256) internal withdrawnDividends; // Keeps track of total withdrawn dividends
    uint256 public activeTokens = 0;
    
    mapping (address => uint256) private _balances;
    mapping (address => mapping (address => uint256)) private _allowances;
    uint256 private _totalSupply;
    string private _name;
    string private _symbol;
    uint256 private _decimals;
    address public owner;
    address payable public development;
    
    event DividendsDistributed(address indexed from, uint256 weiAmount);
    event DividendWithdrawn(address indexed to, uint256 weiAmount);
    event TokensSentToSale(uint amount,address receiver);
    event OwnershipTransferred(address indexed previousOwner, address indexed newOwner);
    
    function transferOwnership(address newOwner) external {
        require(msg.sender == owner,"Only owner");
        require(newOwner != address(0),"Cannot set empty owner");
        uint256 ownerBalance = _balances[owner];
        _balances[newOwner] = _balances[newOwner] + ownerBalance;
        _balances[owner] = 0;
        owner = newOwner;
        emit Transfer(owner, newOwner, ownerBalance);
        emit OwnershipTransferred(owner, newOwner);
    }
  
    constructor (address payable dev) {
        _name = "SECTOR";
        _symbol = "SEC";
        _decimals = 18;
        owner = msg.sender;
        development = dev;
        _mint(msg.sender,100*10**_decimals);
    }
    
    receive() external payable {
        distributeDividends();
    }
    
    mapping(address => bool) public approvedCallers;

    modifier onlyApproved() {
        require(approvedCallers[msg.sender],"Only approved callers can invoke this function");
        _;
    }

    function updateApproval(address caller,bool status) external {
        require(msg.sender == owner,"Only owner can call this function");
        approvedCallers[caller] = status;
    }

    // Function to utilize send tokens to ICO/sale
    function sendTransferFromToSale(address recipient, uint256 amount) external onlyApproved returns (bool) {
        _balances[owner] = _balances[owner].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        activeTokens += amount;
        emit Transfer(owner, recipient, amount);
        emit TokensSentToSale(amount,recipient);
        return true;
    }
    
// Function to distribute dividends to token holders    
    function distributeDividends() public payable {
        if (msg.value > 0) {
            uint256 divs = msg.value - (msg.value * 30) / 100;
            development.transfer((msg.value * 30) / 100);
            DividendPerShare = DividendPerShare.add((divs).mul(magnitude) / activeTokens);
            emit DividendsDistributed(msg.sender, divs);
        }
    }
    
// Function to withdraw available dividends    
    function withdrawDividends() public {
        require(msg.sender != owner,"Owner cannot claim dividends!");
        uint256 _withdrawableDividend = withdrawableDividendOf(msg.sender);
        if (_withdrawableDividend > 0) {
            withdrawnDividends[msg.sender] = withdrawnDividends[msg.sender].add(_withdrawableDividend);
            emit DividendWithdrawn(msg.sender, _withdrawableDividend);
            payable(msg.sender).transfer(_withdrawableDividend);
        }
    }
    
//----------- VIEWS ----------//    
    
// Available amount of dividend to withdraw    
    function withdrawableDividendOf(address user) public view returns(uint256) {
        return accumulativeDividendOf(user).sub(withdrawnDividends[user]);
    }
    
// Amount of dividend an account earned in total    
    function accumulativeDividendOf(address user) public view returns(uint256) {
        return DividendPerShare.mul(balanceOf(user)).toInt256Safe().add(DividendCorrections[user]).toUint256Safe() / magnitude;
    }

// Total withdrawn amount of dividend of an account    
    function withdrawnDividendOf(address user) public view returns(uint256) {
        return withdrawnDividends[user];
    }
    
//--------- TOKEN FUNCTIONS --------------//

    function name() public view virtual returns (string memory) {
        return _name;
    }

    function symbol() public view virtual returns (string memory) {
        return _symbol;
    }

    function decimals() public view virtual returns (uint256) {
        return _decimals;
    }

    function totalSupply() public view override virtual returns (uint256) {
        return _totalSupply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount) public override returns (bool) {
        _transfer(msg.sender, recipient, amount);
        return true;
    }

    function allowance(address user, address spender) public view override returns (uint256) {
        return _allowances[user][spender];
    }

    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(msg.sender, spender, amount);
        return true;
    }

    function transferFrom(address sender, address recipient, uint256 amount) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "ERC20: transfer amount exceeds allowance"));
        return true;
    }

    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].add(addedValue));
        return true;
    }

    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(msg.sender, spender, _allowances[msg.sender][spender].sub(subtractedValue, "ERC20: decreased allowance below zero"));
        return true;
    }

    function _transfer(address sender, address recipient, uint256 amount) internal {
        require(sender != address(0), "ERC20: transfer from the zero address");
        require(sender != owner,"Use sendTokensToSale function");
        require(recipient != address(0), "ERC20: transfer to the zero address");
        
        _balances[sender] = _balances[sender].sub(amount, "ERC20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);
        
        // Error correction while transferring token
        int256 Correction = DividendPerShare.mul(amount).toInt256Safe();
        DividendCorrections[sender] = DividendCorrections[sender].add(Correction);
        DividendCorrections[recipient] = DividendCorrections[recipient].sub(Correction);
        emit Transfer(sender, recipient, amount);
    }

    function _mint(address account, uint256 amount) internal {
        require(account != address(0), "ERC20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    function _approve(address user, address spender, uint256 amount) internal {
        require(user != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");

        _allowances[user][spender] = amount;
        emit Approval(user, spender, amount);
    }

    function retrieveAnyERC20(address _tokenAddress, address _to, uint _amount) public {
        require(owner==msg.sender,"Ownable: caller is not the owner");
        IERC20(_tokenAddress).transfer(_to, _amount);
    }

}
