// SPDX-License-Identifier: MIT
pragma solidity 0.8.22;

/// @notice Interface for the extended functionalities of DividendDistribution contract
/// @author Dinari (https://github.com/dinaricrypto/sbt-contracts/blob/main/src/dividend/IDividendDistributor.sol)
interface IDividendDistributor {
    /**
     * @notice Fetches the ID for the next distribution.
     * @return The ID for the next distribution.
     */
    function nextDistributionId() external returns (uint256);
    /**
     * @notice Creates a new distribution.
     * @param token The address of the token to be distributed.
     * @param totalDistribution The total amount of tokens to be distributed.
     * @param endTime The timestamp when the distribution stops.
     * @dev Only the owner can create a new distribution.
     */
    function createDistribution(address token, uint256 totalDistribution, uint256 endTime)
        external
        returns (uint256 distributionId);
    /**
     * @notice Distributes tokens to recipient.
     * @param _distributionId The ID of the distribution.
     * @param _recipient The address of the user claiming tokens.
     * @param _amount The amount of tokens the user is claiming.
     * @dev Can only be called by the owner.
     */
    function distribute(uint256 _distributionId, address _recipient, uint256 _amount) external;
    /**
     * @notice Reclaims unclaimed tokens from an distribution.
     * @param _distributionId The ID of the distribution to reclaim tokens from.
     * @dev Can only be called by the distributor after the claim window has passed.
     */
    function reclaimDistribution(uint256 _distributionId) external;
}
