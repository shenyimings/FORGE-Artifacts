// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

/// @title Poolhelper
/// @author Vector Team
/// @notice This contract is the main contract that user will intreact with in order to stake stable in Vector protocol
interface IVectorPoolHelperJoe {
    function stakingToken() external view returns (address);

    function totalSupply() external view returns (uint256);

    function rewardPerToken(address token) external view returns (uint256);

    /// @notice get the total amount of shares of a user
    /// @param _address the user
    /// @return the amount of shares
    function balanceOf(address _address) external view returns (uint256);

    /// @notice harvest pending Joe and get the caller fee
    function harvest() external;

    /// @notice get the total amount of rewards for a given token for a user
    /// @param token the address of the token to get the number of rewards for
    /// @return vtxAmount the amount of VTX ready for harvest
    /// @return tokenAmount the amount of token inputted
    function earned(address token)
        external
        view
        returns (uint256 vtxAmount, uint256 tokenAmount);

    function deposit(uint256 amount) external;

    function addLiquidityAndDeposit(
        uint256 amountA,
        uint256 amountB,
        uint256 amountAMin,
        uint256 amountBMin,
        bool isAvax
    )
        external
        payable
        returns (
            uint256 amountAConverted,
            uint256 amountBConverted,
            uint256 liquidity
        );

    /// @notice stake the receipt token in the masterchief of VTX on behalf of the caller
    function stake(uint256 _amount) external;

    /// @notice withdraw stables from mainStakingJoe, auto unstake from masterchief of VTX
    /// @dev performs a harvest of Joe before withdrawing
    /// @param amount the amount of LP tokens to withdraw
    function withdraw(uint256 amount) external;

    /// @notice withdraw stables from mainStakingJoe, auto unstake from masterchief of VTX
    /// @dev performs a harvest of Joe before withdrawing
    /// @param amount the amount of stables to deposit
    /// @param amountAMin the minimum amount of token A to get back
    /// @param amountBMin the minimum amount of token B to get back
    /// @param isAvax is the token actually native ether ?
    function withdrawAndRemoveLiquidity(
        uint256 amount,
        uint256 amountAMin,
        uint256 amountBMin,
        bool isAvax
    ) external;

    /// @notice Harvest VTX and Joe rewards
    function getReward() external;
}
