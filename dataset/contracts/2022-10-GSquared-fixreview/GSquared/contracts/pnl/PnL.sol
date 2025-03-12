// SPDX-License-Identifier: AGPLv3
pragma solidity 0.8.10;

import {IPnL} from "../interfaces/IPnL.sol";
import {PnLErrors} from "../common/PnLErrors.sol";

//  ________  ________  ________
//  |\   ____\|\   __  \|\   __  \
//  \ \  \___|\ \  \|\  \ \  \|\  \
//   \ \  \  __\ \   _  _\ \  \\\  \
//    \ \  \|\  \ \  \\  \\ \  \\\  \
//     \ \_______\ \__\\ _\\ \_______\
//      \|_______|\|__|\|__|\|_______|

// gro protocol: https://github.com/groLabs/GSquared

/// @title PnL
/// @notice PnL - Separate contract for defining profit and loss calculation for the GTranche
contract PnL is IPnL {
    int32 internal constant NO_OF_TRANCHES = 2;
    int32 internal constant DEFAULT_DECIMALS = 10_000;
    address internal immutable tranche;
    address public owner;
    int256 public juniorLoss;

    event LogNewJuniorLoss(int256 juniorLoss);
    event LogOwnershipTransferred(address oldOwner, address newOwner);

    constructor(address _tranche) {
        tranche = _tranche;
        owner = msg.sender;
    }

    /// @notice Change owner of the strategy
    /// @param _owner new strategy owner
    function setOwner(address _owner) external {
        if (msg.sender != owner) revert PnLErrors.NotOwner();
        address previous_owner = msg.sender;
        owner = _owner;

        emit LogOwnershipTransferred(previous_owner, _owner);
    }

    /// @notice Remove debt recovery for junior tranche
    /// @dev Warning, this means that yields wont be used
    ///     to recover junior tranche losses, but yield sharing
    ///     will return to normal
    function resetJuniorDebt() external {
        if (msg.sender != owner) revert PnLErrors.NotOwner();
        juniorLoss = 0;
        emit LogNewJuniorLoss(0);
    }

    /// @notice Calculate distribution of assets changes of underlying yield tokens
    /// @param _loss flag indicating if the change is loss or gain
    /// @param _amount amount of loss to distribute
    /// @param _trancheBalances balances of current tranches in common denominator
    function distributeAssets(
        bool _loss,
        int256 _amount,
        int256[NO_OF_TRANCHES] calldata _trancheBalances
    ) external override returns (int256[NO_OF_TRANCHES] memory amounts) {
        if (msg.sender != tranche) revert PnLErrors.NotTranche();
        if (_loss) {
            amounts = distributeLoss(_amount, _trancheBalances);
            juniorLoss += amounts[0];
            emit LogNewJuniorLoss(amounts[0]);
        } else {
            amounts = distributeProfit(_amount, _trancheBalances);
            int256 _juniorLoss = juniorLoss;
            if (amounts[1] > 0 || amounts[0] >= _juniorLoss) {
                emit LogNewJuniorLoss(-1 * _juniorLoss);
                juniorLoss = 0;
            } else {
                juniorLoss -= amounts[0];
                emit LogNewJuniorLoss(-1 * amounts[0]);
            }
        }
        int256 _utilisation = (_trancheBalances[1] * DEFAULT_DECIMALS) /
            (_trancheBalances[0] + 1);
    }

    /// @notice Calculate distribution of negative changes of underlying yield tokens
    /// @param _amount amount of loss to distribute
    /// @param _trancheBalances balances of current tranches in common denominator
    function distributeLoss(
        int256 _amount,
        int256[NO_OF_TRANCHES] calldata _trancheBalances
    ) public view override returns (int256[NO_OF_TRANCHES] memory loss) {
        if (_amount > _trancheBalances[0]) {
            loss[1] = _amount - _trancheBalances[0];
            loss[0] = _trancheBalances[0];
        } else {
            loss[0] = _amount;
        }
    }

    /// @notice Calculate distribution of positive changes of underlying yield tokens
    /// @param _amount amount of profit to distribute
    /// @param _trancheBalances balances of current tranches in common denominator
    function distributeProfit(
        int256 _amount,
        int256[NO_OF_TRANCHES] calldata _trancheBalances
    ) public view override returns (int256[NO_OF_TRANCHES] memory profit) {
        int256 _juniorLoss = juniorLoss;
        int256 _utilisation = (_trancheBalances[1] * DEFAULT_DECIMALS) /
            (_trancheBalances[0] + 1);
        if (_amount > _juniorLoss && _utilisation < DEFAULT_DECIMALS) {
            _amount = _amount - _juniorLoss;
            // Can potentially break here if _amount ~ _juniorLoss, but should clear up
            //  on its own
            int256 seniorProfit = (_amount * _utilisation) /
                (DEFAULT_DECIMALS + _utilisation);
            int256 juniorProfit = _juniorLoss + _amount - seniorProfit;

            if (_utilisation < 8000)
                _utilisation = (_utilisation * 3) / 8 + 3000;
            else _utilisation = (_utilisation - 8000) * 2 + 6000;

            int256 profitFromSeniorTranche = (seniorProfit * _utilisation) /
                10000;
            profit[0] = juniorProfit + profitFromSeniorTranche;
            profit[1] = seniorProfit - profitFromSeniorTranche;
        } else {
            profit[0] = _amount;
        }
    }
}
