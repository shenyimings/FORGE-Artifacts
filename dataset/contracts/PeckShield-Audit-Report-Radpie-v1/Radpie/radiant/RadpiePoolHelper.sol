// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { ReentrancyGuardUpgradeable } from "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import { PausableUpgradeable } from "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";

import "../interfaces/IBaseRewardPool.sol";
import "../interfaces/IRadiantStaking.sol";
import "../interfaces/IRadpiePoolHelper.sol";

/// @title Radiant Loop Helper
/// @author Magpie Team
/// @notice This contract is the main contract that user will interact with in order to Loop Asset Token into Radiant . This
///         Helper will be shared among all assets on Radiant to Loop on Radpie.

contract RadpiePoolHelper is
    Initializable,
    OwnableUpgradeable,
    ReentrancyGuardUpgradeable,
    PausableUpgradeable
{
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */

    IRadiantStaking public radiantStaking;
    mapping(address => bool) private operator;

    /* ============ Events ============ */

    event NewDeposit(address indexed _user, address indexed _asset, uint256 _amount);
    event NewWithdraw(address indexed _user, address indexed _asset, uint256 _amount);

    /* ============ Errors ============ */

    error DeactivatePool();
    error NullAddress();
    error InvalidAmount();

    /* ============ Constructor ============ */

    function __RadpiePoolHelper_init(address _radiantStaking) public initializer {
        __Ownable_init();
        __ReentrancyGuard_init();
        __Pausable_init();
        radiantStaking = IRadiantStaking(_radiantStaking);
    }

    /* ============ Modifiers ============ */

    modifier onlyActivePool(address _asset) {
        (, , , , , , , , bool isActive) = radiantStaking.pools(_asset);
        if (!isActive) revert DeactivatePool();
        _;
    }

    /* ============ External Getters ============ */

    /// notice get the amount of total staked LP token in master magpie
    function totalStaked(address _asset) external view returns (uint256) {
        (, , , address rewarder, , , , ,) = radiantStaking.pools(_asset);
        return IBaseRewardPool(rewarder).totalStaked();
    }

    /// @notice get the total amount of shares of a user
    /// @param _asset the Pendle Asset token
    /// @param _address the user
    /// @return the amount of shares
    function balance(address _asset, address _address) external view returns (uint256) {
        (, , , address rewarder, , , , ,) = radiantStaking.pools(_asset);
        return IBaseRewardPool(rewarder).balanceOf(_address);
    }

    /* ============ External Functions ============ */

    function depositAsset(address _asset, uint256 _amount) external payable onlyActivePool(_asset) {
        (, , , , , , , bool isNative,) = radiantStaking.pools(_asset);
        if (isNative) {
            if (msg.value == 0) revert InvalidAmount();
            uint256 _amt = msg.value;
            _depositAssetNative(_asset, msg.sender, _amt);
        } else {
            if (_amount == 0 || msg.value != 0) revert InvalidAmount();
            _depositAsset(_asset, msg.sender, _amount);
        }
    }

    function withdrawAsset(address _asset, uint256 _amount) external {
        IRadiantStaking(radiantStaking).withdrawAssetFor(_asset, msg.sender, _amount);

        emit NewWithdraw(msg.sender, _asset, _amount);
    }

    function _depositAsset(address _asset, address _for, uint256 _amount) internal nonReentrant {
        IERC20(_asset).safeTransferFrom(msg.sender, address(radiantStaking), _amount);
        IRadiantStaking(radiantStaking).depositAssetFor(_asset, _for, _amount);

        emit NewDeposit(_for, _asset, _amount);
    }

    function _depositAssetNative(
        address _asset,
        address _for,
        uint256 _amount
    ) internal nonReentrant {
        IRadiantStaking(radiantStaking).depositAssetFor{ value: msg.value }(_asset, _for, _amount);

        emit NewDeposit(_for, _asset, _amount);
    }
}
