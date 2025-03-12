// solhint-disable no-empty-blocks
// SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.21;

import {AccessControlEnumerableUpgradeable} from "@oz-upgradeable/access/extensions/AccessControlEnumerableUpgradeable.sol";
import {PausableUpgradeable} from "@oz-upgradeable/utils/PausableUpgradeable.sol";
import {SafeTransfer} from "kresko-lib/token/SafeTransfer.sol";
import {ERC20Upgradeable} from "kresko-lib/token/ERC20Upgradeable.sol";
import {IERC20} from "kresko-lib/token/IERC20.sol";
import {IERC165} from "vendor/IERC165.sol";
import {PercentageMath} from "libs/PercentageMath.sol";
import {Percents, Role} from "common/Constants.sol";
import {Errors} from "common/Errors.sol";
import {IKreskoAssetAnchor} from "./IKreskoAssetAnchor.sol";
import {Rebaser} from "./Rebaser.sol";
import {IKreskoAsset, ISyncable} from "./IKreskoAsset.sol";

/**
 * @title Kresko Synthethic Asset, rebasing ERC20 with underlying wrapping.
 * @author Kresko
 * @notice Rebases to adjust for stock splits and reverse stock splits
 * @notice Minting, burning and rebasing can only be performed by the `Role.OPERATOR`
 */

contract KreskoAsset is ERC20Upgradeable, AccessControlEnumerableUpgradeable, PausableUpgradeable, IKreskoAsset {
    using SafeTransfer for IERC20;
    using SafeTransfer for address payable;
    using Rebaser for uint256;
    using PercentageMath for uint256;

    Rebase private rebasing;
    bool public isRebased;
    address public kresko;
    address public anchor;
    Wrapping private wrapping;

    constructor() {
        // _disableInitializers();
    }

    /// @inheritdoc IKreskoAsset
    function initialize(
        string memory _name,
        string memory _symbol,
        uint8 _decimals,
        address _admin,
        address _kresko,
        address _underlying,
        address _feeRecipient,
        uint48 _openFee,
        uint40 _closeFee
    ) external initializer {
        // SetupERC20
        __ERC20Upgradeable_init(_name, _symbol, _decimals);

        // Setup pausable
        __Pausable_init();

        // Setup the protocol
        kresko = _kresko;
        _grantRole(Role.OPERATOR, _kresko);

        // Setup the state
        _grantRole(Role.ADMIN, msg.sender);
        setUnderlying(_underlying);
        setFeeRecipient(_feeRecipient);
        setOpenFee(_openFee);
        setCloseFee(_closeFee);
        // Revoke admin rights after state setup
        _revokeRole(Role.ADMIN, msg.sender);

        // Setup the admin
        _grantRole(Role.DEFAULT_ADMIN, _admin);
        _grantRole(Role.ADMIN, _admin);
    }

    /// @inheritdoc IKreskoAsset
    function setAnchorToken(address _anchor) external {
        if (_anchor == address(0)) revert Errors.ZERO_ADDRESS();

        // allows easy initialization from anchor itself
        if (anchor != address(0)) _checkRole(Role.ADMIN);

        anchor = _anchor;
        _grantRole(Role.OPERATOR, _anchor);
    }

    /// @inheritdoc IKreskoAsset
    function setUnderlying(address _underlyingAddr) public onlyRole(Role.ADMIN) {
        wrapping.underlying = _underlyingAddr;
        if (_underlyingAddr != address(0)) {
            wrapping.underlyingDecimals = IERC20(wrapping.underlying).decimals();
        }
    }

    /// @inheritdoc IKreskoAsset
    function enableNativeUnderlying(bool _enabled) external onlyRole(Role.ADMIN) {
        wrapping.nativeUnderlyingEnabled = _enabled;
    }

    /// @inheritdoc IKreskoAsset
    function setFeeRecipient(address _feeRecipient) public onlyRole(Role.ADMIN) {
        if (_feeRecipient == address(0)) revert Errors.ZERO_ADDRESS();
        wrapping.feeRecipient = payable(_feeRecipient);
    }

    /// @inheritdoc IKreskoAsset
    function setOpenFee(uint48 _openFee) public onlyRole(Role.ADMIN) {
        if (_openFee > Percents.HUNDRED) revert Errors.INVALID_FEE(_assetId(), _openFee, Percents.HUNDRED);
        wrapping.openFee = _openFee;
    }

    /// @inheritdoc IKreskoAsset
    function setCloseFee(uint40 _closeFee) public onlyRole(Role.ADMIN) {
        if (_closeFee > Percents.HUNDRED) revert Errors.INVALID_FEE(_assetId(), _closeFee, Percents.HUNDRED);
        wrapping.closeFee = _closeFee;
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Read                                    */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IERC165
    function supportsInterface(
        bytes4 interfaceId
    ) public view virtual override(AccessControlEnumerableUpgradeable, IERC165) returns (bool) {
        return (interfaceId != 0xffffffff &&
            (interfaceId == type(IKreskoAsset).interfaceId ||
                interfaceId == 0x01ffc9a7 ||
                interfaceId == 0x36372b07 ||
                super.supportsInterface(interfaceId)));
    }

    function wrappingInfo() external view override returns (Wrapping memory) {
        return wrapping;
    }

    /// @inheritdoc IKreskoAsset
    function rebaseInfo() external view override returns (Rebase memory) {
        return rebasing;
    }

    /// @inheritdoc IERC20
    function totalSupply() public view override(ERC20Upgradeable, IERC20) returns (uint256) {
        return _totalSupply.rebase(rebasing);
    }

    /// @inheritdoc IERC20
    function balanceOf(address _account) public view override(ERC20Upgradeable, IERC20) returns (uint256) {
        return _balances[_account].rebase(rebasing);
    }

    /// @inheritdoc IERC20
    function allowance(address _owner, address _account) public view override(ERC20Upgradeable, IERC20) returns (uint256) {
        return _allowances[_owner][_account];
    }

    /// @inheritdoc IKreskoAsset
    function pause() public onlyRole(Role.ADMIN) {
        _pause();
    }

    /// @inheritdoc IKreskoAsset
    function unpause() public onlyRole(Role.ADMIN) {
        _unpause();
    }

    /* -------------------------------------------------------------------------- */
    /*                                    Write                                   */
    /* -------------------------------------------------------------------------- */
    /// @inheritdoc IKreskoAsset
    function reinitializeERC20(
        string memory _name,
        string memory _symbol,
        uint8 _version
    ) external onlyRole(Role.ADMIN) reinitializer(_version) {
        __ERC20Upgradeable_init(_name, _symbol, decimals);
    }

    /// @inheritdoc IERC20
    function approve(address _spender, uint256 _amount) public override(ERC20Upgradeable, IERC20) returns (bool) {
        _allowances[msg.sender][_spender] = _amount;
        emit Approval(msg.sender, _spender, _amount);
        return true;
    }

    /// @inheritdoc IERC20
    function transfer(address _to, uint256 _amount) public override(ERC20Upgradeable, IERC20) returns (bool) {
        return _transfer(msg.sender, _to, _amount);
    }

    /// @inheritdoc IERC20
    function transferFrom(
        address _from,
        address _to,
        uint256 _amount
    ) public override(ERC20Upgradeable, IERC20) returns (bool) {
        uint256 allowed = allowance(_from, msg.sender); // Saves gas for unlimited approvals.

        if (allowed != type(uint256).max) {
            if (_amount > allowed) revert Errors.NO_ALLOWANCE(msg.sender, _from, _amount, allowed);
            _allowances[_from][msg.sender] -= _amount;
        }

        return _transfer(_from, _to, _amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                 Restricted                                 */
    /* -------------------------------------------------------------------------- */

    /// @inheritdoc IKreskoAsset
    function rebase(uint248 _denominator, bool _positive, address[] calldata _pools) external onlyRole(Role.ADMIN) {
        if (_denominator < 1 ether) revert Errors.INVALID_DENOMINATOR(_assetId(), _denominator, 1 ether);
        if (_denominator == 1 ether) {
            isRebased = false;
            rebasing = Rebase(0, false);
        } else {
            isRebased = true;
            rebasing = Rebase(_denominator, _positive);
        }
        uint256 length = _pools.length;
        for (uint256 i; i < length; ) {
            ISyncable(_pools[i]).sync();
            unchecked {
                ++i;
            }
        }
    }

    /// @inheritdoc IKreskoAsset
    function mint(address _to, uint256 _amount) external onlyRole(Role.OPERATOR) {
        _requireNotPaused();
        _mint(_to, _amount);
    }

    /// @inheritdoc IKreskoAsset
    function burn(address _from, uint256 _amount) external onlyRole(Role.OPERATOR) {
        _requireNotPaused();
        _burn(_from, _amount);
    }

    /// @inheritdoc IKreskoAsset
    function wrap(address _to, uint256 _amount) external {
        _requireNotPaused();

        address underlying = wrapping.underlying;
        if (underlying == address(0)) {
            revert Errors.WRAP_NOT_SUPPORTED();
        }

        IERC20(underlying).safeTransferFrom(msg.sender, address(this), _amount);
        uint256 openFee = wrapping.openFee;
        if (openFee > 0) {
            uint256 fee = _amount.percentMul(openFee);
            _amount -= fee;
            IERC20(underlying).safeTransfer(address(wrapping.feeRecipient), fee);
        }

        _amount = _adjustDecimals(_amount, wrapping.underlyingDecimals, decimals);
        _mint(_to, _amount);

        IKreskoAssetAnchor(anchor).wrap(_amount);

        emit Wrap(address(this), underlying, _to, _amount);
    }

    /// @inheritdoc IKreskoAsset
    function unwrap(uint256 _amount, bool _receiveNative) external {
        _requireNotPaused();

        address underlying = wrapping.underlying;
        if (underlying == address(0)) {
            revert Errors.WRAP_NOT_SUPPORTED();
        }

        uint256 adjustedAmount = _adjustDecimals(_amount, wrapping.underlyingDecimals, decimals);

        _burn(msg.sender, adjustedAmount);
        IKreskoAssetAnchor(anchor).unwrap(adjustedAmount);

        bool allowNative = _receiveNative && wrapping.nativeUnderlyingEnabled;

        uint256 closeFee = wrapping.closeFee;
        if (closeFee > 0) {
            uint256 fee = _amount.percentMul(closeFee);
            _amount -= fee;

            if (!allowNative) {
                IERC20(underlying).safeTransfer(wrapping.feeRecipient, fee);
            } else {
                wrapping.feeRecipient.safeTransferETH(fee);
            }
        }
        if (!allowNative) {
            IERC20(underlying).safeTransfer(msg.sender, _amount);
        } else {
            payable(msg.sender).safeTransferETH(_amount);
        }

        emit Unwrap(address(this), underlying, msg.sender, _amount);
    }

    receive() external payable {
        _requireNotPaused();
        if (!wrapping.nativeUnderlyingEnabled) revert Errors.NATIVE_TOKEN_DISABLED(_assetId());

        uint256 amount = msg.value;
        if (amount == 0) revert Errors.ZERO_AMOUNT(_assetId());

        uint256 openFee = wrapping.openFee;
        if (openFee > 0) {
            uint256 fee = amount.percentMul(openFee);
            amount -= fee;
            wrapping.feeRecipient.safeTransferETH(fee);
        }

        _mint(msg.sender, amount);
        IKreskoAssetAnchor(anchor).wrap(amount);

        emit Wrap(address(this), address(0), msg.sender, amount);
    }

    /* -------------------------------------------------------------------------- */
    /*                                  Internal                                  */
    /* -------------------------------------------------------------------------- */

    function _mint(address _to, uint256 _amount) internal override {
        uint256 normalizedAmount = _amount.unrebase(rebasing);
        unchecked {
            _totalSupply += normalizedAmount;
        }

        // Cannot overflow because the sum of all user
        // balances can't exceed the max uint256 value.
        unchecked {
            _balances[_to] += normalizedAmount;
        }
        // Emit user input amount, not the maybe unrebased amount.
        emit Transfer(address(0), _to, _amount);
    }

    function _burn(address _from, uint256 _amount) internal override {
        uint256 normalizedAmount = _amount.unrebase(rebasing);

        _balances[_from] -= normalizedAmount;
        // Cannot underflow because a user's balance
        // will never be larger than the total supply.
        unchecked {
            _totalSupply -= normalizedAmount;
        }

        emit Transfer(_from, address(0), _amount);
    }

    /// @dev Internal balances are always unrebased, events emitted are not.
    function _transfer(address _from, address _to, uint256 _amount) internal returns (bool) {
        _requireNotPaused();
        uint256 bal = balanceOf(_from);
        if (_amount > bal) revert Errors.NOT_ENOUGH_BALANCE(_from, _amount, bal);
        uint256 normalizedAmount = _amount.unrebase(rebasing);

        _balances[_from] -= normalizedAmount;
        unchecked {
            _balances[_to] += normalizedAmount;
        }

        // Emit user input amount, not the maybe unrebased amount.
        emit Transfer(_from, _to, _amount);
        return true;
    }

    function _adjustDecimals(uint256 _amount, uint8 _fromDecimal, uint8 _toDecimal) internal pure returns (uint256) {
        if (_fromDecimal == _toDecimal) return _amount;
        return
            _fromDecimal < _toDecimal
                ? _amount * (10 ** (_toDecimal - _fromDecimal))
                : _amount / (10 ** (_fromDecimal - _toDecimal));
    }

    function _assetId() internal view returns (Errors.ID memory) {
        return Errors.ID(symbol, address(this));
    }
}
