// SPDX-License-Identifier: BSD Protection License
// https://pitch.twomatch.io/

pragma solidity ^0.8.17;

import './IBEP20.sol';
import './SafeMath.sol';
import './Vesting.sol';

contract VestingToken is IBEP20 {
  using SafeMath for uint;
  
  event AirdropSent (address beneficiary, uint amount);

  mapping (address => uint256) private _balances;

  mapping (address => mapping (address => uint256)) private _allowances;

  uint256 private constant _totalSupply = 22_300_000 * 10 ** 18;
  uint8 private constant _decimals = 18;
  string private constant _symbol = 'TMv';
  string private constant _name = 'TwoMatch vesting';

	address public immutable owner;
	address public immutable airdroper;

  mapping (address => bool) private hasReceivedAirdrop;

  address public vestingContractAddress;
  TwoMatchVesting public vestingContract;

	constructor (address airdropAddress) {
		owner = msg.sender;
    airdroper = airdropAddress;

    _balances[owner] = _totalSupply - 300_000 ether;
    _balances[airdroper] = 300_000 ether;

    vestingContract = TwoMatchVesting(vestingContractAddress);

    emit Transfer(address(0), airdroper, _totalSupply);
    emit Transfer(address(0), owner, _totalSupply);
	}

  function setVestingContract (address _vestingContractAddress) external {
    require(msg.sender == owner, 'Owner required');
    require(vestingContractAddress == address(0), 'Contract cannot be changed once set');
    
    vestingContractAddress = _vestingContractAddress;
    vestingContract = TwoMatchVesting(_vestingContractAddress);
  }

	function transfer (address beneficiary, uint256 amount) override public returns (bool) {
    if (msg.sender == airdroper) {
      require(hasReceivedAirdrop[beneficiary] == false, 'TMV: Target address has already got airdrop');

      hasReceivedAirdrop[beneficiary] = true;

      vestingContract.schedule(beneficiary, 0, amount, 0, 10, 30 days);

      emit AirdropSent(beneficiary, amount);
    }

    _transfer(msg.sender, beneficiary, amount);

    return true;
  }

  function decimals() override external pure returns (uint8) {
    return _decimals;
  }

  function symbol() override external pure returns (string memory) {
    return _symbol;
  }

  function name() override external pure returns (string memory) {
    return _name;
  }

  function totalSupply() override external pure returns (uint256) {
    return _totalSupply;
  }

  function balanceOf(address account) override external view returns (uint256) {
    return _balances[account];
  }
	
  function allowance(address _owner, address spender) override external view returns (uint256) {
    return _allowances[_owner][spender];
  }
  
  function getOwner() override external view returns (address) {
    return owner;
  }

  function approve(address spender, uint256 amount) override external returns (bool) {
    _approve(msg.sender, spender, amount);
    return true;
  }

	function _approve(address _owner, address spender, uint256 amount) internal {
    require(owner != address(0), 'BEP20: approve from the zero address');
    require(spender != address(0), 'BEP20: approve to the zero address');

    _allowances[_owner][spender] = amount;
    emit Approval(owner, spender, amount);
  }

  function _transfer(address sender, address recipient, uint256 amount) internal {
    require(sender != address(0), 'BEP20: transfer from the zero address');
    require(recipient != address(0), 'BEP20: transfer to the zero address');
	  
    _balances[sender] = _balances[sender].sub(amount, 'BEP20: transfer amount exceeds balance');
    _balances[recipient] = _balances[recipient].add(amount);

    emit Transfer(sender, recipient, amount);
  }

  function transferFrom(address sender, address recipient, uint256 amount) override external returns (bool) {
    _transfer(sender, recipient, amount);
    _approve(sender, msg.sender, _allowances[sender][msg.sender].sub(amount, "BEP20: transfer amount exceeds allowance"));
    return true;
  }
}