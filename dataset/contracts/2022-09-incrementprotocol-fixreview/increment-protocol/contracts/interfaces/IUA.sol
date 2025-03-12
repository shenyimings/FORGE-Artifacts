// SPDX-License-Identifier: AGPL-3.0
pragma solidity ^0.8.16;

// interfaces
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

interface IUA is IERC20Metadata {
    struct ReserveToken {
        IERC20Metadata asset;
        uint256 currentReserves; // 18 decimals
        uint256 mintCap; // 18 decimals
    }

    /* ****************** */
    /*     Errors         */
    /* ****************** */

    /// @notice Emitted when the proposed reserve token address is equal to the zero address
    error UA_ReserveTokenZeroAddress();

    /// @notice Emitted when the proposed reserve token is already registered
    error UA_ReserveTokenAlreadyAssigned();

    /// @notice Emitted when the UA amount to mint with the token exceed the max cap of this token
    error UA_ExcessiveTokenMintCapReached();

    /// @notice Emitted when the token provided isn't supported by UA as a reserve token
    error UA_UnsupportedReserveToken();

    /* ****************** */
    /*     Events         */
    /* ****************** */

    /// @notice Emitted when new reserve token is added
    /// @param newToken New reserve token
    /// @param numReserveTokens Number of reserve tokens
    event ReserveTokenAdded(IERC20Metadata indexed newToken, uint256 numReserveTokens);

    /// @notice Emitted when the max mint cap of a reserve token is updated
    /// @param token Token to update
    /// @param newMintCap New max mint cap
    event ReserveTokenMaxMintCapUpdated(IERC20Metadata indexed token, uint256 newMintCap);

    /* ******************* */
    /*  Reserve operations */
    /* ******************* */

    function mintWithReserve(IERC20Metadata token, uint256 amount) external;

    function withdraw(IERC20Metadata token, uint256 amount) external;

    /* ****************** */
    /*     Governance     */
    /* ****************** */

    function pause() external;

    function unpause() external;

    function addReserveToken(IERC20Metadata newReserveToken, uint256 tokenMintCap) external;

    function changeReserveTokenMaxMintCap(IERC20Metadata token, uint256 newMintCap) external;

    /* *********** */
    /*   Viewer    */
    /* *********** */

    function initialReserveToken() external view returns (IERC20Metadata);

    function getNumReserveTokens() external view returns (uint256);

    function getReserveToken(uint256 idx) external view returns (ReserveToken memory);
}
