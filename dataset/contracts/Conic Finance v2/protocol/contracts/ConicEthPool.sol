// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "./BaseConicPool.sol";

contract ConicEthPool is BaseConicPool {
    using EnumerableSet for EnumerableSet.AddressSet;
    using ScaledMath for uint256;

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
        uint256 ethUsdPrice_ = priceOracle_.getUSDPrice(address(0));
        for (uint256 i; i < length_; i++) {
            address pool = _pools.at(i);
            address lpToken_ = controller.poolAdapterFor(pool).lpToken(pool);
            uint256 priceInUsd_ = priceOracle_.getUSDPrice(lpToken_);
            uint256 priceInEth_ = priceInUsd_.divDown(ethUsdPrice_);
            _cachedPrices[lpToken_] = priceInEth_;
        }
    }

    function _isDepegged(address asset_) internal view override returns (bool) {
        // ETH has no sense of peg per se, so always return false for it
        if (asset_ == address(underlying)) return false;

        uint256 cachedPrice_ = _cachedPrices[asset_];
        IOracle priceOracle_ = controller.priceOracle();
        uint256 ethUsdPrice_ = priceOracle_.getUSDPrice(address(0));
        uint256 currentPriceUsd_ = priceOracle_.getUSDPrice(asset_);
        uint256 currentPrice_ = currentPriceUsd_.divDown(ethUsdPrice_);
        uint256 priceDiff_ = cachedPrice_.absSub(currentPrice_);
        uint256 priceDiffPercent_ = priceDiff_.divDown(cachedPrice_);
        return priceDiffPercent_ > depegThreshold;
    }

    function _sanityChecks() internal override {
        for (uint256 i; i < _pools.length(); i++) {
            address pool_ = _pools.at(i);
            controller.poolAdapterFor(pool_).executeSanityCheck(pool_);
        }
    }
}
