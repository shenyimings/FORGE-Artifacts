// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.17;

import "@openzeppelin/contracts/access/Ownable.sol";

import "../../libraries/ScaledMath.sol";
import "../../libraries/CurvePoolUtils.sol";
import "../../libraries/CurveLPTokenPricing.sol";
import "../../interfaces/IOracle.sol";
import "../../interfaces/IController.sol";
import "../../interfaces/ICurveRegistryCache.sol";
import "../../interfaces/vendor/ICurvePoolV1.sol";
import "../../interfaces/vendor/ICurvePoolV2.sol";

contract DerivativeOracle is IOracle, Ownable {
    using ScaledMath for uint256;
    using CurveLPTokenPricing for ICurvePoolV1;

    event ImbalanceBufferUpdated(uint256 buffer);

    uint256 internal constant _MAX_IMBALANCE_BUFFER = 0.1e18;
    uint256 public imbalanceBuffer;

    IController private immutable _controller;
    IOracle private immutable _genericOracle;

    constructor(address _controller_) {
        _controller = IController(_controller_);
        _genericOracle = IOracle(IController(_controller_).priceOracle());
    }

    function isTokenSupported(address token) external view override returns (bool) {
        ICurveRegistryCache curveRegistryCache = _controller.curveRegistryCache();
        address curvePoolAddress_ = curveRegistryCache.poolFromLpToken(token);
        if (!curveRegistryCache.isRegistered(curvePoolAddress_)) {
            return false;
        }
        if (curveRegistryCache.assetType(curvePoolAddress_) == CurvePoolUtils.AssetType.CRYPTO) {
            return false;
        }
        // this oracle does not support meta-pools
        if (curveRegistryCache.basePool(curvePoolAddress_) != address(0)) {
            return false;
        }
        return curveRegistryCache.nCoins(curvePoolAddress_) == 2;
    }

    function getUSDPrice(address token) external view returns (uint256) {
        ICurveRegistryCache curveRegistryCache = _controller.curveRegistryCache();
        ICurvePoolV1 curvePool = ICurvePoolV1(curveRegistryCache.poolFromLpToken(token));
        address[] memory coins = curveRegistryCache.coins(address(curvePool));
        uint256 _numberOfCoins = curveRegistryCache.nCoins(address(curvePool));
        require(_numberOfCoins == 2, "only 2 coin pools are supported");
        uint256[] memory decimals = curveRegistryCache.decimals(address(curvePool));
        CurvePoolUtils.AssetType assetType = curveRegistryCache.assetType(address(curvePool));
        require(assetType != CurvePoolUtils.AssetType.CRYPTO, "crypto pool not supported");

        uint256[] memory prices = new uint256[](_numberOfCoins);
        uint256[] memory imbalanceBuffers = new uint256[](_numberOfCoins);
        uint256 imbalanceBuffer_ = imbalanceBuffer;
        for (uint256 i; i < _numberOfCoins; i++) {
            address coin = coins[i];
            uint256 price = _genericOracle.getUSDPrice(coin);
            prices[i] = price;
            imbalanceBuffers[i] = imbalanceBuffer_;
            require(price > 0, "price is 0");
        }

        // Verifying the pool is balanced
        CurvePoolUtils.ensurePoolBalanced(
            CurvePoolUtils.PoolMeta({
                pool: address(curvePool),
                numberOfCoins: _numberOfCoins,
                assetType: assetType,
                decimals: decimals,
                prices: prices,
                imbalanceBuffers: imbalanceBuffers
            })
        );

        // Returning the value of the pool in USD per LP Token
        return
            curvePool.getV1LpTokenPrice(prices[0].divDown(prices[1]), ScaledMath.ONE).mulDown(
                prices[1]
            );
    }

    function setImbalanceBuffer(uint256 buffer) external onlyOwner {
        require(buffer <= _MAX_IMBALANCE_BUFFER, "buffer too high");
        imbalanceBuffer = buffer;
        emit ImbalanceBufferUpdated(buffer);
    }

    function _getCurvePool(address lpToken_) internal view returns (address) {
        return _controller.curveRegistryCache().poolFromLpToken(lpToken_);
    }
}
