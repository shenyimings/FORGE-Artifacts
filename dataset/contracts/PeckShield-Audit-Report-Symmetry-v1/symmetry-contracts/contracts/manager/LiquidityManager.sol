// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/utils/math/SafeCast.sol";
import "@openzeppelin/contracts/access/AccessControlEnumerable.sol";

import "../utils/SafeDecimalMath.sol";
import "../utils/SignedSafeDecimalMath.sol";
import "../utils/Initializable.sol";

import "../interfaces/IMarketSettings.sol";
import "../interfaces/IMarket.sol";

import "../market/MarketSettingsContext.sol";

import "../tokens/LPToken.sol";

import "../security/PauseControl.sol";

contract LiquidityManager is MarketSettingsContext, AccessControlEnumerable, PauseControl, Initializable {
    using SignedSafeDecimalMath for int;
    using SafeDecimalMath for uint;
    using SafeCast for int;
    using SafeCast for uint;

    // reserved storage slots for base contract upgrade in future
    uint[50] private __gap;

    // states
    address public market;
    address public lpToken;

    event AddLiquidity(address account, uint amount, int lpNetValue, uint usdAmount, uint mintAmount);

    event RemoveLiquidity(
        address account,
        uint redeemAmount,
        int lpNetValue,
        uint redeemUsdAmount,
        uint redeemFee,
        uint amountOut
    );

    /*=== initialize ===*/

    function initialize(address _market, address _lpToken) external onlyInitializeOnce {
        market = _market;
        lpToken = _lpToken;

        _setupRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _setupRole(PAUSER_ROLE, msg.sender);
    }

    /*=== liquidity ===*/

    function addLiquidity(
        uint _amount,
        uint _minLp,
        address _receiver,
        bool _stake
    ) external whenNotPaused returns (uint) {
        return _addLiquidity(msg.sender, _amount, _minLp, _receiver, _stake);
    }

    function removeLiquidity(uint _amount, uint _minOut, address _receiver) external returns (uint) {
        return _removeLiquidity(msg.sender, _amount, _minOut, _receiver);
    }

    function getLpOut(uint _amount) public view returns (int lpNetValue, uint usdAmount, uint mintAmount) {
        IMarket market_ = IMarket(market);

        usdAmount = market_.baseTokenToUsd(_amount.toInt256(), false).toUint256();

        uint lpSupply = LPToken(lpToken).totalSupply();
        mintAmount = usdAmount;
        if (lpSupply > 0) {
            (lpNetValue, , ) = market_.globalStatus();
            if (lpNetValue > 0) mintAmount = (lpSupply * usdAmount) / uint(lpNetValue);
        }
    }

    function _addLiquidity(
        address _account,
        uint _amount,
        uint _minLp,
        address _receiver,
        bool _stake
    ) internal returns (uint) {
        (int lpNetValue, uint usdAmount, uint mintAmount) = getLpOut(_amount);

        require(mintAmount >= _minLp, "LiquidityManager: insufficient lp amount");
        // transfer funds
        IMarket(market).transferLiquidityIn(_account, _amount);
        if (_stake) {
            LPToken(lpToken).mintAndStake(_receiver, mintAmount);
        } else {
            LPToken(lpToken).mint(_receiver, mintAmount);
        }

        emit AddLiquidity(_receiver, _amount, lpNetValue, usdAmount, mintAmount);
        return mintAmount;
    }

    function _removeLiquidity(address _account, uint _amount, uint _minOut, address _receiver) internal returns (uint) {
        IMarket market_ = IMarket(market);
        // check lp token price and free lp value
        (int lpNetValue, int netOpenInterest, ) = market_.globalStatus();
        require(lpNetValue > 0, "LiquidityManager: lp bankrupted");
        LPToken lpToken_ = LPToken(lpToken);
        int redeemValue = (lpNetValue * _amount.toInt256()) / lpToken_.totalSupply().toInt256(); // must be non-negative
        require(lpNetValue - netOpenInterest >= redeemValue, "LiquidityManager: insufficient free lp");
        int redeemFee = 0;
        {
            // redeem trade
            redeemFee += IMarket(market).redeemSwap(lpNetValue, redeemValue).toInt256();
            // redeem fee
            redeemFee += IMarketSettings(market_.settings()).getIntVals(LIQUIDITY_REDEEM_FEE).multiplyDecimal(
                redeemValue - redeemFee
            );
            // TODO: where the fee goes?
        }
        require(redeemValue > redeemFee, "LiquidityManager: non-positive redeem value");
        // burn lp
        lpToken_.burn(_account, _amount);
        // withdraw token
        uint amountOut = market_.usdToBaseToken(redeemValue - redeemFee, true).toUint256();
        require(amountOut >= _minOut, "LiquidityManager: insufficient amountOut");
        market_.transferLiquidityOut(_receiver, amountOut);

        emit RemoveLiquidity(_account, _amount, lpNetValue, redeemValue.toUint256(), redeemFee.toUint256(), amountOut);

        return amountOut;
    }
}
