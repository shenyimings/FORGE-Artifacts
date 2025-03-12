// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../SinglePlus.sol";
import "../../interfaces/acbtc/IACoconutMaker.sol";

/**
 * @dev Single plus for ACoconut BTC+.
 */
contract ACoconutBTCPlus is SinglePlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    address public constant ACOCONUT_BTC = address(0xeF6e45af9a422c5469928F927ca04ed332322e2e);
    address public constant ACOCONUT_MAKER = address(0xF42cD30b2E34B77eDB1887Fba0Df93EBE85Fd50C);

    /**
     * @dev Initializes acBTC-BSC+.
     */
    function initialize() public initializer {
        SinglePlus.initialize(ACOCONUT_BTC, "", "");

        IERC20Upgradeable(ACOCONUT_BTC).safeApprove(ACOCONUT_MAKER, uint256(int256(-1)));
    }

    /**
     * @dev Retrive the underlying assets from the investment.
     * Only governance or strategist can call this function.
     */
    function divest() public virtual override onlyStrategist {
        uint256 _share = IERC20Upgradeable(ACOCONUT_MAKER).balanceOf(address(this));
        IACoconutMaker(ACOCONUT_MAKER).redeem(_share);
    }

    /**
     * @dev Returns the amount that can be invested now. The invested token
     * does not have to be the underlying token.
     * investable > 0 means it's time to call invest.
     */
    function investable() public view virtual override returns (uint256) {
        return IERC20Upgradeable(ACOCONUT_BTC).balanceOf(address(this));
    }

    /**
     * @dev Invest the underlying assets for additional yield.
     * Only governance or strategist can call this function.
     */
    function invest() public virtual override onlyStrategist {
        uint256 _balance = IERC20Upgradeable(ACOCONUT_BTC).balanceOf(address(this));
        if (_balance > 0) {
            IACoconutMaker(ACOCONUT_MAKER).mint(_balance);
        }
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken(). The following two
     * tokens are not salvageable:
     * 1) acsBTCB
     * 2) ACS
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view virtual override returns (bool) {
        return _token != ACOCONUT_BTC && _token != ACOCONUT_MAKER;
    }

    /**
     * @dev Returns the amount of single plus token is worth for one underlying token, expressed in WAD.
     * ACoconutMaker's exchange rate is already in WAD.
     */
    function _conversionRate() internal view virtual override returns (uint256) {
        // The share price is in WAD.
        return IACoconutMaker(ACOCONUT_MAKER).exchangeRate();
    }

    /**
     * @dev Withdraws underlying tokens.
     * @param _receiver Address to receive the token withdraw.
     * @param _amount Amount of underlying token withdraw.
     */
    function _withdraw(address _receiver, uint256  _amount) internal virtual override {
        IERC20Upgradeable _token = IERC20Upgradeable(ACOCONUT_BTC);
        uint256 _balance = _token.balanceOf(address(this));
        if (_balance < _amount) {
            // Redeem from acBTCx
            uint256 _share = _amount.sub(_balance).mul(WAD).div(_conversionRate());
            IACoconutMaker(ACOCONUT_MAKER).redeem(_share);

            // In case of rounding errors
            _amount = MathUpgradeable.min(_amount, _token.balanceOf(address(this)));
        }
        _token.safeTransfer(_receiver, _amount);
    }
}