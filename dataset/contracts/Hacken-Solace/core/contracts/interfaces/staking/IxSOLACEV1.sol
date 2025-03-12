// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";


/**
 * @title xSolace V1 Token (xSOLACE)
 * @author solace.fi
 * @notice V1 of the [**SOLACE**](./../../SOLACE) staking contract.
 *
 * Users can stake their [**SOLACE**](./../../SOLACE) and receive **xSOLACE**. **xSOLACE** is designed to be a safe up-only contract that allows users to enter or leave at any time. The value of **xSOLACE** relative to [**SOLACE**](./../../SOLACE) will increase when [**SOLACE**](./../../SOLACE) is sent to this contract, namely from premiums from coverage polices.
 *
 * Note that xSOLACEV1 was deprecated for the [new staking system](./../../staking/xSOLACE).
 */
interface IxSOLACEV1 is IERC20, IERC20Permit {

    /***************************************
    EVENTS
    ***************************************/

    /// @notice Emitted when [**SOLACE**](./../../SOLACE) is staked.
    event Staked(address user, uint256 amountSolace, uint256 amountXSolace);
    /// @notice Emitted when [**SOLACE**](./../../SOLACE) is unstaked.
    event Unstaked(address user, uint256 amountSolace, uint256 amountXSolace);

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    /// @notice Address of the [**SOLACE**](./../../SOLACE) contract.
    function solace() external view returns (address solace_);

    /**
     * @notice Determines the current value in **xSOLACE** for an amount of [**SOLACE**](./../../SOLACE).
     * @param amountSolace The amount of [**SOLACE**](./../../SOLACE).
     * @return amountXSolace The amount of **xSOLACE**.
     */
    function solaceToXSolace(uint256 amountSolace) external view returns (uint256 amountXSolace);

    /**
     * @notice Determines the current value in [**SOLACE**](./../../SOLACE) for an amount of **xSOLACE**.
     * @param amountXSolace The amount of **xSOLACE**.
     * @return amountSolace The amount of [**SOLACE**](./../../SOLACE).
     */
    function xSolaceToSolace(uint256 amountXSolace) external view returns (uint256 amountSolace);

    /***************************************
    MUTATOR FUNCTIONS
    ***************************************/

    /**
     * @notice Allows a user to stake [**SOLACE**](./../../SOLACE).
     * Shares of the pool (xSOLACE) are minted to msg.sender.
     * @param amountSolace Amount of [**SOLACE**](./../../SOLACE) to deposit.
     * @return amountXSolace The amount of **xSOLACE** minted.
     */
    function stake(uint256 amountSolace) external returns (uint256 amountXSolace);

    /**
     * @notice Allows a user to stake [**SOLACE**](./../../SOLACE).
     * Shares of the pool (xSOLACE) are minted to msg.sender.
     * @param depositor The depositing user.
     * @param amountSolace The deposit amount.
     * @param deadline Time the transaction must go through before.
     * @param v secp256k1 signature
     * @param r secp256k1 signature
     * @param s secp256k1 signature
     * @return amountXSolace The amount of **xSOLACE** minted.
     */
    function stakeSigned(address depositor, uint256 amountSolace, uint256 deadline, uint8 v, bytes32 r, bytes32 s) external returns (uint256 amountXSolace);

    /**
     * @notice Allows a user to unstake **xSOLACE**.
     * Burns **xSOLACE** tokens and transfers [**SOLACE**](./../../SOLACE) to msg.sender.
     * @param amountXSolace Amount of **xSOLACE**.
     * @return amountSolace Amount of [**SOLACE**](./../../SOLACE) returned.
     */
    function unstake(uint256 amountXSolace) external returns (uint256 amountSolace);

    /**
     * @notice Burns **xSOLACE** from msg.sender.
     * @param amount Amount to burn.
     */
    function burn(uint256 amount) external;
}
