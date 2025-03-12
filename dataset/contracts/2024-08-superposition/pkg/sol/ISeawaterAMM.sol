// SPDX-Identifier: MIT
pragma solidity 0.8.16;

import "./ISeawaterEvents.sol";
import "./ISeawaterExecutors.sol";

// ISeawaterAMM is the public facing interface for the SeawaterAMM
interface ISeawaterAMM is
    ISeawaterEvents,
    ISeawaterExecutorSwap,
    ISeawaterExecutorSwapPermit2,
    ISeawaterExecutorQuote,
    ISeawaterExecutorPosition,
    ISeawaterExecutorUpdatePosition,
    ISeawaterExecutorAdminExposed
    {
    /// @notice swaps _token for USDC
    /// @param _token the token to swap
    /// @param _amount input amount (token)
    /// @param _minOut the minimum output amount (usdc), reverting if the actual output is lower
    /// @return amount of usdc out
    function swapIn32502CA71(
        address _token,
        uint256 _amount,
        uint256 _minOut
    ) external returns (int256, int256);

    /// @notice swaps _token for USDC
    /// @param _token the token to swap
    /// @param _amount input amount (token)
    /// @param _minOut the minimum output amount (usdc), reverting if the actual output is lower
    /// @param _nonce the nonce for the token
    /// @param _deadline the deadline for the token
    /// @param _sig the signature for the token
    /// @param _maxAmount the max amount of the token
    /// @return amount of usdc out
    function swapInPermit2CEAAB576(
        address _token,
        uint256 _amount,
        uint256 _minOut,
        uint256 _nonce,
        uint256 _deadline,
        uint256 _maxAmount,
        bytes memory _sig
    ) external returns (int256, int256);

    /// @notice swaps USDC for _token
    /// @param _token the token to swap
    /// @param _amount input amount (usdc)
    /// @param _minOut the minimum output amount (token), reverting if the actual output is lower
    /// @return amount of token out
    function swapOut5E08A399(
        address _token,
        uint256 _amount,
        uint256 _minOut
    ) external returns (int256, int256);

    /// @notice swaps USDC for _token
    /// @param _token the token to swap
    /// @param _amount input amount (usdc)
    /// @param _minOut the minimum output amount (token), reverting if the actual output is lower
    /// @param _nonce the nonce for the token
    /// @param _deadline the deadline for the token
    /// @param _sig the signature for the token
    /// @param _maxAmount the max amount of the token
    /// @return amount of token out
    function swapOutPermit23273373B(
        address _token,
        uint256 _amount,
        uint256 _minOut,
        uint256 _nonce,
        uint256 _deadline,
        uint256 _maxAmount,
        bytes memory _sig
    ) external returns (int256, int256);

    /// @notice swaps tokenA for tokenB
    /// @param _tokenA the input token
    /// @param _tokenB the output token
    /// @param _amount input amount (tokenA)
    /// @param _minOut the minimum output amount (tokenB), reverting if the actual output is lower
    /// @return amount of token A in, amount of token B out
    function swap2ExactIn41203F1D(
        address _tokenA,
        address _tokenB,
        uint256 _amount,
        uint256 _minOut
    ) external returns (uint256, uint256);
}
