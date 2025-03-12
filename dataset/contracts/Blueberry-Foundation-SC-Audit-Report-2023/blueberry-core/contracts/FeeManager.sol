// SPDX-License-Identifier: MIT
/*
██████╗ ██╗     ██╗   ██╗███████╗██████╗ ███████╗██████╗ ██████╗ ██╗   ██╗
██╔══██╗██║     ██║   ██║██╔════╝██╔══██╗██╔════╝██╔══██╗██╔══██╗╚██╗ ██╔╝
██████╔╝██║     ██║   ██║█████╗  ██████╔╝█████╗  ██████╔╝██████╔╝ ╚████╔╝
██╔══██╗██║     ██║   ██║██╔══╝  ██╔══██╗██╔══╝  ██╔══██╗██╔══██╗  ╚██╔╝
██████╔╝███████╗╚██████╔╝███████╗██████╔╝███████╗██║  ██║██║  ██║   ██║
╚═════╝ ╚══════╝ ╚═════╝ ╚══════╝╚═════╝ ╚══════╝╚═╝  ╚═╝╚═╝  ╚═╝   ╚═╝
*/

pragma solidity 0.8.16;

import "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "./interfaces/IProtocolConfig.sol";
import "./utils/BlueBerryConst.sol" as Constants;
import "./utils/BlueBerryErrors.sol" as Errors;

contract FeeManager is OwnableUpgradeable {
    using SafeERC20Upgradeable for IERC20Upgradeable;

    IProtocolConfig public config;

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() {
        _disableInitializers();
    }

    function initialize(IProtocolConfig config_) external initializer {
        __Ownable_init();

        if (address(config_) == address(0)) revert Errors.ZERO_ADDRESS();
        config = config_;
    }

    /// @notice Cut deposit fee when lending isolated underlying assets to Blueberry Money Market
    /// @param token underlying token address
    /// @param amount deposit amount
    function doCutDepositFee(
        address token,
        uint256 amount
    ) external returns (uint256) {
        return _doCutFee(token, amount, config.depositFee());
    }

    /// @notice Cut withdraw fee when redeeming isolated underlying tokens from Blueberry Money Market
    /// @param token underlying token address
    /// @param amount withdraw amount
    function doCutWithdrawFee(
        address token,
        uint256 amount
    ) external returns (uint256) {
        return _doCutFee(token, amount, config.withdrawFee());
    }

    /// @notice Cut performance fee from the rewards generated from the leveraged position
    /// @param token reward token address
    /// @param amount reward amount
    function doCutRewardsFee(
        address token,
        uint256 amount
    ) external returns (uint256) {
        return _doCutFee(token, amount, config.rewardFee());
    }

    /// @notice Cut vault withdraw fee when perform withdraw from Blueberry Money Market within the given window
    /// @param token underlying token address
    /// @param amount withdraw amount
    function doCutVaultWithdrawFee(
        address token,
        uint256 amount
    ) external returns (uint256) {
        // Cut withdraw fee if it is in withdrawVaultFee Window (2 months)
        if (
            block.timestamp <
            config.withdrawVaultFeeWindowStartTime() +
                config.withdrawVaultFeeWindow()
        ) {
            return _doCutFee(token, amount, config.withdrawVaultFee());
        } else {
            return amount;
        }
    }

    /// @dev Cut fee from given amount with given rate and send fee to the treasury
    /// @param token fee token address
    /// @param amount total amount to cut fee from
    /// @param feeRate fee rate, based 10000
    function _doCutFee(
        address token,
        uint256 amount,
        uint256 feeRate
    ) internal returns (uint256) {
        address treasury = config.treasury();
        if (treasury == address(0)) revert Errors.NO_TREASURY_SET();

        uint256 fee = (amount * feeRate) / Constants.DENOMINATOR;
        if (fee > 0) {
            IERC20Upgradeable(token).safeTransferFrom(
                msg.sender,
                treasury,
                fee
            );
        }
        return amount - fee;
    }
}
