// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

/// @title IERC1155Controller
/// @notice A contract used by the SeriesController to perform ERC1155 functions (inherited
/// from the OpenZeppelin ERC1155PresetMinterPauserUpgradeable contract)
/// @dev All ERC1155 tokens minted by this contract are stored on SeriesVault
/// @dev This contract exists solely to decrease the size of the deployed SeriesController
/// bytecode so it can be lower than the Spurious Dragon bytecode size limit
interface IERC1155Controller {
    function optionTokenTotalSupply(uint256 id) external view returns (uint256);

    function optionTokenTotalSupplyBatch(uint256[] memory ids)
        external
        view
        returns (uint256[] memory);

    function mint(
        address to,
        uint256 id,
        uint256 amount,
        bytes memory data
    ) external;

    function mintBatch(
        address to,
        uint256[] memory ids,
        uint256[] memory amounts,
        bytes memory data
    ) external;

    function burn(
        address account,
        uint256 id,
        uint256 amount
    ) external;

    function burnBatch(
        address account,
        uint256[] memory ids,
        uint256[] memory amounts
    ) external;
}
