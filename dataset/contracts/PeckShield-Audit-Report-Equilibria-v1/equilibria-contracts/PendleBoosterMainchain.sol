// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "./PendleBoosterBaseUpg.sol";

contract PendleBoosterMainchain is PendleBoosterBaseUpg {
    using TransferHelper for address;

    address public pendleDepositor;
    address public ePendle;

    function initialize() public initializer {
        __PendleBoosterBaseUpg_init();
    }

    function setParams(
        address _pendle,
        address _pendleProxy,
        address _pendleDepositor,
        address _ePendle,
        address _eqbMinter,
        address _vlEqb,
        address _ePendleRewardPool,
        address _treasury
    ) external onlyOwner {
        require(_pendleDepositor != address(0), "invalid _pendleDepositor!");
        require(_ePendle != address(0), "invalid _ePendle!");

        _setParams(
            _pendle,
            _pendleProxy,
            _eqbMinter,
            _vlEqb,
            _ePendleRewardPool,
            _treasury
        );

        pendleDepositor = _pendleDepositor;
        ePendle = _ePendle;
    }

    function _isAllowedClaimer(
        PoolInfo memory _pool,
        address _rewardContract
    ) internal override returns (bool) {
        return
            super._isAllowedClaimer(_pool, _rewardContract) ||
            _rewardContract == ePendleRewardPool;
    }

    function _sendOtherRewards(
        address _rewardToken,
        uint256 _vlEqbIncentiveAmount,
        uint256 _ePendleIncentiveAmount
    ) internal override {
        // send to vlEqb
        if (_vlEqbIncentiveAmount > 0) {
            if (_rewardToken == pendle) {
                // send ePendle
                uint256 ePendleAmount = _convertPendleToEPendle(
                    _vlEqbIncentiveAmount
                );
                ePendle.safeTransferToken(vlEqb, ePendleAmount);
            } else {
                _rewardToken.safeTransferToken(vlEqb, _vlEqbIncentiveAmount);
            }
        }

        // send to ePendle reward contract
        _sendReward(ePendleRewardPool, _rewardToken, _ePendleIncentiveAmount);
    }

    function _convertPendleToEPendle(
        uint256 _amount
    ) internal returns (uint256) {
        _approveTokenIfNeeded(pendle, pendleDepositor, _amount);
        IPendleDepositor(pendleDepositor).deposit(_amount, false);
        return _amount;
    }
}
