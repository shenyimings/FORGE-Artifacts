pragma solidity ^0.4.24;

import "./SafeMath.sol";
import "./TokenRecipient.sol";

contract ERC20Token {
  using SafeMath for uint;

  string public name;
  string public symbol;
  uint256 public totalSupply;
  uint256 public maxSupply;
  uint8 public decimals;

  mapping(address => uint256) _balances;

  mapping (address => mapping (address => uint256)) private _allowed;

  event Transfer(address from, address to, uint value);
  event Approval(address from, address to, uint value);
  event ApproveAndCall(address spender, uint value, bytes extraData);

  constructor(string _name, string _symbol, uint8 _decimals, uint256 _initialSupply, uint256 _maxSupply) public {
    require(_maxSupply >= _initialSupply);

    name = _name;
    symbol = _symbol;
    decimals = _decimals;

    _balances[msg.sender] = _initialSupply;
    totalSupply = _initialSupply;
    maxSupply = _maxSupply;
  }

  function balanceOf(address _owner) public view returns (uint balance) {
    return _balances[_owner];
  }

  function allowance(address _owner, address _spender) public view returns (uint256 remaining) {
    return _allowed[_owner][_spender];
  }

  /**
     * @dev Transfer token to a specified address.
     * @param _to The address to transfer to.
     * @param _value The amount to be transferred.
     */
  function transfer(address _to, uint256 _value) public returns (bool success) {
    _transfer(msg.sender, _to, _value);
    return true;
  }

  /**
     * @dev Transfer tokens from one address to another.
     * Note that while this function emits an Approval event, this is not required as per the specification,
     * and other compliant implementations may not emit the event.
     * @param _from address The address which you want to send tokens from
     * @param _to address The address which you want to transfer to
     * @param _value uint256 the amount of tokens to be transferred
     */
  function transferFrom(address _from, address _to, uint256 _value) public returns (bool success) {
    _transfer(_from, _to, _value);
    _approve(_from, msg.sender, _allowed[_from][msg.sender].sub(_value));
    return true;
  }

  /**
     * @dev Approve the passed address to spend the specified amount of tokens on behalf of msg.sender.
     * Beware that changing an allowance with this method brings the risk that someone may use both the old
     * and the new allowance by unfortunate transaction ordering. One possible solution to mitigate this
     * race condition is to first reduce the spender's allowance to 0 and set the desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     * @param _spender The address which will spend the funds.
     * @param _value The amount of tokens to be spent.
     */
  function approve(address _spender, uint256 _value) public returns (bool success) {
    _approve(msg.sender, _spender, _value);
    return true;
  }

  /**
     * @dev Increase the amount of tokens that an owner allowed to a spender.
     * approve should be called when _allowed[msg.sender][spender] == 0. To increment
     * allowed value is better to use this function to avoid 2 calls (and wait until
     * the first transaction is mined)
     * From MonolithDAO Token.sol
     * Emits an Approval event.
     * @param _spender The address which will spend the funds.
     * @param _addedValue The amount of tokens to increase the allowance by.
     */
  function increaseAllowance(address _spender, uint256 _addedValue) public returns (bool) {
    _approve(msg.sender, _spender, _allowed[msg.sender][_spender].add(_addedValue));
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   * approve should be called when _allowed[msg.sender][spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * Emits an Approval event.
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseAllowance(address _spender, uint256 _subtractedValue) public returns (bool) {
    _approve(msg.sender, _spender, _allowed[msg.sender][_spender].sub(_subtractedValue));
    return true;
  }

  function approveAndCall(address _spender, uint256 _value, bytes _extraData)  public returns (bool success) {
    require(_spender != address(0));

    TokenRecipient spender = TokenRecipient(_spender);
    if (approve(_spender, _value)) {
      spender.receiveApproval(msg.sender, _value, this, _extraData);
      emit ApproveAndCall(_spender, _value, _extraData );
      return true;
    }

    return false;
  }

  /**
     * @dev Approve an address to spend another addresses' tokens.
     * @param owner The address that owns the tokens.
     * @param spender The address that will spend the tokens.
     * @param value The number of tokens that can be spent.
     */
  function _approve(address owner, address spender, uint256 value) internal {
    require(spender != address(0));
    require(owner != address(0));

    _allowed[owner][spender] = value;
    emit Approval(owner, spender, value);
  }

  /**
     * @dev Transfer token for a specified addresses.
     * @param from The address to transfer from.
     * @param to The address to transfer to.
     * @param value The amount to be transferred.
     */
  function _transfer(address from, address to, uint256 value) internal {
    require(to != address(0));

    _balances[from] = _balances[from].sub(value);
    _balances[to] = _balances[to].add(value);
    emit Transfer(from, to, value);
  }
}
