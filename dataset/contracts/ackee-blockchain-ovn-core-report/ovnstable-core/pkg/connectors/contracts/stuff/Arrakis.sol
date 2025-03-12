// SPDX-License-Identifier: agpl-3.0
pragma solidity >=0.8.0 <0.9.0;

interface IArrakisRewards {

    function claim_rewards(address to) external;

    function balanceOf(address account) external view returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);
}


interface IArrakisV1RouterStaking {

    function addLiquidityAndStake(
        address gauge,
        uint256 amount0Max,
        uint256 amount1Max,
        uint256 amount0Min,
        uint256 amount1Min,
        address receiver
    )
    external
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 mintAmount
    );


    function removeLiquidityAndUnstake(
        address gauge,
        uint256 burnAmount,
        uint256 amount0Min,
        uint256 amount1Min,
        address receiver
    )
    external
    returns (
        uint256 amount0,
        uint256 amount1,
        uint128 liquidityBurned
    );


}

interface IArrakisVault {

    /// @notice compute total underlying holdings of the G-UNI token supply
    /// includes current liquidity invested in uniswap position, current fees earned
    /// and any uninvested leftover (but does not include manager or gelato fees accrued)
    /// @return amount0Current current total underlying balance of token0
    /// @return amount1Current current total underlying balance of token1
    function getUnderlyingBalances() external view returns (uint256 amount0Current, uint256 amount1Current);

    function getUnderlyingBalancesAtPrice(uint160 sqrtRatioX96) external view returns (uint256 amount0Current, uint256 amount1Current);

    function getPositionID() external view returns (bytes32 positionID);

    function token0() external view returns (address token);

    function token1() external view returns (address token);

    function upperTick() external view returns (int24);

    function lowerTick() external view returns (int24);

    function pool() external view returns (address pool);

    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function getMintAmounts(uint256 amount0Max, uint256 amount1Max)
    external
    view
    returns (
        uint256 amount0,
        uint256 amount1,
        uint256 mintAmount
    );

}
