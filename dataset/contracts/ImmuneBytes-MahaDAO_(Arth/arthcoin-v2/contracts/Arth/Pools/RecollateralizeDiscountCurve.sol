// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {IERC20} from '../../ERC20/IERC20.sol';
import {SafeMath} from '../../Math/SafeMath.sol';
import {Ownable} from '../../Common/Ownable.sol';
import {IARTHController} from '../IARTHController.sol';

/**
 * @title  RecollateralizeDiscountCruve.
 * @author MahaDAO.
 */
contract RecollateralizeDiscountCurve is Ownable {
    using SafeMath for uint256;

    /**
     * @dev Contract instances.
     */

    IERC20 private _ARTH;
    IARTHController private _arthController;

    /// @notice Bonus rate on ARTHX minted when recollateralizing.
    uint256 public bonusRate = 7500; // 6 decimals of precision, is set to 0.75% on genesis.

    constructor(IERC20 __ARTH, IARTHController __arthController) {
        _ARTH = __ARTH;
        _arthController = __arthController;
    }

    function setBonusRate(uint256 rate) public onlyOwner {
        require(
            bonusRate <= 1e6,
            'RecollateralizeDiscountCurve: bonusRate > MAX(precision)'
        );

        bonusRate = rate;
    }

    function getTargetCollateralValue() public view returns (uint256) {
        return
            _ARTH
                .totalSupply()
                .mul(_arthController.getGlobalCollateralRatio())
                .div(1e6);
    }

    function getCurveExponent() public view returns (uint256) {
        uint256 targetCollatValue = getTargetCollateralValue();
        uint256 currentCollatValue = _arthController.getGlobalCollateralRatio();

        if (targetCollatValue <= currentCollatValue) return 0;

        return
            targetCollatValue
                .sub(currentCollatValue)
                .mul(1e6)
                .div(targetCollatValue)
                .div(1e6);
    }

    function getCurvedDiscount() public view returns (uint256) {
        uint256 exponent = getCurveExponent();
        if (exponent == 0) return 0;

        uint256 discount = (10**exponent).sub(1).div(10).mul(bonusRate);

        // Fail safe cap to bonus_rate.
        return discount > bonusRate ? bonusRate : discount;
    }
}
