// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";

/**
 * This is the special NFT contract which behaves like a coupon that can be locked to receive
 * certain extra rewards proportional to the rewards in the Governance pool contract
 */
interface IAbstractERC721Multiplier is IERC721EnumerableUpgradeable {
    /// @notice This struct holds NFT Multiplier parameters
    /// @param multiplier the basic rewards multiplier
    /// @param duration the time for which an nft can be locked
    /// @param mintedAt the time nft was minter
    struct NftInfo {
        uint256 multiplier;
        uint64 duration;
        uint64 mintedAt;
    }

    /// @notice This function is used to lock an nft (enable corresponding basic rewards multiplier).
    /// Only one NFT for each address can be locked at the same time
    /// @param tokenId the id of the nft to be locked
    function lock(uint256 tokenId) external;

    /// @notice This function is used to unlock an nft (disable corresponding basic rewards multiplier)
    function unlock() external;

    /// @notice This function is used to calculate extra rewards
    /// @param whose the address of the user who is to receive extra rewards
    /// @param rewards basic rewards to be multiplied
    /// @return extra rewards
    function getExtraRewards(address whose, uint256 rewards) external view returns (uint256);

    /// @notice This function is used to check whether the passed nft id is locked
    /// @param tokenId the id of the nft
    /// @return false if nft has expired or hasn't yet been locked, otherwise true
    function isLocked(uint256 tokenId) external view returns (bool);
}
