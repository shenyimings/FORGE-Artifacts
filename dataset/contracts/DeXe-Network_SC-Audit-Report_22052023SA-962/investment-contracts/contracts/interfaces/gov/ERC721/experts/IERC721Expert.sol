// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

/**
 * The ERC721 token that implements experts functionality, follows EIP-5484
 */
interface IERC721Expert is IERC721Upgradeable {
    enum BurnAuth {
        IssuerOnly,
        OwnerOnly,
        Both,
        Neither
    }

    /// @notice Emitted when a soulbound token is issued.
    /// @param from The issuer
    /// @param to The receiver
    /// @param tokenId The id of the issued token
    /// @param burnAuth the BurnAuth struct
    event Issued(
        address indexed from,
        address indexed to,
        uint256 indexed tokenId,
        BurnAuth burnAuth
    );
    /// @notice Emitted when tags are added to the SBT
    /// @param tokenId the token where the tags are added
    /// @param tags the list of tags
    event TagsAdded(uint256 indexed tokenId, string[] tags);

    /// @notice The function to burn the token
    /// @param from the address to burn from (1 to 1 relation)
    function burn(address from) external;

    /// @notice The function to check of a user is an expert
    /// @param expert the user to check
    /// @return true if user is an expert
    function isExpert(address expert) external view returns (bool);

    /// @notice The function to get the SBT id of an expert
    /// @param expert the user to get the SBT id of
    /// @return SBT id of the user
    function getIdByExpert(address expert) external view returns (uint256);

    /// @notice provides burn authorization of the token id
    /// @param tokenId The identifier for a token
    /// @return the auth
    function burnAuth(uint256 tokenId) external view returns (BurnAuth);
}
