// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/extensions/IERC721EnumerableUpgradeable.sol";

/**
 * This is the custom NFT contract with voting power
 */
interface IERC721Power is IERC721EnumerableUpgradeable {
    /// @notice This struct holds NFT Power parameters. These parameters are used to recalculate nft power
    /// @param lastUpdate the last time when the power was recalculated
    /// @param maxRawPower the maximum raw nft power limit
    /// @param currentRawPower the current raw nft power
    /// @param requiredCollateral the required collateral amount
    /// @param currentCollateral the current nft collateral
    struct NftInfo {
        uint64 lastUpdate;
        uint256 maxRawPower;
        uint256 currentRawPower;
        uint256 requiredCollateral;
        uint256 currentCollateral;
    }

    /// @notice The struct to get info about the NFT
    /// @param rawInfo the raw NFT info
    /// @param maxPower real max nft power
    /// @param minPower real min nft power
    /// @param currentPower real nft power
    struct NftInfoView {
        NftInfo rawInfo;
        uint256 maxPower;
        uint256 minPower;
        uint256 currentPower;
    }

    /// @notice Add collateral amount to certain nft
    /// @param amount Wei
    /// @param tokenId Nft number
    function addCollateral(uint256 amount, uint256 tokenId) external;

    /// @notice Remove collateral amount from certain nft
    /// @param amount Wei
    /// @param tokenId Nft number
    function removeCollateral(uint256 amount, uint256 tokenId) external;

    /// @notice Recalculate nft power (coefficient)
    /// @param tokenIds Nft numbers
    function recalculateNftPowers(uint256[] calldata tokenIds) external;

    /// @notice Get total power
    /// @return totalPower
    function totalPower() external view returns (uint256);

    /// @notice Return max possible power (coefficient) for nft
    /// @param tokenId Nft number
    /// @return max power for Nft
    function getNftMaxPower(uint256 tokenId) external view returns (uint256);

    /// @notice Return min possible power (coefficient) for nft
    /// @param tokenId Nft number
    /// @return min power for Nft
    function getNftMinPower(uint256 tokenId) external view returns (uint256);

    /// @notice The function to get current NFT power
    /// @param tokenId the Nft number
    /// @return current power of the Nft
    function getNftPower(uint256 tokenId) external view returns (uint256);

    /// @notice Return required collateral amount for nft
    /// @param tokenId Nft number
    /// @return required collateral for Nft
    function getNftRequiredCollateral(uint256 tokenId) external view returns (uint256);
}
