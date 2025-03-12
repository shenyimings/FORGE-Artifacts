// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {IAggregatorV3} from "kresko-lib/vendor/IAggregatorV3.sol";
import {IERC20} from "kresko-lib/token/IERC20.sol";
import {ERC20} from "kresko-lib/token/ERC20.sol";
import {SafeTransfer} from "kresko-lib/token/SafeTransfer.sol";
import {IVault} from "vault/interfaces/IVault.sol";

import {Arrays} from "libs/Arrays.sol";
import {FixedPointMath} from "libs/FixedPointMath.sol";

import {Errors} from "common/Errors.sol";
import {isSequencerUp} from "common/funcs/Utils.sol";
import {Validations} from "common/Validations.sol";

import {VEvent} from "vault/VEvent.sol";
import {VAssets} from "vault/funcs/VAssets.sol";
import {VaultAsset, VaultConfiguration} from "vault/VTypes.sol";

/**
 * @title Vault - A multiple deposit token vault.
 * @author Kresko
 * @notice This is derived from ERC4626 standard.
 * @notice Users deposit tokens into the vault and receive shares of equal value in return.
 * @notice Shares are redeemable for the underlying tokens at any time.
 * @notice Price or exchange rate of SHARE/USD is determined by the total value of the underlying tokens in the vault and the share supply.
 */
contract Vault is IVault, ERC20 {
    using SafeTransfer for IERC20;
    using FixedPointMath for uint256;
    using VAssets for uint256;
    using VAssets for VaultAsset;
    using Arrays for address[];

    /* -------------------------------------------------------------------------- */
    /*                                    State                                   */
    /* -------------------------------------------------------------------------- */
    VaultConfiguration internal _config;
    mapping(address => VaultAsset) internal _assets;
    address[] public assetList;

    constructor(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        uint8 _oracleDecimals,
        address _feeRecipient,
        address _sequencerUptimeFeed
    ) ERC20(_name, _symbol, _decimals) {
        _config.governance = msg.sender;
        _config.oracleDecimals = _oracleDecimals;
        _config.feeRecipient = _feeRecipient;
        _config.sequencerUptimeFeed = _sequencerUptimeFeed;
        _config.sequencerGracePeriodTime = 0;
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Modifiers                                 */
    /* -------------------------------------------------------------------------- */

    modifier onlyGovernance() {
        if (msg.sender != _config.governance) revert Errors.INVALID_SENDER(msg.sender, _config.governance);
        _;
    }

    modifier check(address assetAddr) {
        if (!_assets[assetAddr].enabled) revert Errors.ASSET_NOT_ENABLED(Errors.id(assetAddr));
        _;
    }

    /// @notice Validate deposits.
    function _checkAssetsIn(address assetAddr, uint256 assetsIn, uint256 sharesOut) private view {
        uint256 depositLimit = maxDeposit(assetAddr);

        if (sharesOut == 0) revert Errors.ZERO_SHARES_OUT(Errors.id(assetAddr), assetsIn);
        if (assetsIn == 0) revert Errors.ZERO_ASSETS_IN(Errors.id(assetAddr), sharesOut);
        if (assetsIn > depositLimit) revert Errors.EXCEEDS_ASSET_DEPOSIT_LIMIT(Errors.id(assetAddr), assetsIn, depositLimit);
    }

    /* -------------------------------------------------------------------------- */
    /*                                Functionality                               */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IVault
    function deposit(
        address assetAddr,
        uint256 assetsIn,
        address receiver
    ) public virtual check(assetAddr) returns (uint256 sharesOut, uint256 assetFee) {
        (sharesOut, assetFee) = previewDeposit(assetAddr, assetsIn);

        _checkAssetsIn(assetAddr, assetsIn, sharesOut);

        IERC20 token = IERC20(assetAddr);

        token.safeTransferFrom(msg.sender, address(this), assetsIn);

        if (assetFee > 0) token.safeTransfer(_config.feeRecipient, assetFee);

        _mint(receiver == address(0) ? msg.sender : receiver, sharesOut);

        emit VEvent.Deposit(msg.sender, receiver, assetAddr, assetsIn, sharesOut);
    }

    /// @inheritdoc IVault
    function mint(
        address assetAddr,
        uint256 sharesOut,
        address receiver
    ) public virtual check(assetAddr) returns (uint256 assetsIn, uint256 assetFee) {
        (assetsIn, assetFee) = previewMint(assetAddr, sharesOut);

        _checkAssetsIn(assetAddr, assetsIn, sharesOut);

        IERC20 token = IERC20(assetAddr);

        token.safeTransferFrom(msg.sender, address(this), assetsIn);

        if (assetFee > 0) token.safeTransfer(_config.feeRecipient, assetFee);

        _mint(receiver == address(0) ? msg.sender : receiver, sharesOut);

        emit VEvent.Deposit(msg.sender, receiver, assetAddr, assetsIn, sharesOut);
    }

    /// @inheritdoc IVault
    function redeem(
        address assetAddr,
        uint256 sharesIn,
        address receiver,
        address owner
    ) public virtual check(assetAddr) returns (uint256 assetsOut, uint256 assetFee) {
        (assetsOut, assetFee) = previewRedeem(assetAddr, sharesIn);

        if (assetsOut == 0) revert Errors.ZERO_ASSETS_OUT(Errors.id(assetAddr), sharesIn);

        if (msg.sender != owner) {
            uint256 allowed = _allowances[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) _allowances[owner][msg.sender] = allowed - sharesIn;
        }

        IERC20 token = IERC20(assetAddr);

        uint256 balance = token.balanceOf(address(this));

        if (assetsOut + assetFee > balance) {
            assetsOut = balance;
            (sharesIn, assetFee) = previewWithdraw(assetAddr, assetsOut);
            token.safeTransfer(receiver, assetsOut - assetFee);
        } else {
            token.safeTransfer(receiver, assetsOut);
        }

        if (assetFee > 0) token.safeTransfer(_config.feeRecipient, assetFee);

        _burn(owner, sharesIn);

        emit VEvent.Withdraw(msg.sender, receiver, assetAddr, owner, assetsOut, sharesIn);
    }

    /// @inheritdoc IVault
    function withdraw(
        address assetAddr,
        uint256 assetsOut,
        address receiver,
        address owner
    ) public virtual check(assetAddr) returns (uint256 sharesIn, uint256 assetFee) {
        (sharesIn, assetFee) = previewWithdraw(assetAddr, assetsOut);

        if (sharesIn == 0) revert Errors.ZERO_SHARES_IN(Errors.id(assetAddr), assetsOut);

        if (msg.sender != owner) {
            uint256 allowed = _allowances[owner][msg.sender]; // Saves gas for limited approvals.

            if (allowed != type(uint256).max) _allowances[owner][msg.sender] = allowed - sharesIn;
        }

        IERC20 token = IERC20(assetAddr);

        if (assetFee > 0) token.safeTransfer(_config.feeRecipient, assetFee);

        _burn(owner, sharesIn);

        token.safeTransfer(receiver, assetsOut);

        emit VEvent.Withdraw(msg.sender, receiver, assetAddr, owner, assetsOut, sharesIn);
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Views                                   */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IVault
    function getConfig() external view returns (VaultConfiguration memory) {
        return _config;
    }

    /// @inheritdoc IVault
    function assets(address assetAddr) external view returns (VaultAsset memory) {
        return _assets[assetAddr];
    }

    function assetPrice(address assetAddr) external view returns (uint256) {
        return _assets[assetAddr].price(_config);
    }

    /// @inheritdoc IVault
    function totalAssets() public view virtual returns (uint256 result) {
        for (uint256 i; i < assetList.length; ) {
            result += _assets[assetList[i]].getDepositValueWad(_config);
            unchecked {
                i++;
            }
        }
    }

    /// @inheritdoc IVault
    function exchangeRate() public view virtual returns (uint256) {
        uint256 tAssets = totalAssets();
        uint256 tSupply = totalSupply();
        if (tSupply == 0 || tAssets == 0) return 1e18;
        return (tAssets * 1e18) / tSupply;
    }

    /// @inheritdoc IVault
    function previewDeposit(
        address assetAddr,
        uint256 assetsIn
    ) public view virtual returns (uint256 sharesOut, uint256 assetFee) {
        uint256 tSupply = totalSupply();
        uint256 tAssets = totalAssets();
        if (tSupply == 0) tSupply = 1e18;
        if (tAssets == 0) tAssets = 1e18;
        VaultAsset storage asset = _assets[assetAddr];
        (assetsIn, assetFee) = asset.handleDepositFee(assetsIn);
        sharesOut = asset.usdWad(_config, assetsIn).mulDivDown(tSupply, tAssets);
    }

    /// @inheritdoc IVault
    function previewMint(
        address assetAddr,
        uint256 sharesOut
    ) public view virtual returns (uint256 assetsIn, uint256 assetFee) {
        uint256 tSupply = totalSupply();
        uint256 tAssets = totalAssets();

        if (tSupply == 0) tSupply = 1e18;
        if (tAssets == 0) tAssets = 1e18;

        VaultAsset storage asset = _assets[assetAddr];

        (assetsIn, assetFee) = asset.handleMintFee(asset.getAmount(_config, sharesOut.mulDivUp(tAssets, tSupply)));
    }

    /// @inheritdoc IVault
    function previewRedeem(
        address assetAddr,
        uint256 sharesIn
    ) public view virtual returns (uint256 assetsOut, uint256 assetFee) {
        uint256 tSupply = totalSupply();
        uint256 tAssets = totalAssets();

        if (tSupply == 0) tSupply = 1e18;
        if (tAssets == 0) tAssets = 1e18;

        VaultAsset storage asset = _assets[assetAddr];
        (assetsOut, assetFee) = asset.handleRedeemFee(asset.getAmount(_config, sharesIn.mulDivDown(tAssets, tSupply)));
    }

    /// @inheritdoc IVault
    function previewWithdraw(
        address assetAddr,
        uint256 assetsOut
    ) public view virtual returns (uint256 sharesIn, uint256 assetFee) {
        uint256 tSupply = totalSupply();
        uint256 tAssets = totalAssets();

        if (tSupply == 0) tSupply = 1e18;
        if (tAssets == 0) tAssets = 1e18;

        VaultAsset storage asset = _assets[assetAddr];

        (assetsOut, assetFee) = asset.handleWithdrawFee(assetsOut);

        sharesIn = asset.usdWad(_config, assetsOut).mulDivUp(tSupply, tAssets);

        if (sharesIn > tSupply) revert Errors.ROUNDING_ERROR(Errors.id(assetAddr), sharesIn, tSupply);
    }

    /// @inheritdoc IVault
    function maxRedeem(address assetAddr, address owner) public view virtual returns (uint256 max) {
        (uint256 assetsOut, uint256 fee) = previewRedeem(assetAddr, _balances[owner]);
        uint256 balance = IERC20(assetAddr).balanceOf(address(this));

        if (assetsOut + fee > balance) {
            assetsOut = balance;
            (max, ) = previewWithdraw(assetAddr, assetsOut);
        } else {
            return _balances[owner];
        }
    }

    /// @inheritdoc IVault
    function maxWithdraw(address assetAddr, address owner) external view returns (uint256 max) {
        (max, ) = previewRedeem(assetAddr, maxRedeem(assetAddr, owner));
    }

    /// @inheritdoc IVault
    function maxDeposit(address assetAddr) public view virtual returns (uint256) {
        return _assets[assetAddr].maxDeposits - _assets[assetAddr].token.balanceOf(address(this));
    }

    /// @inheritdoc IVault
    function maxMint(address assetAddr, address user) external view virtual returns (uint256 max) {
        uint256 balance = IERC20(assetAddr).balanceOf(user);
        uint256 depositLimit = maxDeposit(assetAddr);
        if (balance > depositLimit) {
            (max, ) = previewDeposit(assetAddr, depositLimit);
        } else {
            (max, ) = previewDeposit(assetAddr, balance);
        }
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Admin                                   */
    /* -------------------------------------------------------------------------- */
    function setSequencerUptimeFeed(address newFeedAddr, uint96 gracePeriod) external onlyGovernance {
        if (newFeedAddr != address(0)) {
            if (!isSequencerUp(newFeedAddr, gracePeriod)) revert Errors.INVALID_SEQUENCER_UPTIME_FEED(newFeedAddr);
        }
        _config.sequencerUptimeFeed = newFeedAddr;
        _config.sequencerGracePeriodTime = gracePeriod;
    }

    /// @inheritdoc IVault
    function addAsset(VaultAsset memory assetConfig) external onlyGovernance returns (VaultAsset memory) {
        address assetAddr = address(assetConfig.token);
        if (assetAddr == address(0)) revert Errors.ZERO_ADDRESS();
        if (_assets[assetAddr].decimals != 0) revert Errors.ASSET_ALREADY_EXISTS(Errors.id(assetAddr));

        assetConfig.decimals = assetConfig.token.decimals();
        Validations.validateVaultAssetDecimals(assetAddr, assetConfig.decimals);
        Validations.validateFees(assetAddr, uint16(assetConfig.depositFee), uint16(assetConfig.withdrawFee));

        _assets[assetAddr] = assetConfig;
        assetList.pushUnique(assetAddr);

        emit VEvent.AssetAdded(
            assetAddr,
            address(assetConfig.feed),
            assetConfig.token.symbol(),
            assetConfig.staleTime,
            _assets[assetAddr].price(_config),
            assetConfig.maxDeposits,
            block.timestamp
        );

        return assetConfig;
    }

    /// @inheritdoc IVault
    function removeAsset(address assetAddr) external onlyGovernance {
        assetList.removeExisting(assetAddr);
        delete _assets[assetAddr];
        emit VEvent.AssetRemoved(assetAddr, block.timestamp);
    }

    /// @inheritdoc IVault
    function setAssetFeed(address assetAddr, address newFeedAddr, uint24 newStaleTime) external onlyGovernance {
        _assets[assetAddr].feed = IAggregatorV3(newFeedAddr);
        _assets[assetAddr].staleTime = newStaleTime;
        emit VEvent.OracleSet(assetAddr, newFeedAddr, newStaleTime, _assets[assetAddr].price(_config), block.timestamp);
    }

    /// @inheritdoc IVault
    function setFeedPricePrecision(uint8 newDecimals) external onlyGovernance {
        _config.oracleDecimals = newDecimals;
    }

    /// @inheritdoc IVault
    function setAssetEnabled(address assetAddr, bool isEnabled) external onlyGovernance {
        _assets[assetAddr].enabled = isEnabled;
        emit VEvent.AssetEnabledChange(assetAddr, isEnabled, block.timestamp);
    }

    /// @inheritdoc IVault
    function setDepositFee(address assetAddr, uint16 newDepositFee) external onlyGovernance {
        Validations.validateFees(assetAddr, newDepositFee, newDepositFee);
        _assets[assetAddr].depositFee = newDepositFee;
    }

    /// @inheritdoc IVault
    function setWithdrawFee(address assetAddr, uint16 newWithdrawFee) external onlyGovernance {
        Validations.validateFees(assetAddr, newWithdrawFee, newWithdrawFee);
        _assets[assetAddr].withdrawFee = newWithdrawFee;
    }

    /// @inheritdoc IVault
    function setMaxDeposits(address assetAddr, uint248 newMaxDeposits) external onlyGovernance {
        _assets[assetAddr].maxDeposits = newMaxDeposits;
    }

    /// @inheritdoc IVault
    function setGovernance(address newGovernance) external onlyGovernance {
        _config.governance = newGovernance;
    }

    /// @inheritdoc IVault
    function setFeeRecipient(address newFeeRecipient) external onlyGovernance {
        _config.feeRecipient = newFeeRecipient;
    }
}
