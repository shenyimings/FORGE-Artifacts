// SPDX-License-Identifier: MIT
pragma solidity 0.8.10;
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

/// @title extension to connect the referral system to any contract

abstract contract ExtensionReferralSystem {
    event SetPercentReward(uint256[] percentReward);

    using SafeERC20 for IERC20;
    uint256 constant PRECISION = 1e6;

    mapping(address => address) internal mapReferrer;

    uint256[] internal _percentReward;
    address _owner;

    /// @notice sets the amount of the reward and the number of levels in the referral program
    /// @dev the number of levels depends on the size of the array
    /// * the data inside the array shows the percentage of reward at each level
    /// @param percentReward the data must be specified taking into account the precission
    /// * the amount of data inside the array is equal to the number of levels
    /// * example [10000000, 5000000] equal first level =10%, second level = 5%
    function _setPercentReward(
        uint256[] memory percentReward
    ) internal virtual {
        delete (_percentReward);
        uint256 level = percentReward.length;
        for (uint256 i; i < level; i++) {
            _percentReward.push(percentReward[i]);
        }
        emit SetPercentReward(percentReward);
    }

    /// @notice set the referrer
    /// @param referral specify the referral address
    /// @param referrer rspecify the referrer address
    function _setReferrer(address referral, address referrer) internal virtual {
        mapReferrer[referral] = referrer;
    }

    /// @notice distribution of rewards to referrers
    /// @param amount the amount from which the percentage is calculated for the referral
    /// @param token address token
    /// @return amountWithoutFee returns the amount with the deduction of referral rewards
    function _distributeTheReward(
        address referral,
        uint256 amount,
        address token
    ) internal virtual returns (uint256 amountWithoutFee) {
        uint256 level = _percentReward.length;
        amountWithoutFee = amount;
        address newReferral = referral;

        for (uint256 i; i < level; i++) {
            newReferral = mapReferrer[newReferral];
            if (newReferral != address(0)) {
                uint256 value = _calcPercent(amount, _percentReward[i]);
                _send(newReferral, value, token);
                amountWithoutFee -= value;
            }
        }
    }

    function _send(
        address account,
        uint256 value,
        address token
    ) internal virtual {
        IERC20(token).safeTransfer(account, value);
    }

    function _calcPercent(
        uint256 value,
        uint256 percent
    ) internal pure virtual returns (uint256 res) {
        return ((percent * value) / (100 * PRECISION));
    }

    function getDataRefSystem()
        external
        view
        virtual
        returns (uint256[] memory percentReward, address owner)
    {
        return (_percentReward, _owner);
    }

    function getReferrer(
        address referral
    ) external view virtual returns (address referrer) {
        return mapReferrer[referral];
    }
}
