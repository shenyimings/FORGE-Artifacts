// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../openzeppelin/SafeERC20.sol";
import "../openzeppelin/ReentrancyGuard.sol";
import "../openzeppelin/EnumerableSet.sol";
import "../openzeppelin/Math.sol";
import "../interfaces/ITetuLiquidator.sol";
import "../interfaces/IVoter.sol";
import "../interfaces/IForwarder.sol";
import "../interfaces/IMultiPool.sol";
import "../interfaces/IBribe.sol";
import "../proxy/ControllableV3.sol";

/// @title This contract should contains a buffer of fees from strategies.
///        Periodically sell rewards and distribute to their destinations.
/// @author belbix
contract ForwarderV3 is ReentrancyGuard, ControllableV3, IForwarder {
  using SafeERC20 for IERC20;
  using EnumerableSet for EnumerableSet.AddressSet;

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************
  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant FORWARDER_VERSION = "3.0.0";
  /// @dev Denominator for different ratios. It is default for the whole platform.
  uint public constant RATIO_DENOMINATOR = 100_000;
  /// @dev If slippage not defined for concrete token will be used 5% tolerance.
  uint public constant DEFAULT_SLIPPAGE = 5_000;
  /// @dev Max handled destinations from queue per call.
  uint public constant MAX_DESTINATIONS = 50;

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  // -- ratios

  /// @dev Percent of tokens for Invest Fund
  uint public toInvestFundRatio;
  /// @dev Percent of tokens for gauges.
  uint public toGaugesRatio;

  // -- convert options

  /// @dev We will convert all tokens to TETU and distribute to destinations.
  address public tetu;
  /// @dev Contract for bribes distribution
  address public bribe;
  /// @dev Minimum amount of TETU tokens for distribution.
  uint public tetuThreshold;
  /// @dev Specific slippages for volatile tokens.
  mapping(address => uint) public tokenSlippage;

  // -- registered destinations

  /// @dev Tokens ready for distribution
  ///      This Set need for easy handle tokens off-chain, can be removed for gas optimisation.
  EnumerableSet.AddressSet internal _queuedTokens;
  /// @dev Token => Set of destinations with positive balances for the given token
  mapping(address => EnumerableSet.AddressSet) internal _destinationQueue;
  /// @dev Destination => Tokens ready to distribute
  mapping(address => EnumerableSet.AddressSet) internal _tokensPerDestination;
  /// @dev Token => Destination => Registered amount
  mapping(address => mapping(address => uint)) public amountPerDestination;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event Distributed(
    address sender,
    address incomeToken,
    uint queuedBalance,
    uint tetuValue,
    uint tetuBalance,
    uint toInvestFund,
    uint toGauges,
    uint toBribes
  );
  event InvestFundRatioChanged(uint oldValue, uint newValue);
  event GaugeRatioChanged(uint oldValue, uint newValue);
  event TetuThresholdChanged(uint oldValue, uint newValue);
  event SlippageChanged(address token, uint value);

  // *************************************************************
  //                        INIT
  // *************************************************************

  /// @dev Proxy initialization. Call it after contract deploy.
  function init(address controller_, address _tetu, address _bribe) external initializer {
    _requireInterface(_bribe, InterfaceIds.I_BRIBE);
    _requireERC20(_tetu);
    __Controllable_init(controller_);
    tetu = _tetu;
    bribe = _bribe;
    // 10k TETU by default
    tetuThreshold = 10_000 * 1e18;
  }

  // *************************************************************
  //                      GOV ACTIONS
  // *************************************************************

  /// @dev Check that sender is governance.
  function _onlyGov() internal view {
    require(isGovernance(msg.sender), "DENIED");
  }

  /// @dev Set specific token slippage for given token.
  function setSlippage(address token, uint value) external {
    _onlyGov();
    require(value < RATIO_DENOMINATOR, "TOO_HIGH");

    tokenSlippage[token] = value;
    emit SlippageChanged(token, value);
  }

  /// @dev Set TETU threshold for distribution.
  function setTetuThreshold(uint value) external {
    _onlyGov();

    emit TetuThresholdChanged(tetuThreshold, value);
    tetuThreshold = value;
  }

  // *************************************************************
  //                     VOTER ACTIONS
  // *************************************************************

  /// @dev Check that sender is platform voter.
  function _onlyPlatformVoter() internal view {
    require(msg.sender == IController(controller()).platformVoter(), "DENIED");
  }

  /// @dev veTETU holders can change proportion via special voter.
  function setInvestFundRatio(uint value) external override {
    _onlyPlatformVoter();
    require(value <= RATIO_DENOMINATOR, "TOO_HIGH");

    emit InvestFundRatioChanged(toInvestFundRatio, value);
    toInvestFundRatio = value;
  }

  /// @dev veTETU holders can change proportion via special voter.
  function setGaugesRatio(uint value) external override {
    _onlyPlatformVoter();
    require(value <= RATIO_DENOMINATOR, "TOO_HIGH");

    emit GaugeRatioChanged(toGaugesRatio, value);
    toGaugesRatio = value;
  }

  // *************************************************************
  //                         VIEWS
  // *************************************************************

  /// @dev Size of array of tokens ready for distribution.
  function queuedTokensLength() external view returns (uint) {
    return _queuedTokens.length();
  }

  /// @dev Return queued token address for given id. Ordering can be changed between calls!
  function queuedTokenAt(uint i) external view returns (address) {
    return _queuedTokens.at(i);
  }

  /// @dev Size of array of tokens ready for distribution for given destination.
  function tokenPerDestinationLength(address destination) public view override returns (uint) {
    return _tokensPerDestination[destination].length();
  }

  /// @dev Return queued token address for given id and destination. Ordering can be changed between calls!
  function tokenPerDestinationAt(address destination, uint i) external view override returns (address) {
    return _tokensPerDestination[destination].at(i);
  }

  /// @dev Size of array of destinations for distribution for given token.
  function destinationsLength(address incomeToken) external view returns (uint) {
    return _destinationQueue[incomeToken].length();
  }

  /// @dev Return destination for given income token. Ordering can be changed between calls!
  function destinationAt(address incomeToken, uint i) external view returns (address) {
    return _destinationQueue[incomeToken].at(i);
  }

  /// @dev In case of too many queued destinations `targetTokenThreshold` should be lowered to reasonable value.
  function getQueuedDestinations(address token) public view returns (
    address[] memory queuedDestinations,
    uint[] memory queuedAmounts,
    uint balance
  ){
    EnumerableSet.AddressSet storage destinations = _destinationQueue[token];
    mapping(address => uint) storage tokenPerDst = amountPerDestination[token];
    uint length = Math.min(destinations.length(), MAX_DESTINATIONS);

    queuedDestinations = new address[](length);
    queuedAmounts = new uint[](length);
    balance = 0;
    for (uint i; i < length; ++i) {
      address destination = destinations.at(i);
      queuedDestinations[i] = destination;
      uint amount = tokenPerDst[destination];
      balance += amount;
      queuedAmounts[i] = amount;
    }
  }

  // *************************************************************
  //                     REGISTER INCOME
  // *************************************************************

  /// @dev Strategy should call this on reward liquidation after compound part.
  ///      Register tokens for the given destination.
  function registerIncome(
    address[] memory tokens,
    uint[] memory amounts,
    address vaults,
    bool isDistribute
  ) external nonReentrant override {

    for (uint i; i < tokens.length; ++i) {
      address token = tokens[i];
      uint amount = amounts[i];
      IERC20(token).safeTransferFrom(msg.sender, address(this), amount);

      amountPerDestination[token][vaults] += amount;
      // suppose to be not unique, relatively cheap
      _destinationQueue[token].add(vaults);
      _tokensPerDestination[vaults].add(token);
      _queuedTokens.add(token);
    }

    // call it on cheap network
    if (isDistribute) {
      _distributeAll(vaults);
    }
  }

  // *************************************************************
  //                      DISTRIBUTE
  // *************************************************************

  function distributeAll(address destination) external nonReentrant override {
    _distributeAll(destination);
  }

  function _distributeAll(address destination) internal {
    address[] memory tokens = _tokensPerDestination[destination].values();
    uint length = tokens.length;
    for (uint i; i < length; ++i) {
      _distribute(tokens[i]);
    }
  }

  /// @dev Try to distribute given income token using  a target token from converter.
  ///      No strict access.
  ///      We assume that amount will be distributed before accumulate huge value reasonable for arbitrage attack.
  function distribute(address incomeToken) external nonReentrant override {
    _distribute(incomeToken);
  }

  function _distribute(address incomeToken) internal {

    (address[] memory vaults, uint[] memory queuedAmounts, uint queuedBalance)
    = getQueuedDestinations(incomeToken);

    IController controller_ = IController(controller());
    address _tetu = tetu;

    (uint tetuBalance, uint tetuValue) = _liquidate(controller_, incomeToken, _tetu, queuedBalance);

    if (tetuBalance != 0) {
      uint toInvestFund = tetuBalance * toInvestFundRatio / RATIO_DENOMINATOR;
      uint toGauges = (tetuBalance - toInvestFund) * toGaugesRatio / RATIO_DENOMINATOR;
      uint toBribes = (tetuBalance - toInvestFund) - toGauges;

      if (toInvestFund != 0) {
        IERC20(_tetu).safeTransfer(controller_.investFund(), toInvestFund);
      }

      if (toGauges != 0) {
        address voter = controller_.voter();
        IERC20(_tetu).safeApprove(voter, toGauges);
        IVoter(voter).notifyRewardAmount(toGauges);
      }

      if (toBribes != 0) {
        _distributeToBribes(
          incomeToken,
          _tetu,
          vaults,
          queuedAmounts,
          queuedBalance,
          toBribes
        );
      }

      emit Distributed(
        msg.sender,
        incomeToken,
        queuedBalance,
        tetuValue,
        tetuBalance,
        toInvestFund,
        toGauges,
        toBribes
      );
    }
  }

  function _liquidate(
    IController controller_,
    address tokenIn,
    address _tetu,
    uint amount
  ) internal returns (uint boughtTetu, uint tetuValue) {

    if (tokenIn == _tetu) {
      return (amount, amount);
    }

    boughtTetu = 0;
    ITetuLiquidator _liquidator = ITetuLiquidator(controller_.liquidator());

    (ITetuLiquidator.PoolData[] memory route, string memory error)
    = _liquidator.buildRoute(tokenIn, _tetu);

    if (route.length == 0) {
      revert(error);
    }

    // calculate balance in tetu value for check threshold
    tetuValue = _liquidator.getPriceForRoute(route, amount);

    // if the value higher than threshold distribute to destinations
    if (tetuValue > tetuThreshold) {

      uint slippage = tokenSlippage[tokenIn];
      if (slippage == 0) {
        slippage = DEFAULT_SLIPPAGE;
      }

      uint tetuBalanceBefore = IERC20(_tetu).balanceOf(address(this));

      _approveIfNeed(tokenIn, address(_liquidator), amount);
      _liquidator.liquidateWithRoute(route, amount, slippage);

      boughtTetu = IERC20(_tetu).balanceOf(address(this)) - tetuBalanceBefore;
    }
  }

  // *************************************************************
  //                      INTERNAL LOGIC
  // *************************************************************


  function _distributeToBribes(
    address incomeToken,
    address tokenToDistribute,
    address[] memory vaults,
    uint[] memory queuedAmounts,
    uint queuedBalance,
    uint toDistribute
  ) internal {
    address _bribe = bribe;
    uint _epoch = IBribe(_bribe).epoch();
    _approveIfNeed(tokenToDistribute, _bribe, toDistribute);

    uint remaining = toDistribute;
    for (uint i; i < vaults.length; i++) {
      uint toSend = toDistribute * queuedAmounts[i] / queuedBalance;
      // for avoid rounding issue send all remaining amount
      if (i == vaults.length - 1) {
        toSend = remaining;
      } else {
        remaining -= toSend;
      }

      _registerRewardInBribe(_bribe, vaults[i], tokenToDistribute);
      IBribe(_bribe).notifyForNextEpoch(vaults[i], tokenToDistribute, toSend);
      IBribe(_bribe).notifyDelayedRewards(vaults[i], tokenToDistribute, _epoch);

      // clear queued data
      _destinationQueue[incomeToken].remove(vaults[i]);
      delete amountPerDestination[incomeToken][vaults[i]];
      _tokensPerDestination[vaults[i]].remove(incomeToken);
    }

    if (IERC20(incomeToken).balanceOf(address(this)) == 0) {
      _queuedTokens.remove(incomeToken);
    }
  }

  function _registerRewardInBribe(address _bribe, address stakingToken, address rewardToken) internal {
    if (!IMultiPool(_bribe).isRewardToken(stakingToken, rewardToken)) {
      IMultiPool(_bribe).registerRewardToken(stakingToken, rewardToken);
    }
  }

  function _approveIfNeed(address token, address dst, uint amount) internal {
    if (IERC20(token).allowance(address(this), dst) < amount) {
      IERC20(token).safeApprove(dst, 0);
      IERC20(token).safeApprove(dst, type(uint).max);
    }
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_FORWARDER || super.supportsInterface(interfaceId);
  }

}
