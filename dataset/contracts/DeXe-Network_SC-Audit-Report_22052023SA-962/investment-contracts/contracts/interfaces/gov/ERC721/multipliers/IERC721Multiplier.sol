// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "./IAbstractERC721Multiplier.sol";

interface IERC721Multiplier is IAbstractERC721Multiplier {
    /// @notice This function is used to change the basic rewards multiplier and the time for which the current nft will be locked
    /// @param tokenId the id of the nft to be changed
    /// @param multiplier the basic rewards multiplier
    /// @param duration the time for which an nft can be locked
    function changeToken(uint256 tokenId, uint256 multiplier, uint64 duration) external;

    /// @notice This function is used to get the current basic rewards multiplier and the time for which the current nft will be locked
    /// @param whose the address of the user to be checked
    /// @return multiplier the basic rewards multiplier
    /// @return timeLeft seconds remaining before the current locked nft expires
    function getCurrentMultiplier(
        address whose
    ) external view returns (uint256 multiplier, uint256 timeLeft);
}
