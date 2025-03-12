// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.6.0;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 *
*/

library SafeMath {
  function mul(uint256 a, uint256 b) internal pure returns (uint256) {
    if (a == 0) {
      return 0;
    }
    uint256 c = a * b;
    assert(c / a == b);
    return c;
  }

  function div(uint256 a, uint256 b) internal pure returns (uint256) {
    // assert(b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = a / b;
    // assert(a == b * c + a % b); // There is no case in which this doesn't hold
    return c;
  }

  function sub(uint256 a, uint256 b) internal pure returns (uint256) {
    assert(b <= a);
    return a - b;
  }

  function add(uint256 a, uint256 b) internal pure returns (uint256) {
    uint256 c = a + b;
    assert(c >= a);
    return c;
  }

  function ceil(uint a, uint m) internal pure returns (uint r) {
    return (a + m - 1) / m * m;
  }
}

// ----------------------------------------------------------------------------
// Owned contract
// ----------------------------------------------------------------------------
contract Owned {
    address payable public owner;

    event OwnershipTransferred(address indexed _from, address indexed _to);

    constructor() public {
        owner = msg.sender;
    }

    modifier onlyOwner {
        require(msg.sender == owner, "Only allowed by owner");
        _;
    }

    function transferOwnership(address payable _newOwner) external onlyOwner {
        require(_newOwner != address(0), "Invalid owner address");
        owner = _newOwner;
        emit OwnershipTransferred(msg.sender, _newOwner);
    }
}

// ----------------------------------------------------------------------------
// ERC Token Standard #20 Interface
// https://github.com/ethereum/EIPs/blob/master/EIPS/eip-20-token-standard.md
// ----------------------------------------------------------------------------
abstract contract ERC20Interface {
    function totalSupply() external virtual view returns (uint);
    function balanceOf(address tokenOwner) external virtual view returns (uint256 balance);
    function allowance(address tokenOwner, address spender) external virtual view returns (uint256 remaining);
    function transfer(address to, uint256 tokens) external virtual returns (bool success);
    function approve(address spender, uint256 tokens) external virtual returns (bool success);
    function transferFrom(address from, address to, uint256 tokens) external virtual returns (bool success);

    event Transfer(address indexed from, address indexed to, uint256 tokens);
    event Approval(address indexed tokenOwner, address indexed spender, uint256 tokens);
}

// ----------------------------------------------------------------------------
// 'UYF Token' token contract

// Symbol      : UYF
// Name        : UYF Token
// Total supply: 500,000,000
// Decimals    : 18
// ----------------------------------------------------------------------------

// ----------------------------------------------------------------------------
// ERC20 Token, with the addition of symbol, name and decimals and assisted
// token transfers
// ----------------------------------------------------------------------------
contract UYF is ERC20Interface, Owned {
    using SafeMath for uint256;

    string public symbol = "UYF";
    string public  name = "UYF Token";
    uint256 public decimals = 18;
    uint256 _totalSupply = 500000000 * 10 ** (decimals); // 500 million
    uint256 _minSupply = 30000000 * 10 ** (decimals); //30 million
    mapping(address => uint256) balances;
    mapping(address => mapping(address => uint256)) allowed;
    
    address private holdersReserveReceiver = 0x97E8De2CB3E7323D9e720d9b1D0A909508D40D3e;
    address private liquidityProvidersReserveReceiver = 0x8BEa61Ec87B673f1077890474e01eDbBBD9dC4Fa;
    
    mapping(address => bool) deductionsApplicable;
    
    // ------------------------------------------------------------------------
    // Constructor
    // ------------------------------------------------------------------------
    constructor() public {
        owner = 0xC2ece87Bf6f6CF07F4326b191990165A53e0eaA6;
        
        balances[liquidityProvidersReserveReceiver] = 50000 * 10 ** (decimals);
        emit Transfer(address(0), liquidityProvidersReserveReceiver, 50000 * 10 ** (decimals));
        
        balances[holdersReserveReceiver] = 15000 * 10 ** (decimals);
        emit Transfer(address(0), holdersReserveReceiver, 15000 * 10 ** (decimals));
        
        balances[owner] = totalSupply().sub(50000 * 10 ** (decimals)).sub(15000 * 10 ** (decimals));
        emit Transfer(address(0), owner, totalSupply().sub(50000 * 10 ** (decimals)).sub(15000 * 10 ** (decimals)));
        
        deductionsApplicable[0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F] = true;
    }

    /** ERC20Interface function's implementation **/

    function totalSupply() public override view returns (uint256){
       return _totalSupply;
    }

    // ------------------------------------------------------------------------
    // Get the token balance for account `tokenOwner`
    // ------------------------------------------------------------------------
    function balanceOf(address tokenOwner) external override view returns (uint256 balance) {
        return balances[tokenOwner];
    }

    // ------------------------------------------------------------------------
    // Transfer the balance from token owner's account to `to` account
    // - Owner's account must have sufficient balance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transfer(address to, uint256 tokens) external override returns (bool success) {
        require(address(to) != address(0));
        require(balances[msg.sender] >= tokens);
        require(balances[to] + tokens >= balances[to]);
        
        uint256 deduction = 0;
        
        if(deductionsApplicable[to] == true && _totalSupply > _minSupply){
            // burn 0.02%
            deduction = (onePercent(tokens).mul(2)).div(100);
            if(_totalSupply.sub(deduction) < _minSupply)
                deduction = _totalSupply.sub(_minSupply);
            else
                _burn(msg.sender, deduction);
        }
        
        
        balances[msg.sender] = balances[msg.sender].sub(tokens);
        balances[to] = balances[to].add(tokens.sub(deduction));
        emit Transfer(msg.sender, to, tokens.sub(deduction));
        return true;
    }

    // ------------------------------------------------------------------------
    // Token owner can approve for `spender` to transferFrom(...) `tokens`
    // from the token owner's account
    // ------------------------------------------------------------------------
    function approve(address spender, uint256 tokens) external override returns (bool success){
        allowed[msg.sender][spender] = tokens;
        emit Approval(msg.sender,spender,tokens);
        return true;
    }

    // ------------------------------------------------------------------------
    // Transfer `tokens` from the `from` account to the `to` account
    //
    // The calling account must already have sufficient tokens approve(...)-d
    // for spending from the `from` account and
    // - From account must have sufficient balance to transfer
    // - Spender must have sufficient allowance to transfer
    // - 0 value transfers are allowed
    // ------------------------------------------------------------------------
    function transferFrom(address from, address to, uint256 tokens) external override returns (bool success){
        require(tokens <= allowed[from][msg.sender]); //check allowance
        require(balances[from] >= tokens);
        balances[from] = balances[from].sub(tokens);
        allowed[from][msg.sender] = allowed[from][msg.sender].sub(tokens);
        
        uint256 deduction = 0;
        
        if(deductionsApplicable[to] == true && _totalSupply > _minSupply){
            // burn 0.02 %
            deduction = (onePercent(tokens).mul(2)).div(100);
            if(_totalSupply.sub(deduction) < _minSupply)
                deduction = _totalSupply.sub(_minSupply);
            else
                _burn(from, deduction);
        }
        
        balances[to] = balances[to].add(tokens.sub(deduction)); 
        emit Transfer(from, to, tokens.sub(deduction));
        return true;
    }
    
    // ------------------------------------------------------------------------
    // Returns the amount of tokens approved by the owner that can be
    // transferred to the spender's account
    // ------------------------------------------------------------------------
    function allowance(address tokenOwner, address spender) external override view returns (uint256 remaining) {
        return allowed[tokenOwner][spender];
    }
    
    // ------------------------------------------------------------------------
    // Private function to calculate 1% percentage
    // ------------------------------------------------------------------------
    function onePercent(uint256 _tokens) private pure returns (uint256){
        uint256 roundValue = _tokens.ceil(100);
        uint onePercentofTokens = roundValue.mul(100).div(100 * 10**uint(2));
        return onePercentofTokens;
    }
    
    // --------------------------------------------------------------------------
    // @dev Internal function that burns an amount of the token of a given
    // @param value The amount that will be burnt.
    // --------------------------------------------------------------------------
    function _burn(address from, uint256 value) internal {
        _totalSupply = _totalSupply.sub(value);
        balances[address(0)] = balances[address(0)].add(value);
        emit Transfer(from, address(0), value);
    }
    
    // ------------------------------------------------------------------------
    // Add more exchanges address to apply deductions when sold to them
    // ------------------------------------------------------------------------
    function addAddressForDeduction(address _addressToApplyDeductions) external onlyOwner{
        deductionsApplicable[_addressToApplyDeductions] = true;
    }
    
    // ------------------------------------------------------------------------
    // Remove an exchange address to stop applying deductions when sold to them
    // ------------------------------------------------------------------------
    function removeAddressForDeduction(address _addressToApplyDeductions) external onlyOwner{
        deductionsApplicable[_addressToApplyDeductions] = false;
    }
}