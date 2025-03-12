// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

/**
 * @title Interface for liquidity gauge.
 */
interface IGauge is IERC20Upgradeable {

    /**
     * @dev Returns the address of the staked token.
     */
    function token() external view returns (address);

    /**
     * @dev Checkpoints the liquidity gauge.
     */
    function checkpoint() external;

    /**
     * @dev Returns the total amount of token staked in the gauge.
     */
    function totalStaked() external view returns (uint256);

    /**
     * @dev Returns the amount of token staked by the user.
     */
    function userStaked(address _account) external view returns (uint256);

    /**
     * @dev Returns the amount of AC token that the user can claim.
     * @param _account Address of the account to check claimable reward.
     */
    function claimable(address _account) external view returns (uint256);

    /**
     * @dev Claims reward for the user. It transfers the claimable reward to the user and updates user's liquidity limit.
     * Note: We allow anyone to claim other rewards on behalf of others, but not for the AC reward. This is because claiming AC
     * reward also updates the user's liquidity limit. Therefore, only authorized claimer can do that on behalf of user.
     * @param _account Address of the user to claim.
     * @param _receiver Address that receives the claimed reward
     * @param _claimRewards Whether to claim other rewards as well.
     */
    function claim(address _account, address _receiver, bool _claimRewards) external;

    /**
     * @dev Checks whether an account can be kicked.
     * An account is kickable if the account has another voting event since last checkpoint,
     * or the lock of the account expires.
     */
    function kickable(address _account) external view returns (bool);

    /**
     * @dev Kicks an account for abusing their boost. Only kick if the user
     * has another voting event, or their lock expires.
     */
    function kick(address _account) external;
}