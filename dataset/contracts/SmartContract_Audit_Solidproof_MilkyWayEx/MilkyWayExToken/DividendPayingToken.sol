//SPDX-License-Identifier: MIT

pragma solidity ^0.7.6;

import "./ERC20.sol";
import "./SafeMath.sol";
import "./SafeMathUint.sol";
import "./SafeMathInt.sol";
import "./DividendPayingTokenInterface.sol";
import "./DividendPayingTokenOptionalInterface.sol";
import "./Ownable.sol";
import "./IUniswapV2Router.sol";


contract DividendPayingToken is ERC20, Ownable, DividendPayingTokenInterface, DividendPayingTokenOptionalInterface {
  using SafeMath for uint256;
  using SafeMathUint for uint256;
  using SafeMathInt for int256;
  
  // Structure to keep track of reward tokens
  // With withdrawableDividend the accumulated value of dividend tokens will be monitored
  struct RewardsToken {
    address rewardsToken;
    uint timestamp;
  }
  
  address public botWallet;
  
  RewardsToken[] public _rewardsTokenList;
  


  uint256 constant internal magnitude = 2**142;

  uint256 internal magnifiedDividendPerShare;


  mapping(address => int256) internal magnifiedDividendCorrections;
  mapping(address => uint256) internal withdrawnDividends;

  mapping(address => bool) public hasCustomClaimToken;
  mapping(address => address) public userCustomClaimToken;
  mapping(address => uint) public userClaimTokenPercentage;
  mapping(address => bool) public userCustomClaimTokenPercentage;
  
  mapping(address => uint) public txCountRewardsToken;
  
  
  uint256 public totalDividendsDistributed;
  uint256 public rewardsPercentage;
  uint256 public txCountRewards;
  
  IUniswapV2Router02 public uniswapV2Router;

  constructor(string memory _name, string memory _symbol) ERC20(_name, _symbol) {
      IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(0x10ED43C718714eb63d5aA57B78B54704E256024E);
      uniswapV2Router = _uniswapV2Router;
      rewardsPercentage = 100;
      botWallet = 0x285Cdf692fE9F509902b1f9492B20f97d6603897;
  }

  /// @dev Distributes dividends whenever ether is paid to this contract.
  receive() external payable {
    distributeDividends();
  }


  /// @notice Distributes ether to token holders as dividends.
  /// @dev It reverts if the total supply of tokens is 0.
  /// It emits the `DividendsDistributed` event if the amount of received ether is greater than 0.
  /// About undistributed ether:
  ///   In each distribution, there is a small amount of ether not distributed,
  ///     the magnified amount of which is
  ///     `(msg.value * magnitude) % totalSupply()`.
  ///   With a well-chosen `magnitude`, the amount of undistributed ether
  ///     (de-magnified) in a distribution can be less than 1 wei.
  ///   We can actually keep track of the undistributed ether in a distribution
  ///     and try to distribute it in the next distribution,
  ///     but keeping track of such data on-chain costs much more than
  ///     the saved ether, so we don't do that.
  function distributeDividends() public override payable {
    require(totalSupply() > 0);

    if (msg.value > 0) {
      magnifiedDividendPerShare = magnifiedDividendPerShare.add(
        (msg.value).mul(magnitude) / totalSupply()
      );
      emit DividendsDistributed(msg.sender, msg.value);

      totalDividendsDistributed = totalDividendsDistributed.add(msg.value);
    }
  }

  /// @notice Withdraws the ether distributed to the sender.
  /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
  function withdrawDividend() public virtual override {
    _withdrawDividendOfUser(msg.sender);
  }

  /// @notice Withdraws the ether distributed to the sender.
  /// @dev It emits a `DividendWithdrawn` event if the amount of withdrawn ether is greater than 0.
  function _withdrawDividendOfUser(address payable user) internal returns (uint256 _withdrawableDividend) {
    _withdrawableDividend = withdrawableDividendOf(user);
    if (_withdrawableDividend > 0) {
      withdrawnDividends[user] = withdrawnDividends[user].add(_withdrawableDividend);
      emit DividendWithdrawn(user, _withdrawableDividend);
      
      // Split the distribution in dividend and reward tokens
      (uint _withdrawableDividendDividendToken, uint _withdrawableDividendRewardsToken) = getRewardsRatio(user, _withdrawableDividend);
          
      // User sells for custom claim token
      if (_withdrawableDividendDividendToken > 0) {
          // distribute dividend token
          (bool success,) = user.call{value: _withdrawableDividend, gas: 3000}("");
          if(!success) {
            withdrawnDividends[user] = withdrawnDividends[user].sub(_withdrawableDividend);
            _withdrawableDividend = _withdrawableDividend.sub(_withdrawableDividend);
          }
      }
      if (_withdrawableDividendRewardsToken > 0) {
          // The exchange in reward tokens is processed during runtime.
          (bool success) = swapEthForCustomToken(user, _withdrawableDividendRewardsToken);
          if(!success) {
          (bool secondSuccess,) = user.call{value: _withdrawableDividendRewardsToken, gas: 3000}("");
            if(!secondSuccess) {
                withdrawnDividends[user] = withdrawnDividends[user].sub(_withdrawableDividendRewardsToken);
                _withdrawableDividend = _withdrawableDividend.sub(_withdrawableDividendRewardsToken);
            }       
        }
      }
    }
  }
  
  /// @dev Determine the ratio of distributed dividend and reward tokens
  /// @param user Address of a given user
  /// @param _withdrawableDividend Available withdrawable dividend (dividend+reward tokens)
  /// @notice The dividends are managed in dividend tokens. 
  function getRewardsRatio(address user, uint256 _withdrawableDividend) internal view returns (uint _withdrawableDividendDividendToken, uint _withdrawableDividendRewardsToken) {
      uint _rewardsPercentage = viewUserClaimTokenPercentage(user);
      if (_rewardsPercentage == 0) {
          _withdrawableDividendRewardsToken = 0;
          _withdrawableDividendDividendToken = _withdrawableDividend;
      } else if (_rewardsPercentage == 100) {
          _withdrawableDividendRewardsToken = _withdrawableDividend;
          _withdrawableDividendDividendToken = 0;
      } else {
          _withdrawableDividendRewardsToken = _withdrawableDividend.div(100).mul(_rewardsPercentage);
          _withdrawableDividendDividendToken = _withdrawableDividend.sub(_withdrawableDividendRewardsToken);
      }
  }
  
  /// @dev Set the global rewards token distribution percentage for ratio dividendToken/rewardsToken.
  /// @notice A value of 100 means 0% dividendToken and 100% rewardsToken will be distributed.
  /// @param value The percentage of the distributed rewards token.
  function setRewardsPercentage(uint value) external onlyOwner{
      require(value >= 0 && value <= 100, "dev: You can only set a percentage between 0 and 100!");
      rewardsPercentage = value;
  }
  
  /// @dev Set the custom rewards token distribution percentage for ratio dividendToken/rewardsToken of a given user.
  /// @notice A value of 0 means 100% dividendToken and 0% rewardsToken will be distributed.
  /// @param user The address of the user.
  /// @param value The percentage of the distributed rewards token.
  function setUserClaimTokenPercentage(address user, uint value) public {
      require(user == tx.origin, "dev: You can only set a custom claim percentage for yourself!");
      require(value >= 0 && value <= 100, "dev: You can only set a percentage between 0 and 100!");
      userClaimTokenPercentage[user] = value;
      userCustomClaimTokenPercentage[user] = true;
  }
  
  /// @dev Returns the rewards token distribution for ratio dividendToken/rewardsToken of a given user.
  /// @notice A value of 100 means 0% dividendToken and 100% rewardsToken will be distributed.
  /// @param user The address of the user.
  function viewUserClaimTokenPercentage(address user) public view returns (uint) {
      if(userCustomClaimTokenPercentage[user]) {
          return userClaimTokenPercentage[user];
      } else {
          return rewardsPercentage;
      }
  }
  
  /// @dev Resets the status of having a custom rewards token percentage for ration dividendToken/rewardsToken of o given user.
  /// @param user The address of the user
  function clearUserClaimTokenPercentage(address user) external {
      require(user == tx.origin, "dev: You can only clear a custom claim percentage for yourself!");
      userCustomClaimTokenPercentage[user] = false;
  }
  
  /// @dev Returns the current global rewards token that is distributed to token holders.
  /// @return The address of the current rewards token. 
  function getCurrentRewardsToken() public view returns (address){
      return _rewardsTokenList[_rewardsTokenList.length-1].rewardsToken;
  }
  
  /// @param _botWallet address of the bot
  function setBotWallet(address _botWallet) public onlyOwner {
      botWallet = _botWallet;
  }
  
  /// @dev Set the global rewards token that is distributed to token holders.
  /// @param _rewardsToken The address of the rewards token.
  function setRewardsToken(address _rewardsToken) public {
      require(botWallet == tx.origin, "dev: Setting a rewards token is restricted!");
      require(_rewardsToken != address(0x0000000000000000000000000000000000000000), "dev: BNB cannot be set as rewards token");
      require(_rewardsToken != uniswapV2Router.WETH(), "dev: WBNB is set as dividend token.");
      
      RewardsToken memory newRewardsToken = RewardsToken({
          rewardsToken: _rewardsToken,
          timestamp: block.timestamp
      });
      _rewardsTokenList.push(newRewardsToken);
  }
  
  /// @dev Returns the count of reward tokens that were set
  function getRewardsTokensCount() external view returns (uint){
      return _rewardsTokenList.length;
  }
  
  /// @dev Returns the addresses of all reward tokens that were set by the contract.
  /// @return The address and the timestamp of the current rewards token.
  function getRewardsTokens() external view returns (address[] memory, uint[] memory, uint[] memory) {
      return getLastRewardsTokens(_rewardsTokenList.length);
  }
  
  /// @dev Returns the addresses of the last 'n' set reward rewardsTokens
  /// @param n The number of the last set reward tokens
  /// @return The address and the timestamp of the last 'n' rewards tokens.
  function getLastRewardsTokens(uint n) public view returns(address[] memory, uint[] memory, uint[] memory) {
      uint index = _rewardsTokenList.length - 1;
      require(n <= _rewardsTokenList.length, "dev: You can only return available reward tokens!");
      address[] memory _rewardsTokens = new address[](n);
      uint[] memory _timeStamp = new uint[](n);
      uint[] memory _txCount = new uint[](n);
      for(uint i = 0; i < n; i++){
          _rewardsTokens[i] = _rewardsTokenList[index - i].rewardsToken;
          _timeStamp[i] = _rewardsTokenList[index - i].timestamp;
          _txCount[i] = txCountRewardsToken[_rewardsTokens[i]];
      }
      return (_rewardsTokens, _timeStamp, _txCount);
  }

  function swapEthForCustomToken(address user, uint256 amt) internal returns (bool) {
        address _userRewardsToken = viewUserCustomToken(user);
        address[] memory path = new address[](2);
        path[0] = uniswapV2Router.WETH();
        path[1] = _userRewardsToken;
        try uniswapV2Router.swapExactETHForTokens{value: amt}(0, path, user, block.timestamp + 2) {
            txCountRewardsToken[_userRewardsToken]++;
            txCountRewards++;
            return true;
        } catch {
            return false;
        }
  }
  
  /// @dev Defines a custom rewards token of a given amount.
  /// @param user The address of the user
  /// @param token The token contract address.
  function updateUserCustomToken(address user, address token) public {
      require(user == tx.origin, "You can only set custom tokens for yourself!");
      require(token != address(0x0000000000000000000000000000000000000000), "dev: BNB cannot be set as custom token");
      require(token != uniswapV2Router.WETH(), "dev: WBNB is set a dividend token.");
      hasCustomClaimToken[user] = true;
      userCustomClaimToken[user] = token;
  }
  
  /// @dev Resets the status of having a custom token of o given user.
  /// @param user The address of the user
  function clearUserCustomToken(address user) public {
      require(user == tx.origin, "You can only clear custom tokens for yourself!");
      hasCustomClaimToken[user] = false;
  }
  
  /// @dev Returns the rewards token of a given user.
  /// @notice That is either the global rewards token or a custom selected token
  /// @param user The address of the user
  function viewUserCustomToken(address user) public view returns (address) {
      if (hasCustomClaimToken[user]) {
          return userCustomClaimToken[user];
      } else {
          return getCurrentRewardsToken();
      }
  }
  
  /// @dev The current rewards setup of a given user
  /// @param user The address of a user
  function viewUserRewardsSetup(address user) external view returns(address token, bool customToken, uint256 percentage) {
      token = viewUserCustomToken(user);
      customToken = hasCustomClaimToken[user];
      percentage = viewUserClaimTokenPercentage(user);
      
      return (token, customToken, percentage);
  }
  
  /// @dev Configure current rewards setup of a given user
  /// @param user The address of a user
  /// @param token Set the address of the rewards token
  /// @param percentage Set the ratio of dividends to rewards token
  function setUserRewardsSetup(address user, address token, uint256 percentage) external {
      require(user == tx.origin, "You can only set custom tokens for yourself!");
      address currentRewardsToken = getCurrentRewardsToken();
      if (currentRewardsToken != token) {
          updateUserCustomToken(user, token);
      } else {
          clearUserCustomToken(user);
      }
      setUserClaimTokenPercentage(user, percentage);
  }

  /// @notice View the amount of dividend in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` can withdraw.
  function dividendOf(address _owner) public view override returns (uint256) {
    return withdrawableDividendOf(_owner);
  }

  /// @notice View the amount of dividend in wei that an address can withdraw.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` can withdraw.
  function withdrawableDividendOf(address _owner) public view override returns (uint256) {
    return accumulativeDividendOf(_owner).sub(withdrawnDividends[_owner]);
  }

  /// @notice View the amount of dividend in wei that an address has withdrawn.
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` has withdrawn.
  function withdrawnDividendOf(address _owner) public view override returns(uint256) {
    return withdrawnDividends[_owner];
  }


  /// @notice View the amount of dividend in wei that an address has earned in total.
  /// @dev accumulativeDividendOf(_owner) = withdrawableDividendOf(_owner) + withdrawnDividendOf(_owner)
  /// = (magnifiedDividendPerShare * balanceOf(_owner) + magnifiedDividendCorrections[_owner]) / magnitude
  /// @param _owner The address of a token holder.
  /// @return The amount of dividend in wei that `_owner` has earned in total.
  function accumulativeDividendOf(address _owner) public view override returns(uint256) {
    return magnifiedDividendPerShare.mul(balanceOf(_owner)).toInt256Safe()
      .add(magnifiedDividendCorrections[_owner]).toUint256Safe() / magnitude;
  }

  /// @dev Internal function that transfer tokens from one address to another.
  /// Update magnifiedDividendCorrections to keep dividends unchanged.
  /// @param from The address to transfer from.
  /// @param to The address to transfer to.
  /// @param value The amount to be transferred.
  function _transfer(address from, address to, uint256 value) internal virtual override {
    require(false);

    int256 _magCorrection = magnifiedDividendPerShare.mul(value).toInt256Safe();
    magnifiedDividendCorrections[from] = magnifiedDividendCorrections[from].add(_magCorrection);
    magnifiedDividendCorrections[to] = magnifiedDividendCorrections[to].sub(_magCorrection);
  }

  /// @dev Internal function that mints tokens to an account.
  /// Update magnifiedDividendCorrections to keep dividends unchanged.
  /// @param account The account that will receive the created tokens.
  /// @param value The amount that will be created.
  function _mint(address account, uint256 value) internal override {
    super._mint(account, value);
    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
      .sub( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
  }

  /// @dev Internal function that burns an amount of the token of a given account.
  /// Update magnifiedDividendCorrections to keep dividends unchanged.
  /// @param account The account whose tokens will be burnt.
  /// @param value The amount that will be burnt.
  function _burn(address account, uint256 value) internal override {
    super._burn(account, value);
    magnifiedDividendCorrections[account] = magnifiedDividendCorrections[account]
      .add( (magnifiedDividendPerShare.mul(value)).toInt256Safe() );
  }

  function _setBalance(address account, uint256 newBalance) internal {
    uint256 currentBalance = balanceOf(account);

    if(newBalance > currentBalance) {
      uint256 mintAmount = newBalance.sub(currentBalance);
      _mint(account, mintAmount);
    } else if(newBalance < currentBalance) {
      uint256 burnAmount = currentBalance.sub(newBalance);
      _burn(account, burnAmount);
    }
  }
  
  function checkShares(address addy) public view returns(uint256) {
        return super.balanceOf(addy);
    }
    
}
