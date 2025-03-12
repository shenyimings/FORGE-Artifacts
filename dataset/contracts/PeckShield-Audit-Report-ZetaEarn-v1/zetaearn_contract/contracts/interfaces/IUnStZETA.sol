// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC721/IERC721Upgradeable.sol";

interface IUnStZETA is IERC721Upgradeable {
    /// @notice mint a new NFT.
    /// @param _to to address
    /// @return tokenId return token id.
    function mint(address _to) external returns (uint256);

    /// @notice burn NFT
    /// @param _tokenId token id.
    function burn(uint256 _tokenId) external;

    /// @notice check if address is owner or approved
    /// @param _spender check address.
    /// @param _tokenId token id.
    /// @return result return result
    function isApprovedOrOwner(address _spender, uint256 _tokenId)
        external
        view
        returns (bool);

    /// @notice set stZETA address.
    /// @param _newStZETA new stZETA address.
    function setStZETA(address _newStZETA) external;

    /// @notice list address all owned tokenid
    /// @param _owner check address.
    /// @return result return tokenid list.
    function getOwnedTokens(address _owner) external view returns (uint256[] memory);

    /// @notice toggle pause
    function togglePause() external;

    /// @notice set new version
    /// @param _newVersion new version
    function setVersion(string memory _newVersion) external;

    /// @notice get update version
    /// @return version return version
    function getUpdateVersion() external pure returns(string memory);

    /// @notice check tokenid exists
    /// @param _tokenId token id.
    /// @return result return result
    function exists(uint256 _tokenId) external view returns (bool);

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                    EVENTS                          ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @notice set new version event
    /// @param oldVersion old version.
    /// @param newVersion new version.
    event SetVersion(string oldVersion, string newVersion);

    /// @notice set new stZETA address
    /// @param oldStZETA old stZETA address.
    /// @param newStZETA new stZETA address.
    event SetStZETA(address oldStZETA, address newStZETA);

}