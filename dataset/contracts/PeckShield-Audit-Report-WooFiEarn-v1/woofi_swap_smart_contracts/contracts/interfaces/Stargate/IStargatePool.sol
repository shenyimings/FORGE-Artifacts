// SPDX-License-Identifier: MIT
pragma solidity =0.6.12;

interface IStargatePool {
    /**
     * @dev shared id between chains to represent same pool.
     */
    function poolId() external view returns (uint256);

    /**
     * @dev the shared decimals (lowest common decimals between chains);
     *   e.g. typically, decimal = 6
     */
    function sharedDecimals() external view returns (uint256);

    /**
     * @dev the decimals for the underlying asset token (e.g. busd, usdt, usdt.e, usdc, etc)
     */
    function localDecimals() external view returns (uint256);

    /**
     * @dev the token for the pool.
     */
    function token() external view returns (address);

    /**
     * @dev the router for the pool.
     */
    function router() external view returns (address);

    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev the total amount of tokens added on this side of the chain (fees + deposits - withdrawals)
     */
    function totalLiquidity() external view returns (uint256);

    /**
     * @dev convertRate = 10 ^ (localDecimals - sharedDecimals)
     */
    function convertRate() external view returns (uint256);

    /**
     * @dev total weight for pool percentages
     */
    function totalWeight() external view returns (uint256);

    /**
     * @dev credits accumulated from txn
     */
    function deltaCredit() external view returns (uint256);
}
