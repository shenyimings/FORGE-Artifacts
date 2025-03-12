// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.8.16;

// contracts
import {BaseERC20} from "./BaseERC20.sol";
import {IncreAccessControl} from "../utils/IncreAccessControl.sol";
import {Pausable} from "../../lib/openzeppelin-contracts/contracts/security/Pausable.sol";

// interfaces
import {IUA} from "../interfaces/IUA.sol";
import {IERC20Metadata} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/extensions/IERC20Metadata.sol";

// libraries
import {SafeERC20} from "../../lib/openzeppelin-contracts/contracts/token/ERC20/utils/SafeERC20.sol";
import {LibMath} from "../lib/LibMath.sol";
import {LibReserve} from "../lib/LibReserve.sol";

/// @notice Unit of Account (UA) is a USDC-backed token used as the unit of account accross Increment
contract UA is IUA, BaseERC20, Pausable, IncreAccessControl {
    using SafeERC20 for IERC20Metadata;
    using LibMath for int256;
    using LibMath for uint256;

    // USDC
    IERC20Metadata public override initialReserveToken;

    ReserveToken[] internal reserveTokens;
    /// @notice Map whitelisted reserve tokens to their reserveTokens indices
    mapping(IERC20Metadata => uint256) internal tokenToReserveIdx;

    constructor(IERC20Metadata _initialReserveToken, uint256 _initialTokenMaxMintCap)
        BaseERC20("Increment Unit of Account", "UA")
    {
        addReserveToken(_initialReserveToken, _initialTokenMaxMintCap);
        initialReserveToken = _initialReserveToken;
    }

    /* ************************* */
    /*   Reserve operations      */
    /* ************************* */

    /// @notice Mint UA with a whitelisted token
    /// @param token Address of the reserve token to mint UA with
    /// @param amount Amount of reserve token. Might not be 18 decimals
    function mintWithReserve(IERC20Metadata token, uint256 amount) external override whenNotPaused {
        uint256 tokenIdx = tokenToReserveIdx[token];
        if ((tokenIdx == 0) && (address(token) != address(initialReserveToken))) revert UA_UnsupportedReserveToken();
        ReserveToken memory reserveToken = reserveTokens[tokenIdx];

        // Check that the cap of the reserve token isn't reached
        uint256 wadAmount = LibReserve.tokenToWad(reserveToken.asset.decimals(), amount);
        if (reserveToken.currentReserves + wadAmount > reserveToken.mintCap) revert UA_ExcessiveTokenMintCapReached();

        _mint(msg.sender, wadAmount);
        reserveTokens[tokenIdx].currentReserves += wadAmount;

        reserveToken.asset.safeTransferFrom(msg.sender, address(this), amount);
    }

    /// @notice Burn UA in exchange of a whitelisted token
    /// @param token Address of whitelisted reserve token to withdraw in
    /// @param amount UA amount. 18 decimals
    function withdraw(IERC20Metadata token, uint256 amount) external override whenNotPaused {
        uint256 tokenIdx = tokenToReserveIdx[token];
        if ((tokenIdx == 0) && (address(token) != address(initialReserveToken))) revert UA_UnsupportedReserveToken();

        _burn(msg.sender, amount);
        reserveTokens[tokenIdx].currentReserves -= amount;

        uint256 tokenAmount = LibReserve.wadToToken(token.decimals(), amount);
        token.safeTransfer(msg.sender, tokenAmount);
    }

    /* ****************** */
    /*     Governance     */
    /* ****************** */

    function pause() external override onlyRole(EMERGENCY_ADMIN) {
        _pause();
    }

    function unpause() external override onlyRole(EMERGENCY_ADMIN) {
        _unpause();
    }

    function addReserveToken(IERC20Metadata newReserveToken, uint256 tokenMintCap)
        public
        override
        onlyRole(GOVERNANCE)
    {
        if (address(newReserveToken) == address(0)) revert UA_ReserveTokenZeroAddress();

        for (uint256 i = 0; i < reserveTokens.length; i++) {
            if (reserveTokens[i].asset == newReserveToken) revert UA_ReserveTokenAlreadyAssigned();
        }

        reserveTokens.push(ReserveToken({asset: newReserveToken, currentReserves: 0, mintCap: tokenMintCap}));
        tokenToReserveIdx[newReserveToken] = reserveTokens.length - 1;

        emit ReserveTokenAdded(newReserveToken, reserveTokens.length);
    }

    function changeReserveTokenMaxMintCap(IERC20Metadata token, uint256 newMintCap)
        external
        override
        onlyRole(GOVERNANCE)
    {
        uint256 tokenIdx = tokenToReserveIdx[token];
        if ((tokenIdx == 0) && (address(token) != address(initialReserveToken))) revert UA_UnsupportedReserveToken();

        reserveTokens[tokenIdx].mintCap = newMintCap;
        emit ReserveTokenMaxMintCapUpdated(token, newMintCap);
    }

    /* *********** */
    /*   Viewer    */
    /* *********** */

    /// @notice Return the number of reserve tokens
    /// @return Number of reserve tokens
    function getNumReserveTokens() external view override returns (uint256) {
        return reserveTokens.length;
    }

    /// @notice Get details of a reserve token
    /// @param tokenIdx Index of the reserve token to get details from
    function getReserveToken(uint256 tokenIdx) external view override returns (ReserveToken memory) {
        if (tokenIdx > reserveTokens.length - 1) revert UA_UnsupportedReserveToken();

        return reserveTokens[tokenIdx];
    }
}
