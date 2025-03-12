// SPDX-License-Identifier: MIT
pragma solidity 0.8.11;

interface IERCMintBurn {
    /// @dev IERC20 burnFrom
    function burnFrom(address, uint256) external;

    /// @dev ERC20 & ERC721 burn
    function burn(uint256) external;

    /// @dev ERC1155 burn
    function burn(
        address,
        uint256,
        uint256
    ) external;

    /// @dev ERC1155 burnBatch
    function burnBatch(
        address,
        uint256[] calldata,
        uint256[] calldata
    ) external;

    /// @dev ERC20 Mint
    function mint(address, uint256) external;

    /// @dev ERC721 Mint
    function mint(
        address,
        uint256,
        string calldata
    ) external;

    /// @dev ERC1155 Mint
    function mint(
        address,
        uint256,
        uint256,
        bytes calldata
    ) external;

    /// @dev ERC1155 mintBatch
    function mintBatch(
        address,
        uint256[] calldata,
        uint256[] calldata,
        bytes calldata
    ) external;
}
