// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

interface IYieldSourceDHedge {
    /// @notice Deposit funds into the pool
    /// @dev https://github.com/dhedge/V2-Public/blob/ba2f06d40a87e18a150f4055def5e7a2d596c719/contracts/PoolLogic.sol#L275
    /// @param _asset Address of the token
    /// @param _amount Amount of tokens to deposit
    /// @return liquidityMinted Amount of liquidity minted
    function depositFor(address _recipient, address _asset, uint256 _amount) external returns (uint256 liquidityMinted);

    /// @notice Withdraw assets based on the fund token amount
    /// @dev https://github.com/dhedge/V2-Public/blob/ba2f06d40a87e18a150f4055def5e7a2d596c719/contracts/PoolLogic.sol#L364
    /// @param _fundTokenAmount the fund token amount
    function withdrawTo(address _recipient, uint256 _fundTokenAmount) external;

    /// @return total shares supply with 18 decimals i.e. 7454095482755680176243 => 7454.1 shares
    function totalSupply() external view returns (uint256);

    /// @return balance of shares of the account i.e. 999977130000000000 => 0.999977 shares
    function balanceOf(address account) external view returns (uint256);
}

interface IYieldSourceDHedgeSwapper {
    /// @notice withdraw underlying value of tokens in expectedWithdrawalAssetOfUser
    /// @dev Swaps the underlying pool withdrawal assets to expectedWithdrawalAssetOfUser
    /// @dev https://github.com/dhedge/V2-Public/blob/ba2f06d40a87e18a150f4055def5e7a2d596c719/contracts/EasySwapper/DhedgeEasySwapper.sol#L244
    /// @param fundTokenAmount the amount to withdraw
    /// @param withdrawalAsset must have direct pair to all pool.supportedAssets on swapRouter
    /// @param expectedAmountOut the amount of value in the withdrawalAsset expected (slippage protection)
    function withdraw(address pool, uint256 fundTokenAmount, IERC20 withdrawalAsset, uint256 expectedAmountOut) external;
}
