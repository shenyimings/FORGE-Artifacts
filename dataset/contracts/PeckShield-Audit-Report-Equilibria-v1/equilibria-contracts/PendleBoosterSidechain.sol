// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./PendleBoosterBaseUpg.sol";

contract PendleBoosterSidechain is PendleBoosterBaseUpg {
    using TransferHelper for address;

    function initialize() public initializer {
        __PendleBoosterBaseUpg_init();
    }

    function setParams(
        address _pendle,
        address _pendleProxy,
        address _eqbMinter,
        address _vlEqb,
        address _ePendleRewardPool,
        address _treasury
    ) external onlyOwner {
        _setParams(
            _pendle,
            _pendleProxy,
            _eqbMinter,
            _vlEqb,
            _ePendleRewardPool,
            _treasury
        );
    }

    function _sendOtherRewards(
        address _rewardToken,
        uint256 _vlEqbIncentiveAmount,
        uint256 _ePendleIncentiveAmount
    ) internal override {
        // send to vlEqb
        if (_vlEqbIncentiveAmount > 0) {
            _rewardToken.safeTransferToken(vlEqb, _vlEqbIncentiveAmount);
        }

        // send to ePendle reward contract
        if (_ePendleIncentiveAmount > 0) {
            _rewardToken.safeTransferToken(
                ePendleRewardPool,
                _ePendleIncentiveAmount
            );
        }
    }
}
