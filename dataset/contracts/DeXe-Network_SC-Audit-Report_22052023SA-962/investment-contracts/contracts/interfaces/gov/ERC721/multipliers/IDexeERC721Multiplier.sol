// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAbstractERC721Multiplier.sol";

interface IDexeERC721Multiplier is IAbstractERC721Multiplier {
    /// @notice This function is used to change the basic rewards multiplier and the time for which the current nft will be locked
    /// @param tokenId the id of the nft to be changed
    /// @param multiplier the basic rewards multiplier
    /// @param duration the time for which an nft can be locked
    /// @param averageBalance the average balance of the user's tokens
    function changeToken(
        uint256 tokenId,
        uint256 multiplier,
        uint64 duration,
        uint256 averageBalance
    ) external;

    /// @notice This function is used to get the current rewards multiplier and the time for which the current nft will be locked
    /// @param whose the address of the user to be checked
    /// @param rewards basic rewards to be multiplied
    /// @return multiplier the rewards multiplier
    /// @return timeLeft seconds remaining before the current locked nft expires
    function getCurrentMultiplier(
        address whose,
        uint256 rewards
    ) external view returns (uint256 multiplier, uint256 timeLeft);
}
