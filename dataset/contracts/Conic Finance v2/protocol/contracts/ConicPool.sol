// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./BaseConicPool.sol";

contract ConicPool is BaseConicPool {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ScaledMath for uint256;

    uint256 internal constant _DEPEG_UNDERLYING_MULTIPLIER = 2;

    constructor(
        address _underlying,
        IRewardManager _rewardManager,
        address _controller,
        string memory _lpTokenName,
        string memory _symbol,
        address _cvx,
        address _crv
    ) BaseConicPool(_underlying, _rewardManager, _controller, _lpTokenName, _symbol, _cvx, _crv) {}

    function _updatePriceCache() internal override {
        uint256 length_ = _pools.length();
        IOracle priceOracle_ = controller.priceOracle();
        for (uint256 i; i < length_; i++) {
            address pool = _pools.at(i);
            address lpToken_ = controller.poolAdapterFor(pool).lpToken(pool);
            _cachedPrices[lpToken_] = priceOracle_.getUSDPrice(lpToken_);
        }
        address underlying_ = address(underlying);
        _cachedPrices[underlying_] = priceOracle_.getUSDPrice(underlying_);
    }

    function _isDepegged(address asset_) internal view override returns (bool) {
        uint256 depegThreshold_ = depegThreshold;
        if (asset_ == address(underlying)) depegThreshold_ *= _DEPEG_UNDERLYING_MULTIPLIER; // Threshold is higher for underlying
        uint256 cachedPrice_ = _cachedPrices[asset_];
        uint256 currentPrice_ = controller.priceOracle().getUSDPrice(asset_);
        uint256 priceDiff_ = cachedPrice_.absSub(currentPrice_);
        uint256 priceDiffPercent_ = priceDiff_.divDown(cachedPrice_);
        return priceDiffPercent_ > depegThreshold_;
    }
}
