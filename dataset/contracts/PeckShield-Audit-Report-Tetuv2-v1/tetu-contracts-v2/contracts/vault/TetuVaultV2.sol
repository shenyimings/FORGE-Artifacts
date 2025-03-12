// SPDX-License-Identifier: MIT

pragma solidity 0.8.17;

import "../openzeppelin/Math.sol";
import "../interfaces/ISplitter.sol";
import "../interfaces/ITetuVaultV2.sol";
import "../interfaces/IGauge.sol";
import "../proxy/ControllableV3.sol";
import "./ERC4626Upgradeable.sol";

/// @title Vault for storing underlying tokens and managing them with strategy splitter.
/// @author belbix
contract TetuVaultV2 is ERC4626Upgradeable, ControllableV3, ITetuVaultV2 {
  using SafeERC20 for IERC20;
  using FixedPointMathLib for uint;

  // *************************************************************
  //                        CONSTANTS
  // *************************************************************

  /// @dev Version of this contract. Adjust manually on each code modification.
  string public constant VAULT_VERSION = "2.0.1";
  /// @dev Denominator for buffer calculation. 100% of the buffer amount.
  uint constant public BUFFER_DENOMINATOR = 100_000;
  /// @dev Denominator for fee calculation.
  uint constant public FEE_DENOMINATOR = 100_000;
  /// @dev Max 1% fee.
  uint constant public MAX_FEE = FEE_DENOMINATOR / 100;

  // *************************************************************
  //                        VARIABLES
  //                Keep names and ordering!
  //                 Add only in the bottom.
  // *************************************************************

  /// @dev Strategy splitter. Should be setup after deploy.
  ISplitter public splitter;
  /// @dev Connected gauge for stakeless rewards
  IGauge public gauge;
  /// @dev Dedicated contract for holding insurance for covering share price loss.
  IVaultInsurance public insurance;
  /// @dev Percent of assets that will always stay in this vault.
  uint public buffer;

  /// @dev Maximum amount for withdraw. Max UINT256 by default.
  uint public maxWithdrawAssets;
  /// @dev Maximum amount for redeem. Max UINT256 by default.
  uint public maxRedeemShares;
  /// @dev Maximum amount for deposit. Max UINT256 by default.
  uint public maxDepositAssets;
  /// @dev Maximum amount for mint. Max UINT256 by default.
  uint public maxMintShares;
  /// @dev Fee for deposit/mint actions. Zero by default.
  uint public override depositFee;
  /// @dev Fee for withdraw/redeem actions. Zero by default.
  uint public override withdrawFee;

  /// @dev Trigger doHardwork on invest action. Enabled by default.
  bool public doHardWorkOnInvest;

  // *************************************************************
  //                        EVENTS
  // *************************************************************

  event Init(
    address controller,
    address asset,
    string name,
    string symbol,
    address gauge,
    uint buffer
  );
  event SplitterSetup(address splitter);
  event BufferChanged(uint oldValue, uint newValue);
  event Invest(address splitter, uint amount);
  event MaxWithdrawChanged(uint maxAssets, uint maxShares);
  event MaxDepositChanged(uint maxAssets, uint maxShares);
  event FeeChanged(uint depositFee, uint withdrawFee);
  event DoHardWorkOnInvestChanged(bool oldValue, bool newValue);
  event FeeTransfer(uint amount);
  event LossCovered(uint amount);

  // *************************************************************
  //                        INIT
  // *************************************************************

  /// @dev Proxy initialization. Call it after contract deploy.
  function init(
    address controller_,
    IERC20 asset_,
    string memory _name,
    string memory _symbol,
    address _gauge,
    uint _buffer
  ) external initializer override {
    require(_buffer <= BUFFER_DENOMINATOR, "!BUFFER");
    require(_gauge != address(0), "!GAUGE");
    require(IControllable(_gauge).isController(controller_), "!GAUGE_CONTROLLER");

    _requireERC20(address(asset_));
    __ERC4626_init(asset_, _name, _symbol);
    __Controllable_init(controller_);

    _requireInterface(_gauge, InterfaceIds.I_GAUGE);
    gauge = IGauge(_gauge);
    buffer = _buffer;

    // set defaults
    maxWithdrawAssets = type(uint).max;
    maxRedeemShares = type(uint).max;
    maxDepositAssets = type(uint).max - 1;
    maxMintShares = type(uint).max - 1;
    doHardWorkOnInvest = true;

    emit Init(
      controller_,
      address(asset_),
      _name,
      _symbol,
      _gauge,
      _buffer
    );
  }

  function initInsurance(IVaultInsurance _insurance) external override {
    require(address(insurance) == address(0), "INITED");
    _requireInterface(address(_insurance), InterfaceIds.I_VAULT_INSURANCE);

    require(_insurance.vault() == address(this), "!VAULT");
    require(_insurance.asset() == address(_asset), "!ASSET");
    insurance = _insurance;
  }

  // *************************************************************
  //                      GOV ACTIONS
  // *************************************************************

  /// @dev Set new buffer value. Should be lower than denominator.
  function setBuffer(uint _buffer) external {
    require(isGovernance(msg.sender), "DENIED");
    require(_buffer <= BUFFER_DENOMINATOR, "BUFFER");

    emit BufferChanged(buffer, _buffer);
    buffer = _buffer;
  }

  /// @dev Set maximum available to deposit amounts.
  ///      Could be zero values in emergency case when need to pause malicious actions.
  function setMaxDeposit(uint maxAssets, uint maxShares) external {
    require(isGovernance(msg.sender), "DENIED");

    maxDepositAssets = maxAssets;
    maxMintShares = maxShares;
    emit MaxDepositChanged(maxAssets, maxShares);
  }

  /// @dev Set maximum available to withdraw amounts.
  ///      Could be zero values in emergency case when need to pause malicious actions.
  function setMaxWithdraw(uint maxAssets, uint maxShares) external {
    require(isGovernance(msg.sender), "DENIED");

    maxWithdrawAssets = maxAssets;
    maxRedeemShares = maxShares;
    emit MaxWithdrawChanged(maxAssets, maxShares);
  }

  /// @dev Set deposit/withdraw fees
  function setFees(uint _depositFee, uint _withdrawFee) external {
    require(isGovernance(msg.sender), "DENIED");
    require(_depositFee <= MAX_FEE && _withdrawFee <= MAX_FEE, "TOO_HIGH");

    depositFee = _depositFee;
    withdrawFee = _withdrawFee;
    emit FeeChanged(_depositFee, _withdrawFee);
  }

  /// @dev If activated will call doHardWork on splitter on each invest action.
  function setDoHardWorkOnInvest(bool value) external {
    require(isGovernance(msg.sender), "DENIED");
    emit DoHardWorkOnInvestChanged(doHardWorkOnInvest, value);
    doHardWorkOnInvest = value;
  }

  /// @dev Set splitter address. Can not change exist splitter.
  function setSplitter(address _splitter) external override {
    IERC20 asset_ = _asset;
    require(address(splitter) == address(0), "DENIED");
    _requireInterface(_splitter, InterfaceIds.I_SPLITTER);
    require(ISplitter(_splitter).asset() == address(asset_), "WRONG_UNDERLYING");
    require(ISplitter(_splitter).vault() == address(this), "WRONG_VAULT");
    require(IControllable(_splitter).isController(controller()), "WRONG_CONTROLLER");
    asset_.approve(_splitter, type(uint).max);
    splitter = ISplitter(_splitter);
    emit SplitterSetup(_splitter);
  }

  // *************************************************************
  //                        VIEWS
  // *************************************************************

  /// @dev Total amount of the underlying asset that is “managed” by Vault
  function totalAssets() public view override returns (uint) {
    return _asset.balanceOf(address(this)) + splitter.totalAssets();
  }

  /// @dev Amount of assets under control of strategy splitter.
  function splitterAssets() external view returns (uint) {
    return splitter.totalAssets();
  }

  /// @dev Price of 1 full share
  function sharePrice() external view returns (uint) {
    uint units = 10 ** uint256(decimals());
    uint totalSupply_ = totalSupply();
    return totalSupply_ == 0
    ? units
    : units * totalAssets() / totalSupply_;
  }

  /// @dev See {IERC165-supportsInterface}.
  function supportsInterface(bytes4 interfaceId) public view virtual override returns (bool) {
    return interfaceId == InterfaceIds.I_TETU_VAULT_V2 || super.supportsInterface(interfaceId);
  }

  // *************************************************************
  //                 DEPOSIT LOGIC
  // *************************************************************

  function previewDeposit(uint assets) public view virtual override returns (uint) {
    uint shares = convertToShares(assets);
    return shares - (shares * depositFee / FEE_DENOMINATOR);
  }

  function previewMint(uint shares) public view virtual override returns (uint) {
    uint supply = totalSupply();
    if (supply != 0) {
      uint assets = shares.mulDivUp(totalAssets(), supply);
      return assets * FEE_DENOMINATOR / (FEE_DENOMINATOR - depositFee);
    } else {
      return shares * FEE_DENOMINATOR / (FEE_DENOMINATOR - depositFee);
    }
  }

  /// @dev Calculate available to invest amount and send this amount to splitter
  function afterDeposit(uint assets, uint) internal override {
    address _splitter = address(splitter);
    IERC20 asset_ = _asset;
    uint _depositFee = depositFee;
    // send fee to insurance contract
    if (_depositFee != 0) {
      uint toFees = assets * _depositFee / FEE_DENOMINATOR;
      asset_.safeTransfer(address(insurance), toFees);
      emit FeeTransfer(toFees);
    }
    uint256 toInvest = _availableToInvest(_splitter, asset_);
    // invest only when buffer is filled
    if (toInvest > 0) {

      // need to check recursive hardworks
      if (doHardWorkOnInvest && !ISplitter(_splitter).isHardWorking()) {
        ISplitter(_splitter).doHardWork();
      }

      asset_.safeTransfer(_splitter, toInvest);
      ISplitter(_splitter).investAll();
      emit Invest(_splitter, toInvest);
    }
  }

  /// @notice Returns amount of assets ready to invest to the splitter
  function _availableToInvest(address _splitter, IERC20 asset_) internal view returns (uint) {
    uint _buffer = buffer;
    if (_splitter == address(0) || _buffer == BUFFER_DENOMINATOR) {
      return 0;
    }
    uint assetsInVault = asset_.balanceOf(address(this));
    uint assetsInSplitter = ISplitter(_splitter).totalAssets();
    uint wantInvestTotal = (assetsInVault + assetsInSplitter)
    * (BUFFER_DENOMINATOR - _buffer) / BUFFER_DENOMINATOR;
    if (assetsInSplitter >= wantInvestTotal) {
      return 0;
    } else {
      uint remainingToInvest = wantInvestTotal - assetsInSplitter;
      return remainingToInvest <= assetsInVault ? remainingToInvest : assetsInVault;
    }
  }

  // *************************************************************
  //                 WITHDRAW LOGIC
  // *************************************************************

  /// @dev Withdraw all available shares for tx sender.
  ///      The revert is expected if the balance is higher than `maxRedeem`
  function withdrawAll() external {
    redeem(balanceOf(msg.sender), msg.sender, msg.sender);
  }

  function previewWithdraw(uint assets) public view virtual override returns (uint) {
    uint supply = totalSupply();
    uint _totalAssets = totalAssets();
    if (_totalAssets == 0) {
      return assets;
    }
    uint shares = assets.mulDivUp(supply, _totalAssets);
    shares = shares * FEE_DENOMINATOR / (FEE_DENOMINATOR - withdrawFee);
    return supply == 0 ? assets : shares;
  }

  function previewRedeem(uint shares) public view virtual override returns (uint) {
    shares = shares - (shares * withdrawFee / FEE_DENOMINATOR);
    return convertToAssets(shares);
  }

  function maxDeposit(address) public view override returns (uint) {
    return maxDepositAssets;
  }

  function maxMint(address) public view override returns (uint) {
    return maxMintShares;
  }

  function maxWithdraw(address owner) public view override returns (uint) {
    uint assets = convertToAssets(balanceOf(owner));
    assets -= assets * withdrawFee / FEE_DENOMINATOR;
    return Math.min(maxWithdrawAssets, assets);
  }

  function maxRedeem(address owner) public view override returns (uint) {
    return Math.min(maxRedeemShares, balanceOf(owner));
  }

  /// @dev Internal hook for getting necessary assets from splitter.
  function beforeWithdraw(
    uint assets,
    uint shares
  ) internal override {
    uint _withdrawFee = withdrawFee;
    uint fromSplitter;
    if (_withdrawFee != 0) {
      // add fee amount
      fromSplitter = assets * FEE_DENOMINATOR / (FEE_DENOMINATOR - _withdrawFee);
    } else {
      fromSplitter = assets;
    }

    IERC20 asset_ = _asset;
    uint balance = asset_.balanceOf(address(this));
    // if not enough balance in the vault withdraw from strategies
    if (balance < fromSplitter) {
      _processWithdrawFromSplitter(
        fromSplitter,
        shares,
        totalSupply(),
        buffer,
        splitter,
        balance
      );
    }
    balance = asset_.balanceOf(address(this));
    require(assets <= balance, "SLIPPAGE");

    // send fee amount to insurance for keep correct calculations
    // in case of compensation it will lead to double transfer
    // but we assume that it will be rare case
    if (_withdrawFee != 0) {
      // we should compensate possible slippage from user fee too
      uint toFees = Math.min(fromSplitter - assets, balance - assets);
      if (toFees != 0) {
        asset_.safeTransfer(address(insurance), toFees);
        emit FeeTransfer(toFees);
      }
    }
  }

  /// @dev Do necessary calculation for withdrawing from splitter and move assets to vault.
  ///      If splitter not defined must not be called.
  function _processWithdrawFromSplitter(
    uint assetsNeed,
    uint shares,
    uint totalSupply_,
    uint _buffer,
    ISplitter _splitter,
    uint assetsInVault
  ) internal {
    // withdraw everything from the splitter to accurately check the share value
    if (shares == totalSupply_) {
      _splitter.withdrawAllToVault();
    } else {
      uint assetsInSplitter = _splitter.totalAssets();

      // we should always have buffer amount inside the vault
      // assume `assetsNeed` can not be higher than entire balance
      uint expectedBuffer = (assetsInSplitter + assetsInVault - assetsNeed) * _buffer / BUFFER_DENOMINATOR;

      // this code should not be called if `assetsInVault` higher than `assetsNeed`
      uint missing = Math.min(expectedBuffer + assetsNeed - assetsInVault, assetsInSplitter);
      // if zero should be resolved on splitter side
      _splitter.withdrawToVault(missing);
    }
  }

  // *************************************************************
  //                 INSURANCE LOGIC
  // *************************************************************

  function coverLoss(uint amount) external override {
    require(msg.sender == address(splitter), "!SPLITTER");
    IVaultInsurance _insurance = insurance;
    uint balance = _asset.balanceOf(address(_insurance));
    uint fromFees = Math.min(amount, balance);
    _insurance.transferToVault(fromFees);
    emit LossCovered(fromFees);
  }

  // *************************************************************
  //                 GAUGE HOOK
  // *************************************************************

  /// @dev Connect this vault to the gauge for non-contract addresses.
  function _afterTokenTransfer(
    address from,
    address to,
    uint
  ) internal override {
    gauge.handleBalanceChange(from);
    gauge.handleBalanceChange(to);
  }

}
