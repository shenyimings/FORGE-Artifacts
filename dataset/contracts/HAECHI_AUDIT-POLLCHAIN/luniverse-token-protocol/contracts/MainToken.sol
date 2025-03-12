pragma solidity ^0.4.24;

import "./LinearMintableToken.sol";

contract MainToken is LinearMintableToken {
  event Paused(address account);
  event Unpaused(address account);

  mapping (address => bool) public isLocked;
  bool private _paused;

  constructor(
    string _name,
    string _symbol,
    uint8 _decimals,
    uint256 _initialSupply,
    uint256 _maxSupply
  ) ERC20Token(_name, _symbol, _decimals, _initialSupply, _maxSupply)
  public {
    _paused = false;
  }

  modifier onlyUnlocked() {
    require(!isLocked[msg.sender], "msg.sender is locked");
    _;
  }

  function mint(uint256 _amount) onlyOwner() external {
    require(!mintingStatus);
    uint newTotalSupply = totalSupply.add(_amount);
    address tokenOwner = owner();

    require( newTotalSupply <= maxSupply );

    _balances[tokenOwner] = _balances[tokenOwner].add(_amount);

    totalSupply = newTotalSupply;

    emit Minted(tokenOwner, _amount, _amount);
  }

  function lockAccount(address _account) onlyOwner() external {
    require(!isLocked[_account]);

    isLocked[_account] = true;
  }

  function unlockAccount(address _account) onlyOwner() external {
    require(isLocked[_account]);

    isLocked[_account] = false;
  }

  /**
     * @return True if the contract is paused, false otherwise.
     */
  function paused() public view returns (bool) {
    return _paused;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is not paused.
   */
  modifier whenNotPaused() {
    require(!_paused, "Pausable: paused");
    _;
  }

  /**
   * @dev Modifier to make a function callable only when the contract is paused.
   */
  modifier whenPaused() {
    require(_paused, "Pausable: not paused");
    _;
  }

  /**
   * @dev Called by a owner to pause, triggers stopped state.
   */
  function pause() public onlyOwner whenNotPaused {
    _paused = true;
    emit Paused(msg.sender);
  }

  /**
   * @dev Called by a owner to unpause, returns to normal state.
   */
  function unpause() public onlyOwner whenPaused {
    _paused = false;
    emit Unpaused(msg.sender);
  }

  function transfer(address _to, uint256 _value) public onlyUnlocked whenNotPaused returns (bool) {
    return super.transfer(_to, _value);
  }

  function transferFrom(address _from, address _to, uint256 _value) public onlyUnlocked
  whenNotPaused returns
  (bool) {
    return super.transferFrom(_from, _to, _value);
  }

  function approve(address _spender, uint256 _value) public onlyUnlocked whenNotPaused returns
  (bool) {
    return super.approve(_spender, _value);
  }

  function increaseAllowance(address _spender, uint _addedValue) public onlyUnlocked whenNotPaused
  returns (bool) {
    return super.increaseAllowance(_spender, _addedValue);
  }

  function decreaseAllowance(address _spender, uint _subtractedValue) public onlyUnlocked
  whenNotPaused returns
  (bool) {
    return super.decreaseAllowance(_spender, _subtractedValue);
  }

  function approveAndCall(address _spender, uint256 _value, bytes _extraData) onlyUnlocked whenNotPaused
  public returns
  (bool success) {
    return super.approveAndCall(_spender, _value, _extraData);
  }
}
