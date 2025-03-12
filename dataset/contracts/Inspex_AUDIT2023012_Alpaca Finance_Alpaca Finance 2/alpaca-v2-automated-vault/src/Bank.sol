// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { SafeCastLib } from "@solmate/utils/SafeCastLib.sol";
import { EnumerableSet } from "@openzeppelin/utils/structs/EnumerableSet.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { IMoneyMarket } from "@alpaca-mm/money-market/interfaces/IMoneyMarket.sol";

// contracts
import { AutomatedVaultManager } from "src/AutomatedVaultManager.sol";

// libraries
import { LibShareUtil } from "src/libraries/LibShareUtil.sol";

contract Bank is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
  using SafeCastLib for uint256;
  using SafeTransferLib for ERC20;
  using LibShareUtil for uint256;
  using EnumerableSet for EnumerableSet.AddressSet;

  error Bank_ExecutorNotInScope();
  error Bank_RepayMoreThanDebt();

  IMoneyMarket public moneyMarket;
  AutomatedVaultManager public vaultManager;

  // vault token => list of borrowed tokens
  mapping(address => EnumerableSet.AddressSet) internal vaultDebtTokens;
  // vault token => borrowed token => debt shares
  mapping(address => mapping(address => uint256)) public vaultDebtShares;
  // token => total debt shares
  mapping(address => uint256) public tokenDebtShares;

  event LogBorrowOnBehalfOf(address indexed _vaultToken, address indexed _executor, address _token, uint256 _amount);
  event LogRepayOnBehalfOf(address indexed _vaultToken, address indexed _executor, address _token, uint256 _amount);

  modifier onlyExecutorWithinScope() {
    if (msg.sender != vaultManager.EXECUTOR_IN_SCOPE()) revert Bank_ExecutorNotInScope();
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _moneyMarket, address _vaultManager) external initializer {
    Ownable2StepUpgradeable.__Ownable2Step_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    // Sanity check
    IMoneyMarket(_moneyMarket).getMinDebtSize();
    AutomatedVaultManager(_vaultManager).vaultTokenImplementation();

    moneyMarket = IMoneyMarket(_moneyMarket);
    vaultManager = AutomatedVaultManager(_vaultManager);
  }

  function accrueInterest(address _vaultToken) external {
    uint256 _length = vaultDebtTokens[_vaultToken].length();
    for (uint256 _i; _i < _length;) {
      moneyMarket.accrueInterest(vaultDebtTokens[_vaultToken].at(_i));
      unchecked {
        ++_i;
      }
    }
  }

  function getVaultDebt(address _vaultToken, address _token)
    external
    view
    returns (uint256 _debtShares, uint256 _debtAmount)
  {
    _debtShares = vaultDebtShares[_vaultToken][_token];
    // NOTE: must accrue interest on money market before calculate shares to correctly reflect debt
    _debtAmount =
      _debtShares.shareToValue(moneyMarket.getNonCollatAccountDebt(address(this), _token), tokenDebtShares[_token]);
  }

  function borrowOnBehalfOf(address _vaultToken, address _token, uint256 _amount) external onlyExecutorWithinScope {
    IMoneyMarket _moneyMarket = moneyMarket;
    // Accure interest first
    _moneyMarket.accrueInterest(_token);

    // Effects
    uint256 _cachedTokenDebtShares = tokenDebtShares[_token];

    // NOTE: must accrue interest on money market before calculate shares to correctly reflect debt
    // Round up in protocol favor
    uint256 _debtSharesToAdd = _amount.valueToShareRoundingUp(
      _cachedTokenDebtShares, _moneyMarket.getNonCollatAccountDebt(address(this), _token)
    );
    // Add to borrowed token set
    // EnumerableSet already check for duplicate element
    vaultDebtTokens[_vaultToken].add(_token);

    // Safe to use unchecked since amount that would cause an overflow
    // would revert on borrow or transfer anyway
    unchecked {
      tokenDebtShares[_token] = _cachedTokenDebtShares + _debtSharesToAdd;
      vaultDebtShares[_vaultToken][_token] += _debtSharesToAdd;
    }

    // Interactions
    // Non-collat borrow from money market
    _moneyMarket.nonCollatBorrow(_token, _amount);
    // Forward tokens to executor
    ERC20(_token).safeTransfer(msg.sender, _amount);

    emit LogBorrowOnBehalfOf(_vaultToken, msg.sender, _token, _amount);
  }

  function repayOnBehalfOf(address _vaultToken, address _token, uint256 _amount)
    external
    onlyExecutorWithinScope
    returns (uint256 _actualRepayAmount)
  {
    IMoneyMarket _moneyMarket = moneyMarket;
    // Accure interest first
    _moneyMarket.accrueInterest(_token);

    uint256 _cachedTokenDebtShares = tokenDebtShares[_token];
    uint256 _cachedVaultDebtShares = vaultDebtShares[_vaultToken][_token];
    uint256 _cachedMMDebt = _moneyMarket.getNonCollatAccountDebt(address(this), _token);

    // NOTE: must accrue interest on money market before calculate shares to correctly reflect debt
    // Round down in protocol favor: decrease less debt
    _actualRepayAmount = _amount;
    uint256 _debtSharesToDecrease = _actualRepayAmount.valueToShare(_cachedTokenDebtShares, _cachedMMDebt);
    // Cap to debt if try to repay more than debt and re-calculate repay amount
    if (_debtSharesToDecrease > _cachedVaultDebtShares) {
      _debtSharesToDecrease = _cachedVaultDebtShares;
      // Round up in protocol favor: repay more
      _actualRepayAmount = _debtSharesToDecrease.shareToValueRoundingUp(_cachedMMDebt, _cachedTokenDebtShares);
      // Cap to actual debt, could happen when round up
      if (_actualRepayAmount > _cachedMMDebt) {
        _actualRepayAmount = _cachedMMDebt;
      }
    }

    // Transfer capped amount
    ERC20(_token).safeTransferFrom(msg.sender, address(this), _actualRepayAmount);

    // Decrease vault and total debt shares and remove token from borrowed token list if repay all
    // Safe to unchecked, total vault debt shares must always be less than total token debt shares
    unchecked {
      vaultDebtShares[_vaultToken][_token] = _cachedVaultDebtShares - _debtSharesToDecrease;
      if (_cachedVaultDebtShares == _debtSharesToDecrease) {
        vaultDebtTokens[_vaultToken].remove(_token);
      }
      tokenDebtShares[_token] = _cachedTokenDebtShares - _debtSharesToDecrease;
    }

    // Non-collat repay money market for itself
    ERC20(_token).safeApprove(address(_moneyMarket), _actualRepayAmount);
    _moneyMarket.nonCollatRepay(address(this), _token, _actualRepayAmount);

    emit LogRepayOnBehalfOf(_vaultToken, msg.sender, _token, _actualRepayAmount);
  }
}
