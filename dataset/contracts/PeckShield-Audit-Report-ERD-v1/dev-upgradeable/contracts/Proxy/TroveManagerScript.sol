// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../Interfaces/ITroveManager.sol";

contract TroveManagerScript {
    bytes32 public constant NAME = "TroveManagerScript";

    ITroveManager immutable troveManager;

    constructor(ITroveManager _troveManager) {
        troveManager = _troveManager;
    }

    function redeemCollateral(
        uint256 _EUSDAmount,
        address _firstRedemptionHint,
        address _upperPartialRedemptionHint,
        address _lowerPartialRedemptionHint,
        uint256 _partialRedemptionHintNICR,
        uint256 _maxIterations,
        uint256 _maxFeePercentage
    ) external {
        troveManager.redeemCollateral(
            _EUSDAmount,
            _firstRedemptionHint,
            _upperPartialRedemptionHint,
            _lowerPartialRedemptionHint,
            _partialRedemptionHintNICR,
            _maxIterations,
            _maxFeePercentage
        );
    }
}
