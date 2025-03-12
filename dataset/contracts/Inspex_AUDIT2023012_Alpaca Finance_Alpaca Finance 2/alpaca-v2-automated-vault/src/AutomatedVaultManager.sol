// SPDX-License-Identifier: BUSL
pragma solidity 0.8.19;

// dependencies
import { ERC20 } from "@solmate/tokens/ERC20.sol";
import { SafeTransferLib } from "@solmate/utils/SafeTransferLib.sol";
import { Initializable } from "@openzeppelin-upgradeable/proxy/utils/Initializable.sol";
import { Ownable2StepUpgradeable } from "@openzeppelin-upgradeable/access/Ownable2StepUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { Clones } from "@openzeppelin/proxy/Clones.sol";

// contracts
import { AutomatedVaultERC20 } from "src/AutomatedVaultERC20.sol";
import { BaseOracle } from "src/oracles/BaseOracle.sol";

// interfaces
import { IExecutor } from "src/interfaces/IExecutor.sol";
import { IVaultOracle } from "src/interfaces/IVaultOracle.sol";
import { IAutomatedVaultERC20 } from "src/interfaces/IAutomatedVaultERC20.sol";

// libraries
import { LibShareUtil } from "src/libraries/LibShareUtil.sol";
import { MAX_BPS } from "src/libraries/Constants.sol";

contract AutomatedVaultManager is Initializable, Ownable2StepUpgradeable, ReentrancyGuardUpgradeable {
  ///////////////
  // Libraries //
  ///////////////
  using SafeTransferLib for ERC20;
  using LibShareUtil for uint256;

  ////////////
  // Errors //
  ////////////
  error AutomatedVaultManager_InvalidMinAmountOut();
  error AutomatedVaultManager_TokenMismatch();
  error AutomatedVaultManager_VaultNotExist(address _vaultToken);
  error AutomatedVaultManager_WithdrawExceedBalance();
  error AutomatedVaultManager_Unauthorized();
  error AutomatedVaultManager_TooMuchEquityLoss();
  error AutomatedVaultManager_TooMuchLeverage();
  error AutomatedVaultManager_BelowMinimumDeposit();
  error AutomatedVaultManager_TooLittleReceived();
  error AutomatedVaultManager_TokenNotAllowed();
  error AutomatedVaultManager_InvalidParams();
  error AutomatedVaultManager_ExceedCapacity();
  error AutomatedVaultManager_EmergencyPaused();

  ////////////
  // Events //
  ////////////
  event LogOpenVault(address indexed _vaultToken, OpenVaultParams _vaultParams);
  event LogDeposit(
    address indexed _vaultToken,
    address indexed _user,
    TokenAmount[] _deposits,
    uint256 _shareReceived,
    uint256 _equityChanged
  );
  event LogWithdraw(
    address indexed _vaultToken,
    address indexed _user,
    uint256 _sharesWithdrawn,
    uint256 _withdrawFee,
    uint256 _equityChanged
  );
  event LogManage(address _vaultToken, bytes[] _executorParams, uint256 _equityBefore, uint256 _equityAfter);
  event LogSetVaultManager(address indexed _vaultToken, address _manager, bool _isOk);
  event LogSetAllowToken(address indexed _vaultToken, address _token, bool _isAllowed);
  event LogSetVaultTokenImplementation(address _prevImplementation, address _newImplementation);
  event LogSetToleranceBps(address _vaultToken, uint16 _toleranceBps);
  event LogSetMaxLeverage(address _vaultToken, uint8 _maxLeverage);
  event LogSetMinimumDeposit(address _vaultToken, uint32 _compressedMinimumDeposit);
  event LogSetManagementFeePerSec(address _vaultToken, uint32 _managementFeePerSec);
  event LogSetMangementFeeTreasury(address _managementFeeTreasury);
  event LogSetWithdrawalFeeTreasury(address _withdrawalFeeTreasury);
  event LogSetWithdrawalFeeBps(address _vaultToken, uint16 _withdrawalFeeBps);
  event LogSetCapacity(address _vaultToken, uint32 _compressedCapacity);
  event LogSetIsDepositPaused(address _vaultToken, bool _isPaused);
  event LogSetIsWithdrawPaused(address _vaultToken, bool _isPaused);

  /////////////
  // Structs //
  /////////////
  struct TokenAmount {
    address token;
    uint256 amount;
  }

  struct VaultInfo {
    // === Slot 1 === // 160 + 32 + 32 + 8 + 16 + 8
    address worker;
    // Deposit
    uint32 compressedMinimumDeposit;
    uint32 compressedCapacity;
    bool isDepositPaused;
    // Withdraw
    uint16 withdrawalFeeBps;
    bool isWithdrawalPaused;
    // === Slot 2 === // 160 + 32 + 40
    address executor;
    // Management fee
    uint32 managementFeePerSec;
    uint40 lastManagementFeeCollectedAt;
    // === Slot 3 === // 160 + 16 + 8
    address vaultOracle;
    // Manage
    uint16 toleranceBps;
    uint8 maxLeverage;
  }

  ///////////////
  // Constants //
  ///////////////
  uint256 constant MAX_MANAGEMENT_FEE_PER_SEC = 10e16 / uint256(365 days); // 10% per year
  uint256 constant MINIMUM_DEPOSIT_SCALE = 1e16; // 0.01 USD
  uint256 constant CAPACITY_SCALE = 1e18; // 1 USD

  /////////////////////
  // State variables //
  /////////////////////
  address public vaultTokenImplementation;
  address public managementFeeTreasury;
  address public withdrawalFeeTreasury;
  /// @dev execution scope to tell downstream contracts (Bank, Worker, etc.)
  /// that current executor is acting on behalf of vault and can be trusted
  address public EXECUTOR_IN_SCOPE;

  mapping(address => VaultInfo) public vaultInfos; // vault's ERC20 address => vault info
  mapping(address => mapping(address => bool)) public isManager; // vault's ERC20 address => manager address => is manager
  mapping(address => mapping(address => bool)) public allowTokens; // vault's ERC20 address => token address => is allowed
  mapping(address => bool) public workerExisted; // worker address => is existed

  ///////////////
  // Modifiers //
  ///////////////
  modifier collectManagementFee(address _vaultToken) {
    uint256 _lastCollectedFee = vaultInfos[_vaultToken].lastManagementFeeCollectedAt;
    if (block.timestamp > _lastCollectedFee) {
      uint256 _pendingFee = pendingManagementFee(_vaultToken);
      IAutomatedVaultERC20(_vaultToken).mint(managementFeeTreasury, _pendingFee);
      vaultInfos[_vaultToken].lastManagementFeeCollectedAt = uint40(block.timestamp);
    }
    _;
  }

  modifier onlyExistedVault(address _vaultToken) {
    if (vaultInfos[_vaultToken].worker == address(0)) {
      revert AutomatedVaultManager_VaultNotExist(_vaultToken);
    }
    _;
  }

  /// @custom:oz-upgrades-unsafe-allow constructor
  constructor() {
    _disableInitializers();
  }

  function initialize(address _vaultTokenImplementation, address _managementFeeTreasury, address _withdrawalFeeTreasury)
    external
    initializer
  {
    if (
      _vaultTokenImplementation == address(0) || _managementFeeTreasury == address(0)
        || _withdrawalFeeTreasury == address(0)
    ) {
      revert AutomatedVaultManager_InvalidParams();
    }

    Ownable2StepUpgradeable.__Ownable2Step_init();
    ReentrancyGuardUpgradeable.__ReentrancyGuard_init();

    vaultTokenImplementation = _vaultTokenImplementation;
    managementFeeTreasury = _managementFeeTreasury;
    withdrawalFeeTreasury = _withdrawalFeeTreasury;
  }

  /// @notice Calculate pending management fee
  /// @dev Return as share amount
  /// @param _vaultToken an address of vault token
  /// @return _pendingFee an amount of share pending for minting as a form of management fee
  function pendingManagementFee(address _vaultToken) public view returns (uint256 _pendingFee) {
    uint256 _lastCollectedFee = vaultInfos[_vaultToken].lastManagementFeeCollectedAt;

    if (block.timestamp > _lastCollectedFee) {
      unchecked {
        _pendingFee = (
          IAutomatedVaultERC20(_vaultToken).totalSupply() * vaultInfos[_vaultToken].managementFeePerSec
            * (block.timestamp - _lastCollectedFee)
        ) / 1e18;
      }
    }
  }

  function deposit(address _depositFor, address _vaultToken, TokenAmount[] calldata _depositParams, uint256 _minReceive)
    external
    onlyExistedVault(_vaultToken)
    collectManagementFee(_vaultToken)
    nonReentrant
    returns (bytes memory _result)
  {
    VaultInfo memory _cachedVaultInfo = vaultInfos[_vaultToken];

    if (_cachedVaultInfo.isDepositPaused) {
      revert AutomatedVaultManager_EmergencyPaused();
    }

    _pullTokens(_vaultToken, _cachedVaultInfo.executor, _depositParams);

    ///////////////////////////
    // Executor scope opened //
    ///////////////////////////
    EXECUTOR_IN_SCOPE = _cachedVaultInfo.executor;
    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.executor).onUpdate(_cachedVaultInfo.worker, _vaultToken);

    (uint256 _totalEquityBefore,) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    _result = IExecutor(_cachedVaultInfo.executor).onDeposit(_cachedVaultInfo.worker, _vaultToken);
    EXECUTOR_IN_SCOPE = address(0);
    ///////////////////////////
    // Executor scope closed //
    ///////////////////////////

    uint256 _equityChanged;
    {
      (uint256 _totalEquityAfter, uint256 _debtAfter) =
        IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);
      if (_totalEquityAfter + _debtAfter > _cachedVaultInfo.compressedCapacity * CAPACITY_SCALE) {
        revert AutomatedVaultManager_ExceedCapacity();
      }
      _equityChanged = _totalEquityAfter - _totalEquityBefore;
    }

    if (_equityChanged < _cachedVaultInfo.compressedMinimumDeposit * MINIMUM_DEPOSIT_SCALE) {
      revert AutomatedVaultManager_BelowMinimumDeposit();
    }

    uint256 _shareReceived =
      _equityChanged.valueToShare(IAutomatedVaultERC20(_vaultToken).totalSupply(), _totalEquityBefore);
    if (_shareReceived < _minReceive) {
      revert AutomatedVaultManager_TooLittleReceived();
    }
    IAutomatedVaultERC20(_vaultToken).mint(_depositFor, _shareReceived);

    emit LogDeposit(_vaultToken, _depositFor, _depositParams, _shareReceived, _equityChanged);
  }

  function manage(address _vaultToken, bytes[] calldata _executorParams)
    external
    collectManagementFee(_vaultToken)
    nonReentrant
    returns (bytes[] memory _result)
  {
    // 0. Validate
    if (!isManager[_vaultToken][msg.sender]) {
      revert AutomatedVaultManager_Unauthorized();
    }

    VaultInfo memory _cachedVaultInfo = vaultInfos[_vaultToken];

    ///////////////////////////
    // Executor scope opened //
    ///////////////////////////
    EXECUTOR_IN_SCOPE = _cachedVaultInfo.executor;
    // 1. Update the vault
    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.executor).onUpdate(_cachedVaultInfo.worker, _vaultToken);

    // 2. execute manage
    (uint256 _totalEquityBefore,) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    // Set executor execution scope (worker, vault token) so that we don't have to pass them through multicall
    IExecutor(_cachedVaultInfo.executor).setExecutionScope(_cachedVaultInfo.worker, _vaultToken);
    _result = IExecutor(_cachedVaultInfo.executor).multicall(_executorParams);
    IExecutor(_cachedVaultInfo.executor).sweepToWorker();
    IExecutor(_cachedVaultInfo.executor).setExecutionScope(address(0), address(0));

    EXECUTOR_IN_SCOPE = address(0);
    ///////////////////////////
    // Executor scope closed //
    ///////////////////////////

    // 3. Check equity loss < threshold
    (uint256 _totalEquityAfter, uint256 _debtAfter) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    // _totalEquityAfter  < _totalEquityBefore * _cachedVaultInfo.toleranceBps / MAX_BPS;
    if (_totalEquityAfter * MAX_BPS < _totalEquityBefore * _cachedVaultInfo.toleranceBps) {
      revert AutomatedVaultManager_TooMuchEquityLoss();
    }

    // 4. Check leverage exceed max leverage
    // (debt + equity) / equity > max leverage
    // debt + equity = max leverage * equity
    // debt = (max leverage * equity) - equity
    // debt = (leverage - 1) * equity
    if (_debtAfter > (_cachedVaultInfo.maxLeverage - 1) * _totalEquityAfter) {
      revert AutomatedVaultManager_TooMuchLeverage();
    }

    emit LogManage(_vaultToken, _executorParams, _totalEquityBefore, _totalEquityAfter);
  }

  function withdraw(address _vaultToken, uint256 _sharesToWithdraw, TokenAmount[] calldata _minAmountOuts)
    external
    onlyExistedVault(_vaultToken)
    collectManagementFee(_vaultToken)
    nonReentrant
    returns (AutomatedVaultManager.TokenAmount[] memory _results)
  {
    VaultInfo memory _cachedVaultInfo = vaultInfos[_vaultToken];

    if (_cachedVaultInfo.isWithdrawalPaused) {
      revert AutomatedVaultManager_EmergencyPaused();
    }

    // Revert if withdraw shares more than balance
    if (_sharesToWithdraw > IAutomatedVaultERC20(_vaultToken).balanceOf(msg.sender)) {
      revert AutomatedVaultManager_WithdrawExceedBalance();
    }

    uint256 _actualWithdrawAmount;
    // Safe to do unchecked because we already checked withdraw amount < balance and max bps won't overflow anyway
    unchecked {
      _actualWithdrawAmount = (_sharesToWithdraw * (MAX_BPS - _cachedVaultInfo.withdrawalFeeBps)) / MAX_BPS;
    }

    ///////////////////////////
    // Executor scope opened //
    ///////////////////////////
    EXECUTOR_IN_SCOPE = _cachedVaultInfo.executor;

    // Accrue interest and reinvest before execute to ensure fair interest and profit distribution
    IExecutor(_cachedVaultInfo.executor).onUpdate(_cachedVaultInfo.worker, _vaultToken);

    (uint256 _totalEquityBefore,) =
      IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);

    // Execute withdraw
    // Executor should send withdrawn funds back here to check slippage
    _results =
      IExecutor(_cachedVaultInfo.executor).onWithdraw(_cachedVaultInfo.worker, _vaultToken, _actualWithdrawAmount);

    EXECUTOR_IN_SCOPE = address(0);
    ///////////////////////////
    // Executor scope closed //
    ///////////////////////////

    uint256 _equityChanged;
    {
      (uint256 _totalEquityAfter,) =
        IVaultOracle(_cachedVaultInfo.vaultOracle).getEquityAndDebt(_vaultToken, _cachedVaultInfo.worker);
      _equityChanged = _totalEquityBefore - _totalEquityAfter;
    }

    uint256 _withdrawalFee;
    // Safe to do unchecked because _actualWithdrawAmount < _sharesToWithdraw from above
    unchecked {
      _withdrawalFee = _sharesToWithdraw - _actualWithdrawAmount;
    }

    // Burn shares per requested amount before transfer out
    IAutomatedVaultERC20(_vaultToken).burn(msg.sender, _sharesToWithdraw);
    // Mint withdrawal fee to withdrawal treasury
    IAutomatedVaultERC20(_vaultToken).mint(withdrawalFeeTreasury, _withdrawalFee);
    // Net shares changed would be `_actualWithdrawAmount`

    // Transfer withdrawn funds to user
    // Tokens should be transferred from executor to here during `onWithdraw`
    {
      uint256 _len = _results.length;
      if (_minAmountOuts.length < _len) {
        revert AutomatedVaultManager_InvalidMinAmountOut();
      }
      address _token;
      uint256 _amount;
      for (uint256 _i; _i < _len;) {
        _token = _results[_i].token;
        _amount = _results[_i].amount;

        // revert result token != min amount token
        if (_token != _minAmountOuts[_i].token) {
          revert AutomatedVaultManager_TokenMismatch();
        }

        // Check slippage
        if (_amount < _minAmountOuts[_i].amount) {
          revert AutomatedVaultManager_TooLittleReceived();
        }

        ERC20(_token).safeTransfer(msg.sender, _amount);
        unchecked {
          ++_i;
        }
      }
    }

    // Assume `tx.origin` is user for tracking purpose
    emit LogWithdraw(_vaultToken, tx.origin, _sharesToWithdraw, _withdrawalFee, _equityChanged);
  }

  /////////////////////
  // Admin functions //
  /////////////////////

  struct OpenVaultParams {
    address worker;
    address vaultOracle;
    address executor;
    uint32 compressedMinimumDeposit;
    uint32 compressedCapacity;
    uint32 managementFeePerSec;
    uint16 withdrawalFeeBps;
    uint16 toleranceBps;
    uint8 maxLeverage;
  }

  function openVault(string calldata _name, string calldata _symbol, OpenVaultParams calldata _params)
    external
    onlyOwner
    returns (address _vaultToken)
  {
    // Prevent duplicate worker between vaults
    if (workerExisted[_params.worker]) {
      revert AutomatedVaultManager_InvalidParams();
    }
    // Validate parameters
    _validateToleranceBps(_params.toleranceBps);
    _validateMaxLeverage(_params.maxLeverage);
    _validateMinimumDeposit(_params.compressedMinimumDeposit);
    _validateManagementFeePerSec(_params.managementFeePerSec);
    _validateWithdrawalFeeBps(_params.withdrawalFeeBps);
    // Sanity check oracle
    BaseOracle(_params.vaultOracle).maxPriceAge();
    // Sanity check executor
    if (IExecutor(_params.executor).vaultManager() != address(this)) {
      revert AutomatedVaultManager_InvalidParams();
    }

    // Deploy vault token with ERC-1167 minimal proxy
    _vaultToken = Clones.clone(vaultTokenImplementation);
    AutomatedVaultERC20(_vaultToken).initialize(_name, _symbol);

    // Update states
    vaultInfos[_vaultToken] = VaultInfo({
      worker: _params.worker,
      vaultOracle: _params.vaultOracle,
      executor: _params.executor,
      compressedMinimumDeposit: _params.compressedMinimumDeposit,
      compressedCapacity: _params.compressedCapacity,
      isDepositPaused: false,
      withdrawalFeeBps: _params.withdrawalFeeBps,
      isWithdrawalPaused: false,
      managementFeePerSec: _params.managementFeePerSec,
      lastManagementFeeCollectedAt: uint40(block.timestamp),
      toleranceBps: _params.toleranceBps,
      maxLeverage: _params.maxLeverage
    });
    workerExisted[_params.worker] = true;

    emit LogOpenVault(_vaultToken, _params);
  }

  function setVaultTokenImplementation(address _implementation) external onlyOwner {
    emit LogSetVaultTokenImplementation(vaultTokenImplementation, _implementation);
    vaultTokenImplementation = _implementation;
  }

  function setManagementFeePerSec(address _vaultToken, uint32 _managementFeePerSec)
    external
    onlyOwner
    onlyExistedVault(_vaultToken)
  {
    _validateManagementFeePerSec(_managementFeePerSec);
    vaultInfos[_vaultToken].managementFeePerSec = _managementFeePerSec;

    emit LogSetManagementFeePerSec(_vaultToken, _managementFeePerSec);
  }

  function setManagementFeeTreasury(address _managementFeeTreasury) external onlyOwner {
    if (_managementFeeTreasury == address(0)) {
      revert AutomatedVaultManager_InvalidParams();
    }
    managementFeeTreasury = _managementFeeTreasury;

    emit LogSetMangementFeeTreasury(_managementFeeTreasury);
  }

  function setWithdrawalFeeTreasury(address _withdrawalFeeTreasury) external onlyOwner {
    if (_withdrawalFeeTreasury == address(0)) {
      revert AutomatedVaultManager_InvalidParams();
    }
    withdrawalFeeTreasury = _withdrawalFeeTreasury;
    emit LogSetWithdrawalFeeTreasury(_withdrawalFeeTreasury);
  }

  //////////////////////////////
  // Per vault config setters //
  //////////////////////////////

  function setVaultManager(address _vaultToken, address _manager, bool _isOk) external onlyOwner {
    isManager[_vaultToken][_manager] = _isOk;
    emit LogSetVaultManager(_vaultToken, _manager, _isOk);
  }

  function setAllowToken(address _vaultToken, address _token, bool _isAllowed)
    external
    onlyOwner
    onlyExistedVault(_vaultToken)
  {
    allowTokens[_vaultToken][_token] = _isAllowed;

    emit LogSetAllowToken(_vaultToken, _token, _isAllowed);
  }

  function setToleranceBps(address _vaultToken, uint16 _toleranceBps) external onlyOwner onlyExistedVault(_vaultToken) {
    _validateToleranceBps(_toleranceBps);
    vaultInfos[_vaultToken].toleranceBps = _toleranceBps;

    emit LogSetToleranceBps(_vaultToken, _toleranceBps);
  }

  function setMaxLeverage(address _vaultToken, uint8 _maxLeverage) external onlyOwner onlyExistedVault(_vaultToken) {
    _validateMaxLeverage(_maxLeverage);
    vaultInfos[_vaultToken].maxLeverage = _maxLeverage;

    emit LogSetMaxLeverage(_vaultToken, _maxLeverage);
  }

  function setMinimumDeposit(address _vaultToken, uint32 _compressedMinimumDeposit)
    external
    onlyOwner
    onlyExistedVault(_vaultToken)
  {
    _validateMinimumDeposit(_compressedMinimumDeposit);
    vaultInfos[_vaultToken].compressedMinimumDeposit = _compressedMinimumDeposit;

    emit LogSetMinimumDeposit(_vaultToken, _compressedMinimumDeposit);
  }

  function setWithdrawalFeeBps(address _vaultToken, uint16 _withdrawalFeeBps)
    external
    onlyOwner
    onlyExistedVault(_vaultToken)
  {
    _validateWithdrawalFeeBps(_withdrawalFeeBps);
    vaultInfos[_vaultToken].withdrawalFeeBps = _withdrawalFeeBps;

    emit LogSetWithdrawalFeeBps(_vaultToken, _withdrawalFeeBps);
  }

  function setCapacity(address _vaultToken, uint32 _compressedCapacity)
    external
    onlyOwner
    onlyExistedVault(_vaultToken)
  {
    vaultInfos[_vaultToken].compressedCapacity = _compressedCapacity;
    emit LogSetCapacity(_vaultToken, _compressedCapacity);
  }

  function setIsDepositPaused(address[] calldata _vaultTokens, bool _isPaused) external onlyOwner {
    uint256 _len = _vaultTokens.length;
    for (uint256 _i; _i < _len;) {
      vaultInfos[_vaultTokens[_i]].isDepositPaused = _isPaused;
      emit LogSetIsDepositPaused(_vaultTokens[_i], _isPaused);
      unchecked {
        ++_i;
      }
    }
  }

  function setIsWithdrawPaused(address[] calldata _vaultTokens, bool _isPaused) external onlyOwner {
    uint256 _len = _vaultTokens.length;
    for (uint256 _i; _i < _len;) {
      vaultInfos[_vaultTokens[_i]].isWithdrawalPaused = _isPaused;
      emit LogSetIsWithdrawPaused(_vaultTokens[_i], _isPaused);
      unchecked {
        ++_i;
      }
    }
  }

  //////////////////////
  // Getter functions //
  //////////////////////

  function getWorker(address _vaultToken) external view returns (address _worker) {
    _worker = vaultInfos[_vaultToken].worker;
  }

  ///////////////////////
  // Private functions //
  ///////////////////////

  function _pullTokens(address _vaultToken, address _destination, TokenAmount[] calldata _deposits) internal {
    uint256 _depositLength = _deposits.length;
    for (uint256 _i; _i < _depositLength;) {
      if (!allowTokens[_vaultToken][_deposits[_i].token]) {
        revert AutomatedVaultManager_TokenNotAllowed();
      }
      ERC20(_deposits[_i].token).safeTransferFrom(msg.sender, _destination, _deposits[_i].amount);
      unchecked {
        ++_i;
      }
    }
  }

  /// @dev Valid value: withdrawalFeeBps <= 1000
  function _validateWithdrawalFeeBps(uint16 _withdrawalFeeBps) internal pure {
    if (_withdrawalFeeBps > 1000) {
      revert AutomatedVaultManager_InvalidParams();
    }
  }

  /// @dev Valid value range: 9500 <= toleranceBps <= 10000
  function _validateToleranceBps(uint16 _toleranceBps) internal pure {
    if (_toleranceBps > MAX_BPS || _toleranceBps < 9500) {
      revert AutomatedVaultManager_InvalidParams();
    }
  }

  /// @dev Valid value range: 1 <= maxLeverage <= 10
  function _validateMaxLeverage(uint8 _maxLeverage) internal pure {
    if (_maxLeverage > 10 || _maxLeverage < 1) {
      revert AutomatedVaultManager_InvalidParams();
    }
  }

  function _validateMinimumDeposit(uint32 _compressedMinimumDeposit) internal pure {
    if (_compressedMinimumDeposit == 0) {
      revert AutomatedVaultManager_InvalidParams();
    }
  }

  /// @dev Valid value range: 0 <= managementFeePerSec <= 10% per year
  function _validateManagementFeePerSec(uint32 _managementFeePerSec) internal pure {
    if (_managementFeePerSec > MAX_MANAGEMENT_FEE_PER_SEC) {
      revert AutomatedVaultManager_InvalidParams();
    }
  }
}
