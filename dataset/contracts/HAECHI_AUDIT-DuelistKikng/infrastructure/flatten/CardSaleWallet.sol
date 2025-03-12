// Dependency file: @openzeppelin/contracts/token/ERC20/IERC20.sol

// SPDX-License-Identifier: MIT
// OpenZeppelin Contracts v4.4.0 (token/ERC20/IERC20.sol)

// pragma solidity ^0.8.0;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}


// Dependency file: contracts/operators/MultiOwner.sol

// pragma solidity >=0.8.4 <0.9.0;

contract MultiOwner {
  // Multi owner data
  mapping(address => bool) private _owners;

  // Multi owner data
  mapping(address => uint256) private _activeTime;

  // Total number of owners
  uint256 private _totalOwner;

  // Only allow listed address to trigger smart contract
  modifier onlyListedOwner() {
    require(
      _owners[msg.sender] && block.timestamp > _activeTime[msg.sender],
      'MultiOwner: We are only allow owner to trigger this contract'
    );
    _;
  }

  // Transfer ownership event
  event TransferOwnership(address indexed preOwner, address indexed newOwner);

  constructor(address[] memory owners_) {
    for (uint256 i = 0; i < owners_.length; i += 1) {
      _owners[owners_[i]] = true;
      emit TransferOwnership(address(0), owners_[i]);
    }
    _totalOwner = owners_.length;
  }

  /*******************************************************
   * Internal section
   ********************************************************/

  function _transferOwnership(address newOwner, uint256 lockDuration) internal returns (bool) {
    require(newOwner != address(0), 'MultiOwner: Can not transfer ownership to zero address');
    _owners[msg.sender] = false;
    _owners[newOwner] = true;
    _activeTime[newOwner] = block.timestamp + lockDuration;
    emit TransferOwnership(msg.sender, newOwner);
    return _owners[newOwner];
  }

  /*******************************************************
   * View section
   ********************************************************/

  function isOwner(address checkAddress) public view returns (bool) {
    return _owners[checkAddress] && block.timestamp > _activeTime[checkAddress];
  }

  function totalOwner() public view returns (uint256) {
    return _totalOwner;
  }
}


// Root file: contracts/operators/CardSaleWallet.sol

pragma solidity >=0.8.4 <0.9.0;

// import '/Users/chiro/GitHub/infrastructure/node_modules/@openzeppelin/contracts/token/ERC20/IERC20.sol';
// import 'contracts/operators/MultiOwner.sol';

/**
 * Card Sale Wallet
 * Name: N/A
 * Domain: N/A
 */
contract CardSaleWallet is MultiOwner {
  // Init target address once and can't change
  address private immutable _target;

  // Pass parameters to MultiOwner
  constructor(address target_, address[] memory owners_) MultiOwner(owners_) {
    _target = target_;
  }

  // Forward fund to target address
  receive() external payable {
    payable(_target).transfer(address(this).balance);
  }

  /*******************************************************
   * Owner section
   ********************************************************/

  // Transfer ownership to new owner
  function transferOwnership(address newOwner) external onlyListedOwner {
    // New owner will be activated after 1 hours
    _transferOwnership(newOwner, 1 hours);
  }

  // Withdraw token to target address
  function withdraw(address[] memory tokens) external onlyListedOwner {
    for (uint256 i = 0; i < tokens.length; i += 1) {
      IERC20 token = IERC20(tokens[i]);
      // Transfer anything
      token.transfer(_target, token.balanceOf(address(this)));
    }
  }
}
