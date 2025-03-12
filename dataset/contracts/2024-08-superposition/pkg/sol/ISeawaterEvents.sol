// SPDX-Identifier: MIT
pragma solidity 0.8.16;

interface ISeawaterEvents {
    // positions

    /// @notice emitted when a new position is minted
    /// @param id the position id
    /// @param owner the owner of the position
    /// @param pool the pool the position is associated with
    /// @param lower the lower tick of the position's concentrated liquidity range
    /// @param upper the upper tick of the position's concentrated liquidity range
    event MintPosition(
        uint256 indexed id,
        address indexed owner,
        address indexed pool,
        int32 lower,
        int32 upper
    );

    /// @notice emitted when a position is burned
    /// @param id the id of the position being burned
    /// @param owner the user the owned the position
    event BurnPosition(
        uint256 indexed id,
        address indexed owner
    );

    /// @notice emitted when a position changes owners
    /// @param from the original owner of the position
    /// @param to the new owner of the position
    /// @param id the id of the position being transferred
    event TransferPosition(
        address indexed from,
        address indexed to,
        uint256 indexed id
    );

    /// @notice emitted when the liquidity in a position is changed.
    /// @param token0, negative if given to the user. Positive if sent to the contract.
    /// @param token1 that was taken or given to the contract.
    event UpdatePositionLiquidity(
        uint256 indexed id,
        int256 token0,
        int256 token1
    );

    /// @notice emitted when a liquidity provider collects the fees associated with a position
    /// @param id the id of the position whose liquidity is being collected
    /// @param pool the address of the pool the position is associated with
    /// @param to the recipient of the fees
    /// @param amount0 the amount of token0 being collected
    /// @param amount1 the amount of token1 being collected
    event CollectFees(
        uint256 indexed id,
        address indexed pool,
        address indexed to,
        uint128 amount0,
        uint128 amount1
    );

    // admin

    /// @notice emitted when a new pool is created
    /// @param token the token0 the pool is associated with (where token1 is a fluid token)
    /// @param fee the fee being used for this pool
    /// @param decimals the decimals for the token
    /// @param tickSpacing the tick spacing for the pool
    event NewPool(
        address indexed token,
        uint32 indexed fee,
        uint8 decimals,
        uint8 tickSpacing
    );

    /// @notice emitted when a protocol admin collects protocol fees
    /// @param pool the pool for which protocol fees are being collected
    /// @param to the account the fees are being sent to
    /// @param amount0 the amount of token0 being collected
    /// @param amount1 the amount of token1 being collected
    event CollectProtocolFees(
        address indexed pool,
        address indexed to,
        uint128 amount0,
        uint128 amount1
    );

    // amm

    /// @notice emitted when a user swaps a nonfluid token for a nonfluid token (2-step swap)
    /// @param user the user performing the swap
    /// @param from the input token
    /// @param to the output token
    /// @param amountIn the amount of `from` the user is paying
    /// @param amountOut the amount of `to` the user is receiving
    /// @param fluidVolume the volume of the internal transfer
    /// @param finalTick0 the tick that the first token's pool ended on
    /// @param finalTick1 the tick that the second token's pool ended on
    event Swap2(
        address indexed user,
        address indexed from,
        address indexed to,
        uint256 amountIn,
        uint256 amountOut,
        uint256 fluidVolume,
        int32 finalTick0,
        int32 finalTick1
    );

    /// @notice emitted when a user swaps a token for the pool's fluid token, or vice-versa
    /// @param user the user performing the swap
    /// @param pool the token being swapped for the fluid token
    /// @param zeroForOne true if the user is swapping token->fluid, false otherwise
    /// @param amount0 the amount of the nonfluid token being transferred
    /// @param amount1 the amount of the fluid token being transferred
    /// @param finalTick the tick the pool ended on
    event Swap1(
        address indexed user,
        address indexed pool,
        bool zeroForOne,
        uint256 amount0,
        uint256 amount1,
        int32 finalTick
    );
}
