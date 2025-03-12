pragma solidity ^0.4.24;

/**
 * @title SafeMath
 * @dev Math operations with safety checks that throw on error
 */
library SafeMath {

  /**
  * @dev Multiplies two numbers, throws on overflow.
  */
  function mul(uint256 _a, uint256 _b) internal pure returns (uint256) {
    // Gas optimization: this is cheaper than asserting 'a' not being zero, but the
    // benefit is lost if 'b' is also tested.
    // See: https://github.com/OpenZeppelin/openzeppelin-solidity/pull/522
    if (_a == 0) {
      return 0;
    }

    uint256 c = _a * _b;
    assert(c / _a == _b);

    return c;
  }

  /**
  * @dev Integer division of two numbers, truncating the quotient.
  */
  function div(uint256 _a, uint256 _b) internal pure returns (uint256) {
    // assert(_b > 0); // Solidity automatically throws when dividing by 0
    uint256 c = _a / _b;
    // assert(_a == _b * c + _a % _b); // There is no case in which this doesn't hold

    return c;
  }

  /**
  * @dev Subtracts two numbers, throws on overflow (i.e. if subtrahend is greater than minuend).
  */
  function sub(uint256 _a, uint256 _b) internal pure returns (uint256) {
    assert(_b <= _a);
    uint256 c = _a - _b;

    return c;
  }

  /**
  * @dev Adds two numbers, throws on overflow.
  */
  function add(uint256 _a, uint256 _b) internal pure returns (uint256) {
    uint256 c = _a + _b;
    assert(c >= _a);

    return c;
  }
}

contract TestingERC20Token {
  using SafeMath for uint;

  string public name;
  string public symbol;
  uint256 public totalSupply;
  uint256 public maxSupply;
  uint8 public decimals;

  mapping(address => uint256) balances;

  mapping(address => mapping (address => uint256)) public allowance;

  event Transfer(address from, address to, uint value);
  event Approval(address from, address to, uint value);
  event TransferedWithFee(address to, uint256 amount, address sideDeveloper, uint256 fee);
  event ActionApproved(string action, address _from, address spender, uint256 amount);

  event Staked(address staker, uint256 amount);
  event Unstaked(address unstaker, uint256 amount);
  event Vested(address vester, uint256 amount, uint256 cliff, uint256 duration, uint256 interval);
  event Burned(address burner, uint256 amount);


  constructor(string _name, string _symbol, uint8 _decimals, uint256 _initialSupply, uint256 _maxSupply) public {
    require(_maxSupply >= _initialSupply);

    name = _name;
    symbol = _symbol;
    decimals = _decimals;

    balances[msg.sender] = _initialSupply;
    totalSupply = _initialSupply;
    maxSupply = _maxSupply;
  }

  function balanceOf(address _owner) public view returns (uint balance) {
    return balances[_owner];
  }

  function transfer(address _to, uint _amount) public returns (bool success) {
    require(_to != address(0));
    require(balances[msg.sender] >= _amount);

    balances[msg.sender] = balances[msg.sender].sub(_amount);
    balances[_to] = balances[_to].add(_amount);

    emit Transfer(msg.sender, _to, _amount);

    return true;
  }

  function transferFrom(address _from, address _to, uint _amount) public returns (bool success) {
    require(_to != address(0));
    require(balances[_from] >= _amount);
    require(allowance[_from][msg.sender] >= _amount);

    balances[_from] = balances[_from].sub(_amount);
    allowance[_from][msg.sender] = allowance[_from][msg.sender].sub(_amount);
    balances[_to] = balances[_to].add(_amount);

    emit Transfer(_from, _to, _amount);

    return true;
  }

  function approve(address _spender, uint _amount) public returns (bool success) {
    require(_spender != address(0));
    require(balances[msg.sender] >= _amount);

    allowance[msg.sender][_spender] = allowance[msg.sender][_spender].add(_amount);

    emit Approval(msg.sender, _spender, _amount);

    return true;
  }

  function transferWithFee(address _to, uint256 _amount, address _sideDeveloper, uint256 _fee) external {
    transfer(_to, _amount);
    transfer(_sideDeveloper, _fee);

    emit TransferedWithFee(_to, _amount, _sideDeveloper, _fee);
  }

  function approveAction(string _action, address _to, uint256 _amount) external {
    approve(_to, _amount);

    emit ActionApproved(_action, msg.sender, _to, _amount);
  }


  function stake(uint256 _amount) external {
    approve(address(this), _amount);
    transferFrom(msg.sender, this, _amount);

    emit Staked(msg.sender, _amount);
  }

  function unstake(uint256 _amount) external {
    emit Unstaked(msg.sender, _amount);
  }

  function vest(uint256 _amount, uint256 _cliff, uint256 _duration, uint256 _interval) external {
    approve(this, _amount);
    transferFrom(msg.sender, this, _amount);

    emit Vested(msg.sender, _amount, _cliff, _duration, _interval);
  }

  function burn(uint256 _amount) external {
    approve(this, _amount);
    transferFrom(msg.sender, this, _amount);

    emit Burned(msg.sender, _amount);
  }
}

