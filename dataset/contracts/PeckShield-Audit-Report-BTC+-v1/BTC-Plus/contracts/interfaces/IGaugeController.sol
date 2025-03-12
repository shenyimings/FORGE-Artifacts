// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;

/**
 * @title Interface for gauge controller.
 */
interface IGaugeController {

    /**
     * @dev Returns the reward token address.
     */
    function reward() external view returns(address);

    /**
     * @dev Returns the governance address.
     */
    function governance() external view returns (address);

    /**
     * @dev Returns the treasury address.
     */
    function treasury() external view returns (address);

    /**
     * @dev Returns the current AC emission rate for the gauge.
     * @param _gauge The liquidity gauge to check AC emission rate.
     */
    function gaugeRates(address _gauge) external view returns (uint256);

    /**
     * @dev Returns whether the account is a claimer which can claim rewards on behalf
     * of the user. Since user's liquidity limit is updated each time a user claims, we
     * don't want to allow anyone to claim for others.
     */
    function claimers(address _account) external view returns (bool);

    /**
     * @dev Returns the total amount of AC claimed by the user in the liquidity pool specified.
     * @param _gauge Liquidity gauge which generates the AC reward.
     * @param _account Address of the user to check.
     */
    function claimed(address _gauge, address _account) external view returns (uint256);

    /**
     * @dev Returns the last time the user claims from any gauge.
     * @param _account Address of the user to claim.
     */
    function lastClaim(address _account) external view returns (uint256);

    /**
     * @dev Claims rewards for a user. Only the supported gauge can call this function.
     * @param _account Address of the user to claim reward.
     * @param _receiver Address that receives the claimed reward
     * @param _amount Amount of AC to claim
     */
    function claim(address _account, address _receiver, uint256 _amount) external;

    /**
     * @dev Donate the gauge fee. Only liqudity gauge can call this function.
     * @param _token Address of the donated token.
     */
    function donate(address _token) external;
}