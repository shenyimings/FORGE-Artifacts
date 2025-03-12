// SPDX-License-Identifier: AGPL-3.0-only
pragma solidity ^0.8.10;

import {ERC20} from "solmate/tokens/ERC20.sol";
import {ERC4626} from "solmate/mixins/ERC4626.sol";
import {AccessControl} from "openzeppelin-contracts/access/AccessControl.sol";
import {Constants as C} from "./lib/Constants.sol";
import {
    CallerNotAdmin,
    CallerNotKeeper,
    ZeroAddress,
    InvalidFlashLoanCaller,
    TreasuryCannotBeZero,
    FeesTooHigh,
    InvalidFloatPercentage,
    InvalidSlippageTolerance
} from "./errors/scErrors.sol";

abstract contract sc4626 is ERC4626, AccessControl {
    constructor(address _admin, address _keeper, ERC20 _asset, string memory _name, string memory _symbol)
        ERC4626(_asset, _name, _symbol)
    {
        if (_admin == address(0)) revert ZeroAddress();
        if (_keeper == address(0)) revert ZeroAddress();

        _grantRole(DEFAULT_ADMIN_ROLE, _admin);
        _grantRole(KEEPER_ROLE, _keeper);
    }

    event TreasuryUpdated(address indexed user, address newTreasury);
    event PerformanceFeeUpdated(address indexed user, uint256 newPerformanceFee);
    event FloatPercentageUpdated(address indexed user, uint256 newFloatPercentage);
    event SlippageToleranceUpdated(address indexed admin, uint256 newSlippageTolerance);

    /// Role allowed to harvest/reinvest
    bytes32 public constant KEEPER_ROLE = keccak256("KEEPER_ROLE");

    // flag for checking flash loan caller
    bool public flashLoanInitiated;

    // address of the treasury to send performance fees to
    address public treasury;

    // performance fee percentage
    uint256 public performanceFee = 0.1e18; // 10%

    // percentage of the total assets to be kept in the vault as a withdrawal buffer
    uint256 public floatPercentage = 0.01e18;

    // max slippage tolerance for swaps
    uint256 public slippageTolerance = 0.99e18; // 1% default

    /// @notice set the treasury address
    /// @param _newTreasury the new treasury address
    function setTreasury(address _newTreasury) external {
        _onlyAdmin();

        if (_newTreasury == address(0)) revert TreasuryCannotBeZero();
        treasury = _newTreasury;
        emit TreasuryUpdated(msg.sender, _newTreasury);
    }

    /// @notice set the performance fee percentage
    /// @param _newPerformanceFee the new performance fee percentage
    /// @dev performance fee is a number between 0 and 1e18
    function setPerformanceFee(uint256 _newPerformanceFee) external {
        _onlyAdmin();

        if (_newPerformanceFee > 1e18) revert FeesTooHigh();
        performanceFee = _newPerformanceFee;
        emit PerformanceFeeUpdated(msg.sender, _newPerformanceFee);
    }

    /**
     * @notice Set the percentage of the total assets to be kept in the vault as a withdrawal buffer.
     * @param _newFloatPercentage The new float percentage value.
     */
    function setFloatPercentage(uint256 _newFloatPercentage) external {
        _onlyAdmin();

        if (_newFloatPercentage > C.ONE) revert InvalidFloatPercentage();

        floatPercentage = _newFloatPercentage;
        emit FloatPercentageUpdated(msg.sender, _newFloatPercentage);
    }

    /**
     * @notice Set the default slippage tolerance for swapping tokens.
     * @param _newSlippageTolerance The new slippage tolerance value.
     */
    function setSlippageTolerance(uint256 _newSlippageTolerance) external {
        _onlyAdmin();

        if (_newSlippageTolerance > C.ONE) revert InvalidSlippageTolerance();

        slippageTolerance = _newSlippageTolerance;

        emit SlippageToleranceUpdated(msg.sender, _newSlippageTolerance);
    }

    function _onlyAdmin() internal view {
        if (!hasRole(DEFAULT_ADMIN_ROLE, msg.sender)) revert CallerNotAdmin();
    }

    function _onlyKeeper() internal view {
        if (!hasRole(KEEPER_ROLE, msg.sender)) revert CallerNotKeeper();
    }

    function _onlyKeeperOrFlashLoan() internal view {
        if (!flashLoanInitiated) _onlyKeeper();
    }

    function _initiateFlashLoan() internal {
        flashLoanInitiated = true;
    }

    function _finalizeFlashLoan() internal {
        flashLoanInitiated = false;
    }

    function _isFlashLoanInitiated() internal view {
        if (!flashLoanInitiated) revert InvalidFlashLoanCaller();
    }
}
