// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "../openzeppelin/SafeERC20.sol";
import "../openzeppelin/Math.sol";
import "../interfaces/IStrategyV2.sol";
import "../interfaces/ISplitter.sol";
import "../interfaces/IForwarder.sol";
import "../interfaces/ITetuVaultV2.sol";
import "../proxy/ControllableV3.sol";

/// @title Abstract contract for base strategy functionality
/// @author belbix
abstract contract StrategyBaseV2 is IStrategyV2, ControllableV3 {
  using SafeERC20 for IERC20;

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant STRATEGY_BASE_VERSION = "2.0.1";
  /// @dev Denominator for compound ratio
  uint internal constant COMPOUND_DENOMINATOR = 100_000;
  /// @dev Denominator for fee calculation.
  uint internal constant FEE_DENOMINATOR = 100_000;

  // *************************************************************
  //                        ERRORS
  // *************************************************************

  string internal constant WRONG_CONTROLLER = "SB: Wrong controller";
  string internal constant DENIED = "SB: Denied";
  string internal constant TOO_HIGH = "SB: Too high";
  string internal constant IMPACT_TOO_HIGH = "SB: Impact too high";

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  /// @dev Underlying asset
  address public override asset;
  /// @dev Linked splitter
  address public override splitter;
  /// @dev Percent of profit for autocompound inside this strategy.
  uint public override compoundRatio;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event WithdrawAllToSplitter(uint amount);
  event WithdrawToSplitter(uint amount, uint sent, uint balance);
  event EmergencyExit(address sender, uint amount);
  event ManualClaim(address sender);
  event InvestAll(uint balance);
  event DepositToPool(uint amount);
  event WithdrawFromPool(uint amount);
  event WithdrawAllFromPool(uint amount);
  event Claimed(address token, uint amount);
  event CompoundRatioChanged(uint oldValue, uint newValue);
  event SentToForwarder(address forwarder, address token, uint amount);

  // *************************************************************
  //                        INIT
  // *************************************************************

  /// @notice Initialize contract after setup it as proxy implementation
  function __StrategyBase_init(
    address controller_,
    address _splitter
  ) public onlyInitializing {
    _requireInterface(_splitter, InterfaceIds.I_SPLITTER);
    __Controllable_init(controller_);

    require(IControllable(_splitter).isController(controller_), WRONG_CONTROLLER);

    asset = ISplitter(_splitter).asset();
    splitter = _splitter;
  }

  // *************************************************************
  //                     RESTRICTIONS
  // *************************************************************

  /// @dev Restrict access only for operators
  function _onlyOperators() internal view {
    require(IController(controller()).isOperator(msg.sender), DENIED);
  }

  // *************************************************************
  //                        VIEWS
  // *************************************************************

  /// @dev Total amount of underlying assets under control of this strategy.
  function totalAssets() public view override returns (uint) {
    return IERC20(asset).balanceOf(address(this)) + investedAssets();
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_STRATEGY_V2 || super.supportsInterface(interfaceId);
  }

  // *************************************************************
  //                   VOTER ACTIONS
  // *************************************************************

  /// @dev PlatformVoter can change compound ratio for some strategies.
  ///      A strategy can implement another logic for some uniq cases.
  function setCompoundRatio(uint value) external virtual override {
    require(msg.sender == IController(controller()).platformVoter(), DENIED);
    require(value <= COMPOUND_DENOMINATOR, TOO_HIGH);
    emit CompoundRatioChanged(compoundRatio, value);
    compoundRatio = value;
  }

  // *************************************************************
  //                   OPERATOR ACTIONS
  // *************************************************************

  /// @dev In case of any issue operator can withdraw all from pool.
  function emergencyExit() external {
    _onlyOperators();

    _emergencyExitFromPool();

    address _asset = asset;
    uint balance = IERC20(_asset).balanceOf(address(this));
    IERC20(_asset).safeTransfer(splitter, balance);
    emit EmergencyExit(msg.sender, balance);
  }

  /// @dev Manual claim rewards.
  function claim() external {
    _onlyOperators();

    _claim();
    emit ManualClaim(msg.sender);
  }

  // *************************************************************
  //                    DEPOSIT/WITHDRAW
  // *************************************************************

  /// @dev Stakes everything the strategy holds into the reward pool.
  function investAll() external override {
    require(msg.sender == splitter, DENIED);

    uint balance = IERC20(asset).balanceOf(address(this));
    if (balance > 0) {
      _depositToPool(balance);
    }
    emit InvestAll(balance);
  }

  /// @dev Withdraws all underlying assets to the vault
  function withdrawAllToSplitter() external override {
    address _splitter = splitter;
    address _asset = asset;
    require(msg.sender == _splitter, DENIED);

    uint balance = IERC20(_asset).balanceOf(address(this));

    (uint investedAssetsUSD, uint assetPrice) = _withdrawAllFromPool();

    balance = _checkWithdrawImpact(
      _asset,
      balance,
      investedAssetsUSD,
      assetPrice,
      _splitter
    );

    if (balance != 0) {
      IERC20(_asset).safeTransfer(_splitter, balance);
    }
    emit WithdrawAllToSplitter(balance);
  }

  /// @dev Withdraws some assets to the splitter
  function withdrawToSplitter(uint amount) external override {
    address _splitter = splitter;
    address _asset = asset;
    require(msg.sender == _splitter, DENIED);

    uint balance = IERC20(_asset).balanceOf(address(this));
    if (amount > balance) {
      (uint investedAssetsUSD, uint assetPrice) = _withdrawFromPool(amount - balance);
      balance = _checkWithdrawImpact(
        _asset,
        balance,
        investedAssetsUSD,
        assetPrice,
        _splitter
      );
    }

    uint amountAdjusted = Math.min(amount, balance);
    if (amountAdjusted != 0) {
      IERC20(_asset).safeTransfer(_splitter, amountAdjusted);
    }
    emit WithdrawToSplitter(amount, amountAdjusted, balance);
  }

  // *************************************************************
  //                       HELPERS
  // *************************************************************

  /// @notice Calculate withdrawn amount in USD using the {assetPrice}.
  ///         Revert if the amount is different from expected too much (high price impact)
  /// @param balanceBefore Asset balance of the strategy before withdrawing
  /// @param investedAssetsUSD Expected amount in USD, decimals are same to {_asset}
  /// @param assetPrice Price of the asset, decimals 18
  /// @return balance Current asset balance of the strategy
  function _checkWithdrawImpact(
    address _asset,
    uint balanceBefore,
    uint investedAssetsUSD,
    uint assetPrice,
    address _splitter
  ) internal view returns (uint balance) {
    balance = IERC20(_asset).balanceOf(address(this));
    if (assetPrice != 0 || investedAssetsUSD != 0) {

      uint withdrew = balance > balanceBefore ? balance - balanceBefore : 0;
      uint withdrewUSD = withdrew * assetPrice / 1e18;
      uint priceChangeTolerance = ITetuVaultV2(ISplitter(_splitter).vault()).withdrawFee();
      uint difference = investedAssetsUSD > withdrewUSD ? investedAssetsUSD - withdrewUSD : 0;

      require(difference * FEE_DENOMINATOR / investedAssetsUSD <= priceChangeTolerance, IMPACT_TOO_HIGH);
    }
  }

  /// @dev Must use this function for any transfers to Forwarder.
  function _sendToForwarder(address token, uint amount) internal {
    address forwarder = IController(controller()).forwarder();
    IERC20(token).safeTransfer(forwarder, amount);
    IForwarder(forwarder).distribute(token);
    emit SentToForwarder(forwarder, token, amount);
  }

  // *************************************************************
  //                       VIRTUAL
  // These functions must be implemented in the strategy contract
  // *************************************************************

  /// @dev Amount of underlying assets invested to the pool.
  function investedAssets() public view virtual returns (uint);

  /// @dev Deposit given amount to the pool.
  function _depositToPool(uint amount) internal virtual;

  /// @dev Withdraw given amount from the pool.
  /// @return investedAssetsUSD Sum of USD value of each asset in the pool that was withdrawn, decimals of {asset}.
  /// @return assetPrice Price of the strategy {asset}.
  function _withdrawFromPool(uint amount) internal virtual returns (uint investedAssetsUSD, uint assetPrice);

  /// @dev Withdraw all from the pool.
  /// @return investedAssetsUSD Sum of USD value of each asset in the pool that was withdrawn, decimals of {asset}.
  /// @return assetPrice Price of the strategy {asset}.
  function _withdrawAllFromPool() internal virtual returns (uint investedAssetsUSD, uint assetPrice);

  /// @dev If pool support emergency withdraw need to call it for emergencyExit()
  ///      Withdraw assets without impact checking.
  function _emergencyExitFromPool() internal virtual;

  /// @dev Claim all possible rewards.
  function _claim() internal virtual;

}
