// SPDX-License-Identifier: GPL-3.0-only

pragma solidity 0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

/// @title ISeriesVault
/// @author The Siren Devs
/// @notice Interface to interact with a SeriesVault
/// @dev The SeriesVault can store multiple SeriesController's tokens
/// @dev Never send ERC20 tokens directly to this contract with ERC20.safeTransfer*.
/// Always use the SeriesController.transfer*In/transfer*Out functions
/// @dev EIP-1155 functions are OK to use as is, because no 2 Series trade the same wToken,
/// whereas multiple Series trade the same ERC20 (see the warning above)
/// @dev The SeriesController should be the only contract interacting with the SeriesVault
interface ISeriesVault {
    ///////////////////// MUTATING FUNCTIONS /////////////////////

    /// @notice Allow the SeriesController to transfer MAX_UINT of the given ERC20 token from the SeriesVault
    /// @dev Can only be called by the seriesController
    /// @param erc20Token An ERC20-compatible token
    function setERC20ApprovalForController(address erc20Token) external;

    /// @notice Allow the SeriesController to transfer any number of ERC1155 tokens from the SeriesVault
    /// @dev Can only be called by the seriesController
    /// @dev The ERC1155 tokens will be minted and burned by the ERC1155Controller contract
    function setERC1155ApprovalForController(address erc1155Contract) external;
}
