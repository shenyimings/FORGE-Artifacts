// SPDX-License-Identifier: MIT
pragma solidity 0.8.13;

interface IPool {
    /**
     * Calculates amount of base token (LD in Stargate naming; token which was deposited) from user Lp tokens
     */
    function amountLPtoLD(uint256 _amountLP) external view returns (uint256);

    /**
     * total tokens deposited to pool
     */
    function totalLiquidity() external view returns (uint256);

    /**
     * total LP tokens issued
     */
    function totalSupply() external view returns (uint256);

    /**
     * return amount that can be instantly (synchronously) withdrawn from pool 
     */    
    function deltaCredit() external view returns(uint256);
}
