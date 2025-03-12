// SPDX-License-Identifier: No License

import "./IERC20.sol";
import "./Ownable2Step.sol";

pragma solidity ^0.8.0;

library SafeMathUint {
  function toInt256Safe(uint256 a) internal pure returns (int256) {
    int256 b = int256(a);
    require(b >= 0);
    return b;
  }
}

library SafeMathInt {
  function toUint256Safe(int256 a) internal pure returns (uint256) {
    require(a >= 0);
    return uint256(a);
  }
}

contract TruncatedERC20 {
  mapping(address => uint256) private _balances;

  uint256 private _totalSupply;

  string private _name;
  string private _symbol;

  /**
   * @dev Emitted when `value` tokens are moved from one account (`from`) to
   * another (`to`).
   *
   * Note that `value` may be zero.
   */
  event Transfer(address indexed from, address indexed to, uint256 value);

  /**
   * @dev Sets the values for {name} and {symbol}.
   *
   * All two of these values are immutable: they can only be set once during
   * construction.
   */
  constructor(string memory name_, string memory symbol_) {
    _name = name_;
    _symbol = symbol_;
  }

  /**
   * @dev Returns the name of the token.
   */
  function name() public view virtual returns (string memory) {
      return _name;
  }

  /**
   * @dev Returns the symbol of the token, usually a shorter version of the
   * name.
   */
  function symbol() public view virtual returns (string memory) {
      return _symbol;
  }

  /**
   * @dev Returns the number of decimals used to get its user representation.
   * For example, if `decimals` equals `2`, a balance of `505` tokens should
   * be displayed to a user as `5.05` (`505 / 10 ** 2`).
   *
   * Tokens usually opt for a value of 18, imitating the relationship between
   * Ether and Wei. This is the default value returned by this function, unless
   * it's overridden.
   *
   * NOTE: This information is only used for _display_ purposes: it in
   * no way affects any of the arithmetic of the contract, including
   * {IERC20-balanceOf} and {IERC20-transfer}.
   */
  function decimals() public view virtual returns (uint8) {
      return 18;
  }

  /**
   * @dev See {IERC20-totalSupply}.
   */
  function totalSupply() public view virtual returns (uint256) {
      return _totalSupply;
  }

  /**
   * @dev See {IERC20-balanceOf}.
   */
  function balanceOf(address account) public view virtual returns (uint256) {
      return _balances[account];
  }

  /** @dev Creates `amount` tokens and assigns them to `account`, increasing
   * the total supply.
   *
   * Emits a {Transfer} event with `from` set to the zero address.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   */
  function _mint(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: mint to the zero address");

    _totalSupply += amount;
    unchecked {
      // Overflow not possible: balance + amount is at most totalSupply + amount, which is checked above.
      _balances[account] += amount;
    }
    emit Transfer(address(0), account, amount);
  }

  /**
   * @dev Destroys `amount` tokens from `account`, reducing the
   * total supply.
   *
   * Emits a {Transfer} event with `to` set to the zero address.
   *
   * Requirements:
   *
   * - `account` cannot be the zero address.
   * - `account` must have at least `amount` tokens.
   */
  function _burn(address account, uint256 amount) internal virtual {
    require(account != address(0), "ERC20: burn from the zero address");

    uint256 accountBalance = _balances[account];
    require(accountBalance >= amount, "ERC20: burn amount exceeds balance");
    unchecked {
      _balances[account] = accountBalance - amount;
      // Overflow not possible: amount <= accountBalance <= totalSupply.
      _totalSupply -= amount;
    }

    emit Transfer(account, address(0), amount);
  }
}

/// @title Dividend-Paying Token Interface
/// @author Roger Wu (https://github.com/roger-wu)
/// @dev An interface for a dividend-paying token contract.
interface DividendPayingTokenInterface {

  function dividendOf(address _owner) external view returns (uint256);

  event DividendsDistributed(address indexed from, uint256 weiAmount);

  event DividendWithdrawn(address indexed to, uint256 weiAmount);
}

/// @title Dividend-Paying Token Optional Interface
/// @author Roger Wu (https://github.com/roger-wu)
/// @dev OPTIONAL functions for a dividend-paying token contract.
interface DividendPayingTokenOptionalInterface {

  function withdrawableDividendOf(address _owner) external view returns (uint256);

  function withdrawnDividendOf(address _owner) external view returns (uint256);

  function accumulativeDividendOf(address _owner) external view returns (uint256);
}

/// @title Dividend-Paying Token
/// @author Roger Wu (https://github.com/roger-wu)
/// @dev A mintable ERC20 token that allows anyone to pay and distribute ether
/// to token holders as dividends and allows token holders to withdraw their dividends.
/// Reference: the source code of PoWH3D: https://etherscan.io/address/0xB3775fB83F7D12A36E0475aBdD1FCA35c091efBe#code
contract DividendPayingToken is TruncatedERC20, DividendPayingTokenInterface, DividendPayingTokenOptionalInterface {
  using SafeMathUint for uint256;
  using SafeMathInt for int256;

  uint256 constant internal magnitude = 2**128;

  uint256 internal magnifiedDividendPerShare;

  mapping(address => int256) internal magnifiedDividendCorrections;
  mapping(address => uint256) internal withdrawnDividends;

  uint256 public totalDividendsDistributed;

  constructor(string memory _name, string memory _symbol) TruncatedERC20(_name, _symbol) {}

  receive() external payable {
    distributeDividends();
  }

  function distributeDividends() public payable {
    require(totalSupply() > 0);

    if (msg.value > 0) {
      magnifiedDividendPerShare = magnifiedDividendPerShare + (msg.value * magnitude / totalSupply());

      emit DividendsDistributed(msg.sender, msg.value);

      totalDividendsDistributed = totalDividendsDistributed + msg.value;
    }
  }

  function _withdrawDividend(address account) internal returns(uint256) {
    uint256 withdrawableDividend = withdrawableDividendOf(account);

    if (withdrawableDividend > 0) {
      withdrawnDividends[account] = withdrawnDividends[account] + withdrawableDividend;

      bool success = payable(account).send(withdrawableDividend);
     
      if (success) {
        emit DividendWithdrawn(account, withdrawableDividend);
        return withdrawableDividend;
      } else {
        withdrawnDividends[account] = withdrawnDividends[account] - withdrawableDividend;
      }
    }

    return 0;
  }

  function dividendOf(address account) public view override returns(uint256) {
    return withdrawableDividendOf(account);
  }

  function withdrawableDividendOf(address account) public view override returns(uint256) {
    return accumulativeDividendOf(account) - withdrawnDividends[account];
  }

  function withdrawnDividendOf(address account) public view override returns(uint256) {
    return withdrawnDividends[account];
  }

  function accumulativeDividendOf(address account) public view override returns(uint256) {
    return ((magnifiedDividendPerShare * balanceOf(account)).toInt256Safe() + magnifiedDividendCorrections[account]).toUint256Safe() / magnitude;
  }

  function _mint(address account, uint256 value) internal override {
    super._mint(account, value);

    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account] - (magnifiedDividendPerShare * value).toInt256Safe();
  }

  function _burn(address account, uint256 value) internal override {
    super._burn(account, value);

    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account] + (magnifiedDividendPerShare * value).toInt256Safe();
  }

  function _setBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf(account);

    if (newBalance > currentBalance) _mint(account, newBalance - currentBalance);
    else if (newBalance < currentBalance) _burn(account, currentBalance - newBalance);
  }
}

library IterableMapping {
  // Iterable mapping from address to uint;
  struct Map {
    address[] keys;
    mapping(address => uint) values;
    mapping(address => uint) indexOf;
    mapping(address => bool) inserted;
  }

  function get(Map storage map, address key) public view returns (uint) {
    return map.values[key];
  }

  function getIndexOfKey(Map storage map, address key) public view returns (int) {
    if(!map.inserted[key]) {
        return -1;
    }
    return int(map.indexOf[key]);
  }

  function getKeyAtIndex(Map storage map, uint index) public view returns (address) {
    return map.keys[index];
  }

  function size(Map storage map) public view returns (uint) {
    return map.keys.length;
  }

  function set(Map storage map, address key, uint val) public {
    if (map.inserted[key]) {
      map.values[key] = val;
    } else {
      map.inserted[key] = true;
      map.values[key] = val;
      map.indexOf[key] = map.keys.length;
      map.keys.push(key);
    }
  }

  function remove(Map storage map, address key) public {
    if (!map.inserted[key]) {
      return;
    }

    delete map.inserted[key];
    delete map.values[key];

    uint index = map.indexOf[key];
    uint lastIndex = map.keys.length - 1;
    address lastKey = map.keys[lastIndex];

    map.indexOf[lastKey] = index;
    delete map.indexOf[key];

    map.keys[index] = lastKey;
    map.keys.pop();
  }
}

contract DividendTracker is Ownable, DividendPayingToken {
  using IterableMapping for IterableMapping.Map;

  IterableMapping.Map private tokenHoldersMap;
  uint256 public lastProcessedIndex;

  mapping(address => bool) public isExcludedFromDividends;
  mapping(address => uint256) public lastClaimTimes;

  uint256 public claimWait;
  uint256 public minimumTokenBalanceForDividends;

  event ExcludeFromDividends(address indexed account, bool isExcluded);
  event ClaimWaitUpdated(uint256 claimWait);
  event ProcessedDividendTracker(uint256 iterations, uint256 claims);

  constructor(uint256 _claimWait, uint256 _minimumTokenBalance) DividendPayingToken("DividendTracker", "DividendTracker") {
    claimWaitSetup(_claimWait);
    minimumTokenBalanceForDividends = _minimumTokenBalance;
  }

  function excludeFromDividends(address account, uint256 balance, bool isExcluded) external onlyOwner {
    if (isExcluded) {
      require(!isExcludedFromDividends[account], "DividendTracker: This address is already excluded from dividends");
      isExcludedFromDividends[account] = true;

      _setBalance(account, 0);
      tokenHoldersMap.remove(account);
    } else {
      require(isExcludedFromDividends[account], "DividendTracker: This address is already included in dividends");
      isExcludedFromDividends[account] = false;

      setBalance(account, balance);
    }

    emit ExcludeFromDividends(account, isExcluded);
  }

  function claimWaitSetup(uint256 newClaimWait) public onlyOwner {
    require(newClaimWait >= 60 && newClaimWait <= 7 days, "DividendTracker: Claim wait time must be between 1 minute and 7 days");

    claimWait = newClaimWait;

    emit ClaimWaitUpdated(newClaimWait);
  }

  function getNumberOfTokenHolders() external view returns (uint256) {
    return tokenHoldersMap.keys.length;
  }

  function getAccountData(address _account) public view returns (
      address account,
      int256 index,
      int256 iterationsUntilProcessed,
      uint256 withdrawableDividends,
      uint256 totalDividends,
      uint256 lastClaimTime,
      uint256 nextClaimTime,
      uint256 secondsUntilAutoClaimAvailable
    )
  {
    account = _account;
    index = tokenHoldersMap.getIndexOfKey(account);
    iterationsUntilProcessed = -1;

    if (index >= 0) {
      if (uint256(index) > lastProcessedIndex) {
        iterationsUntilProcessed = index - int256(lastProcessedIndex);
      } else {
        uint256 processesUntilEndOfArray = tokenHoldersMap.keys.length > lastProcessedIndex ? tokenHoldersMap.keys.length - lastProcessedIndex : 0;
        iterationsUntilProcessed = index + int256(processesUntilEndOfArray);
      }
    }

    withdrawableDividends = withdrawableDividendOf(account);
    totalDividends = accumulativeDividendOf(account);
    lastClaimTime = lastClaimTimes[account];
    nextClaimTime = lastClaimTime > 0 ? lastClaimTime + claimWait : 0;
    secondsUntilAutoClaimAvailable = nextClaimTime > block.timestamp ? nextClaimTime - block.timestamp : 0;
  }

  function getAccountDataAtIndex(uint256 index) public view returns (
      address,
      int256,
      int256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    )
  {
    if (index >= tokenHoldersMap.size()) return (address(0), -1, -1, 0, 0, 0, 0, 0);

    address account = tokenHoldersMap.getKeyAtIndex(index);

    return getAccountData(account);
  }

  function claim(address account) public onlyOwner returns (bool) {
    uint256 amount = _withdrawDividend(account);

    if (amount > 0) {
      lastClaimTimes[account] = block.timestamp;
      return true;
    }
    return false;
  }

  function _canAutoClaim(uint256 lastClaimTime) private view returns (bool) {
    if (block.timestamp < lastClaimTime) return false;
    
    return block.timestamp - lastClaimTime >= claimWait;
  }

  function setBalance(address account, uint256 newBalance) public onlyOwner {
    if (!isExcludedFromDividends[account]) {

      if (newBalance >= minimumTokenBalanceForDividends) {
        _setBalance(account, newBalance);
        tokenHoldersMap.set(account, newBalance);
      } else {
        _setBalance(account, 0);
        tokenHoldersMap.remove(account);
      }

    }
  }

  function process(uint256 gas) external onlyOwner returns(uint256 iterations, uint256 claims) {
    uint256 numberOfTokenHolders = tokenHoldersMap.keys.length;

    if (numberOfTokenHolders == 0) return (0, 0);

    uint256 _lastProcessedIndex = lastProcessedIndex;
    uint256 gasUsed = 0;
    uint256 gasLeft = gasleft();

    iterations = 0;
    claims = 0;

    while (gasUsed < gas && iterations < numberOfTokenHolders) {
      _lastProcessedIndex++;

      if (_lastProcessedIndex >= tokenHoldersMap.keys.length) _lastProcessedIndex = 0;

      address account = tokenHoldersMap.keys[_lastProcessedIndex];

      if (_canAutoClaim(lastClaimTimes[account])) {
        if (claim(account)) {
          claims++;
        }
      }

      iterations++;

      uint256 newGasLeft = gasleft();

      if (gasLeft > newGasLeft) gasUsed = gasUsed + (gasLeft - newGasLeft);

      gasLeft = newGasLeft;
    }

    lastProcessedIndex = _lastProcessedIndex;

    emit ProcessedDividendTracker(iterations, claims);
  }
}

abstract contract DividendTrackerFunctions is Ownable2Step {
  DividendTracker public dividendTracker;

  uint256 public gasForProcessing;

  event DeployedDividendTracker(address indexed dividendTracker);
  event GasForProcessingUpdated(uint256 gasForProcessing);

  function _deployDividendTracker(uint256 claimWait, uint256 minimumTokenBalance) internal {
    dividendTracker = new DividendTracker(claimWait, minimumTokenBalance);

    emit DeployedDividendTracker(address(dividendTracker));
  }

  function gasForProcessingSetup(uint256 _gasForProcessing) public onlyOwner {
    require(_gasForProcessing >= 200_000 && _gasForProcessing <= 500_000, "DividendTracker: gasForProcessing must be between 200k and 500k units");
    
    gasForProcessing = _gasForProcessing;

    emit GasForProcessingUpdated(_gasForProcessing);
  }

  function claimWaitSetup(uint256 claimWait) external onlyOwner {
    dividendTracker.claimWaitSetup(claimWait);
  }

  function _excludeFromDividends(address account, bool isExcluded) internal virtual;

  function isExcludedFromDividends(address account) public view returns (bool) {
    return dividendTracker.isExcludedFromDividends(account);
  }

  function claim() external returns(bool) {
    return dividendTracker.claim(msg.sender);
  }
  
  function getClaimWait() external view returns (uint256) {
    return dividendTracker.claimWait();
  }

  function getTotalDividendsDistributed() external view returns (uint256) {
    return dividendTracker.totalDividendsDistributed();
  }

  function withdrawableDividendOf(address account) public view returns (uint256) {
    return dividendTracker.withdrawableDividendOf(account);
  }

  function dividendTokenBalanceOf(address account) public view returns (uint256) {
    return dividendTracker.balanceOf(account);
  }

  function dividendTokenTotalSupply() public view returns (uint256) {
    return dividendTracker.totalSupply();
  }

  function getAccountDividendsInfo(address account) external view returns (
      address,
      int256,
      int256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    ) {
    return dividendTracker.getAccountData(account);
  }

  function getAccountDividendsInfoAtIndex(uint256 index) external view returns (
      address,
      int256,
      int256,
      uint256,
      uint256,
      uint256,
      uint256,
      uint256
    ) {
    return dividendTracker.getAccountDataAtIndex(index);
  }

  function getLastProcessedIndex() external view returns (uint256) {
    return dividendTracker.lastProcessedIndex();
  }

  function getNumberOfDividendTokenHolders() public view returns (uint256) {
    return dividendTracker.getNumberOfTokenHolders();
  }

  function process(uint256 gas) external returns(uint256 iterations, uint256 claims) {
    return dividendTracker.process(gas);
  }
}