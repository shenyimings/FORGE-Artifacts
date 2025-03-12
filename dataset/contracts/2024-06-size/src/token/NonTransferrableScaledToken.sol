// SPDX-License-Identifier: MIT
pragma solidity 0.8.23;

import {IPool} from "@aave/interfaces/IPool.sol";
import {WadRayMath} from "@aave/protocol/libraries/math/WadRayMath.sol";
import {IERC20Metadata} from "@openzeppelin/contracts/interfaces/IERC20Metadata.sol";

import {Math} from "@src/libraries/Math.sol";
import {NonTransferrableToken} from "@src/token/NonTransferrableToken.sol";

import {Errors} from "@src/libraries/Errors.sol";

/// @title NonTransferrableScaledToken
/// @custom:security-contact security@size.credit
/// @author Size (https://size.credit/)
/// @notice An ERC-20 that is not transferrable from outside of the protocol
/// @dev The contract owner (i.e. the Size contract) can still mint, burn, and transfer tokens
///      Enables the owner to mint and burn scaled amounts. Emits the TransferUnscaled event representing the actual unscaled amount
contract NonTransferrableScaledToken is NonTransferrableToken {
    IPool private immutable variablePool;
    IERC20Metadata private immutable underlyingToken;

    event TransferUnscaled(address indexed from, address indexed to, uint256 value);

    constructor(
        IPool variablePool_,
        IERC20Metadata underlyingToken_,
        address owner_,
        string memory name_,
        string memory symbol_,
        uint8 decimals_
    ) NonTransferrableToken(owner_, name_, symbol_, decimals_) {
        if (address(variablePool_) == address(0) || address(underlyingToken_) == address(0)) {
            revert Errors.NULL_ADDRESS();
        }

        variablePool = variablePool_;
        underlyingToken = underlyingToken_;
    }

    /// @dev Reverts with NOT_SUPPORTED
    function mint(address, uint256) external view override onlyOwner {
        revert Errors.NOT_SUPPORTED();
    }

    /// @notice Mint scaled tokens to an account
    /// @param to The account to mint the tokens to
    /// @param scaledAmount The scaled amount of tokens to mint
    /// @dev Emits a TransferUnscaled event representing the actual unscaled amount
    function mintScaled(address to, uint256 scaledAmount) external onlyOwner {
        _mint(to, scaledAmount);
        emit TransferUnscaled(address(0), to, _unscale(scaledAmount));
    }

    /// @dev Reverts with NOT_SUPPORTED
    function burn(address, uint256) external view override onlyOwner {
        revert Errors.NOT_SUPPORTED();
    }

    /// @notice Burn scaled tokens from an account
    /// @param from The account to burn the tokens from
    /// @param scaledAmount The scaled amount of tokens to burn
    /// @dev Emits a TransferUnscaled event representing the actual unscaled amount
    function burnScaled(address from, uint256 scaledAmount) external onlyOwner {
        _burn(from, scaledAmount);
        emit TransferUnscaled(from, address(0), _unscale(scaledAmount));
    }

    /// @notice Transfer tokens from one account to another
    /// @param from The account to transfer the tokens from
    /// @param to The account to transfer the tokens to
    /// @param value The unscaled amount of tokens to transfer
    /// @dev Emits TransferUnscaled events representing the actual unscaled amount
    ///      Scales the amount by the current liquidity index before transferring scaled tokens
    /// @return True if the transfer was successful
    function transferFrom(address from, address to, uint256 value) public virtual override onlyOwner returns (bool) {
        uint256 scaledAmount = Math.mulDivDown(value, WadRayMath.RAY, liquidityIndex());

        _burn(from, scaledAmount);
        _mint(to, scaledAmount);

        emit TransferUnscaled(from, to, value);

        return true;
    }

    /// @notice Returns the scaled balance of an account
    /// @param account The account to get the balance of
    /// @return The scaled balance of the account
    function scaledBalanceOf(address account) public view returns (uint256) {
        return super.balanceOf(account);
    }

    /// @notice Unscales a scaled amount
    /// @param scaledAmount The scaled amount to unscale
    /// @return The unscaled amount
    /// @dev The unscaled amount is the scaled amount divided by the current liquidity index
    function _unscale(uint256 scaledAmount) internal view returns (uint256) {
        return Math.mulDivDown(scaledAmount, liquidityIndex(), WadRayMath.RAY);
    }

    /// @notice Returns the unscaled balance of an account
    /// @param account The account to get the balance of
    /// @return The unscaled balance of the account
    function balanceOf(address account) public view override returns (uint256) {
        return _unscale(scaledBalanceOf(account));
    }

    /// @notice Returns the scaled total supply of the token
    /// @return The scaled total supply of the token
    function scaledTotalSupply() public view returns (uint256) {
        return super.totalSupply();
    }

    /// @notice Returns the unscaled total supply of the token
    /// @return The unscaled total supply of the token
    function totalSupply() public view override returns (uint256) {
        return _unscale(scaledTotalSupply());
    }

    /// @notice Returns the current liquidity index of the variable pool
    /// @return The current liquidity index of the variable pool
    function liquidityIndex() public view returns (uint256) {
        return variablePool.getReserveNormalizedIncome(address(underlyingToken));
    }
}
