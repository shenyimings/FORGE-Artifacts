// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity ^0.8.0;

import { IERC20Upgradeable } from "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import { IBondIssuer } from "./IBondIssuer.sol";
import { IFeePolicy } from "./IFeePolicy.sol";
import { IBondController } from "./buttonwood/IBondController.sol";
import { ITranche } from "./buttonwood/ITranche.sol";
import { IRolloverVault } from "./IRolloverVault.sol";
import { TokenAmount, RolloverData } from "./CommonTypes.sol";

interface IPerpetualTranche is IERC20Upgradeable {
    //--------------------------------------------------------------------------
    // Events

    /// @notice Event emitted the reserve's current token balance is recorded after change.
    /// @param token Address of token.
    /// @param balance The recorded ERC-20 balance of the token held by the reserve.
    event ReserveSynced(IERC20Upgradeable token, uint256 balance);

    /// @notice Event emitted when the active deposit bond is updated.
    /// @param bond Address of the new deposit bond.
    event UpdatedDepositBond(IBondController bond);

    //--------------------------------------------------------------------------
    // Methods

    /// @notice Deposits tranche tokens into the system and mint perp tokens.
    /// @param trancheIn The address of the tranche token to be deposited.
    /// @param trancheInAmt The amount of tranche tokens deposited.
    /// @return The amount of perp tokens minted.
    function deposit(ITranche trancheIn, uint256 trancheInAmt) external returns (uint256);

    /// @notice Burn perp tokens and redeem the share of reserve assets.
    /// @param perpAmtBurnt The amount of perp tokens burnt from the caller.
    /// @return tokensOut The list of reserve tokens and amounts redeemed.
    function redeem(uint256 perpAmtBurnt) external returns (TokenAmount[] memory tokensOut);

    /// @notice Rotates newer tranches in for reserve tokens.
    /// @param trancheIn The tranche token deposited.
    /// @param tokenOut The reserve token to be redeemed.
    /// @param trancheInAmt The amount of trancheIn tokens deposited.
    /// @return r The rollover amounts in various denominations.
    function rollover(
        ITranche trancheIn,
        IERC20Upgradeable tokenOut,
        uint256 trancheInAmt
    ) external returns (RolloverData memory r);

    /// @notice External contract that stores a predefined bond config and frequency,
    ///         and issues new bonds when poked.
    /// @return The address of the bond issuer.
    function bondIssuer() external view returns (IBondIssuer);

    /// @notice Reference to the address that has the ability to pause/unpause operations.
    /// @return The address of the keeper.
    function keeper() external view returns (address);

    /// @notice The address of the underlying rebasing ERC-20 collateral token backing the tranches.
    /// @return Address of the underlying collateral token.
    function underlying() external view returns (IERC20Upgradeable);

    /// @return Address of perp's rollover vault.
    function vault() external view returns (IRolloverVault);

    /// @notice The parent bond whose tranches are currently accepted to mint perp tokens.
    /// @return Address of the deposit bond.
    function getDepositBond() external returns (IBondController);

    /// @notice The tranche token contract currently accepted to mint perp tokens.
    /// @return Address of the deposit tranche ERC-20 token.
    function getDepositTranche() external returns (ITranche);

    /// @return The tranche ratio of the current deposit tranche.
    function getDepositTrancheRatio() external returns (uint256);

    /// @notice The policy contract with the fee computation logic for the perp and vault systems.
    /// @return Address of the policy contract.
    function feePolicy() external view returns (IFeePolicy);

    /// @notice Total count of tokens held in the reserve.
    /// @return The reserve token count.
    function getReserveCount() external returns (uint256);

    /// @notice The token address from the reserve list by index.
    /// @param index The index of a token.
    /// @return The reserve token address.
    function getReserveAt(uint256 index) external returns (IERC20Upgradeable);

    /// @notice Checks if the given token is part of the reserve.
    /// @param token The address of a token to check.
    /// @return If the token is part of the reserve.
    function inReserve(IERC20Upgradeable token) external returns (bool);

    /// @notice Fetches the reserve's token balance.
    /// @param token The address of the tranche token held by the reserve.
    /// @return The ERC-20 balance of the reserve token.
    function getReserveTokenBalance(IERC20Upgradeable token) external returns (uint256);

    /// @notice Calculates the reserve's token value,
    ///         in a standard denomination as defined by the implementation.
    /// @param token The address of the tranche token held by the reserve.
    /// @return The value of the reserve token balance held by the reserve, in a standard denomination.
    function getReserveTokenValue(IERC20Upgradeable token) external returns (uint256);

    /// @notice Computes the total value of assets currently held in the reserve.
    /// @return The total value of the perp system, in a standard denomination.
    function getTVL() external returns (uint256);

    /// @notice Fetches the list of reserve tokens which are up for rollover.
    /// @return The list of reserve tokens up for rollover.
    function getReserveTokensUpForRollover() external returns (IERC20Upgradeable[] memory);

    /// @notice Computes the amount of perp tokens minted when `trancheInAmt` `trancheIn` tokens
    ///         are deposited into the system.
    /// @param trancheIn The tranche token deposited.
    /// @param trancheInAmt The amount of tranche tokens deposited.
    /// @return The amount of perp tokens to be minted.
    function computeMintAmt(ITranche trancheIn, uint256 trancheInAmt) external returns (uint256);

    /// @notice Computes the amount reserve tokens redeemed when burning given number of perp tokens.
    /// @param perpAmtBurnt The amount of perp tokens to be burnt.
    /// @return tokensOut The list of reserve tokens and amounts redeemed.
    function computeRedemptionAmts(uint256 perpAmtBurnt) external returns (TokenAmount[] memory tokensOut);

    /// @notice Computes the amount reserve tokens that are rolled out for the given number
    ///         of `trancheIn` tokens rolled in.
    /// @param trancheIn The tranche token rolled in.
    /// @param tokenOut The reserve token to be rolled out.
    /// @param trancheInAmtAvailable The amount of trancheIn tokens rolled in.
    /// @return r The rollover amounts in various denominations.
    function computeRolloverAmt(
        ITranche trancheIn,
        IERC20Upgradeable tokenOut,
        uint256 trancheInAmtAvailable
    ) external returns (RolloverData memory r);

    /// @notice Updates time dependent storage state.
    function updateState() external;

    /// @return The system's current deviation ratio.
    function deviationRatio() external returns (uint256);
}
