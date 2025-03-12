// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

interface IPoolBase {
    /// @notice Function is used to provide liquidity for Pool in exchange for cpTokens
    /// @dev Approval for desired amount of currency token should be given in prior
    /// @param currencyAmount Amount of currency token that user want to provide
    function provide(uint256 currencyAmount) external;

    /// @notice Function is used to redeem previously provided liquidity with interest, burning cpTokens
    /// @param tokens Amount of cpTokens to burn (MaxUint256 to burn maximal possible)
    function redeem(uint256 tokens) external;

    /// @notice Function returns current (with accrual) exchange rate of cpTokens for currency tokens
    /// @return Current exchange rate as 10-digits decimal
    function getCurrentExchangeRate() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);
}

interface IPoolMaster {
    function withdrawReward(address[] memory pools) external;
}


