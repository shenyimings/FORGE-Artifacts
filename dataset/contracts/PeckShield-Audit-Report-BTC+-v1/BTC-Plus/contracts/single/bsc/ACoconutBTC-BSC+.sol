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
 * @dev Single plus for ACoconutBTC-BSC+.
 */
contract ACoconutBTCBscPlus is SinglePlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    address public constant BTCB = address(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    address public constant ACBTC_BSC = address(0xCEF9Ddbf860551cC8505C0BcfF0Bc8C10d59e229);
    address public constant ACMAKER = address(0x1FacDB7951541Bd4bf78B34590cf52E65E938b5A);

    /**
     * @dev Initializes acBTC-BSC+.
     */
    function initialize() public initializer {
        SinglePlus.initialize(ACBTC_BSC, "", "");

        IERC20Upgradeable(ACBTC_BSC).safeApprove(ACMAKER, uint256(int256(-1)));
    }

    /**
     * @dev Retrive the underlying assets from the investment.
     * Only governance or strategist can call this function.
     */
    function divest() public virtual override onlyStrategist {
        uint256 _share = IERC20Upgradeable(ACMAKER).balanceOf(address(this));
        IACoconutMaker(ACMAKER).redeem(_share);
    }

    /**
     * @dev Returns the amount that can be invested now. The invested token
     * does not have to be the underlying token.
     * investable > 0 means it's time to call invest.
     */
    function investable() public view virtual override returns (uint256) {
        return IERC20Upgradeable(ACBTC_BSC).balanceOf(address(this));
    }

    /**
     * @dev Invest the underlying assets for additional yield.
     * Only governance or strategist can call this function.
     */
    function invest() public virtual override onlyStrategist {
        uint256 _balance = IERC20Upgradeable(ACBTC_BSC).balanceOf(address(this));
        if (_balance > 0) {
            IACoconutMaker(ACMAKER).mint(_balance);
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
        return _token != ACBTC_BSC && _token != ACMAKER;
    }

    /**
     * @dev Returns the amount of single plus token is worth for one underlying token, expressed in WAD.
     * ACoconutMaker's exchange rate is already in WAD.
     */
    function _conversionRate() internal view virtual override returns (uint256) {
        // The share price is in WAD.
        return IACoconutMaker(ACMAKER).exchangeRate();
    }

    /**
     * @dev Withdraws underlying tokens.
     * @param _receiver Address to receive the token withdraw.
     * @param _amount Amount of underlying token withdraw.
     */
    function _withdraw(address _receiver, uint256  _amount) internal virtual override {
        IERC20Upgradeable _token = IERC20Upgradeable(ACBTC_BSC);
        uint256 _balance = _token.balanceOf(address(this));
        if (_balance < _amount) {
            // Redeem from acBTCx
            uint256 _share = _amount.sub(_balance).mul(WAD).div(_conversionRate());
            IACoconutMaker(ACMAKER).redeem(_share);

            // In case of rounding errors
            _amount = MathUpgradeable.min(_amount, _token.balanceOf(address(this)));
        }
        _token.safeTransfer(_receiver, _amount);
    }
}