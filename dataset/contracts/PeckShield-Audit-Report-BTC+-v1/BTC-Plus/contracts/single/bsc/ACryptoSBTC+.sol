// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../SinglePlus.sol";
import "../../interfaces/acryptos/IFarm.sol";
import "../../interfaces/yfi/IVault.sol";
import "../../interfaces/uniswap/IUniswapRouter.sol";

/**
 * @dev Single plus for ACryptoS BTC.
 */
contract ACryptoSBTCBPlus is SinglePlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    address public constant BTCB = address(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    address public constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address public constant ACS = address(0x4197C6EF3879a08cD51e5560da5064B773aa1d29);
    address public constant ACS_ACS = address(0x7679381507af0c8DE64586A458161aa58D3A4FC3);
    address public constant ACS_BTCB = address(0x0395fCC8E1a1E30A1427D4079aF6E23c805E3eeF);
    address public constant ACS_FARM = address(0xb1fa5d3c0111d8E9ac43A19ef17b281D5D4b474E);
    address public constant PANCAKE_SWAP_ROUTER = address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);

    /**
     * @dev Initializes acsBTC+.
     */
    function initialize() public initializer {
        SinglePlus.initialize(ACS_BTCB, "", "");
    }

    /**
     * @dev Retrive the underlying assets from the investment.
     * Only governance or strategist can call this function.
     */
    function divest() public virtual override onlyStrategist {
        uint256 _pool = IFarm(ACS_FARM).userInfo(ACS_BTCB, address(this)).amount;
        IFarm(ACS_FARM).withdraw(ACS_BTCB, _pool);
    }

    /**
     * @dev Returns the amount that can be invested now. The invested token
     * does not have to be the underlying token.
     * investable > 0 means it's time to call invest.
     */
    function investable() public view virtual override returns (uint256) {
        return IERC20Upgradeable(ACS_BTCB).balanceOf(address(this));
    }

    /**
     * @dev Invest the underlying assets for additional yield.
     * Only governance or strategist can call this function.
     */
    function invest() public virtual override onlyStrategist {
        uint256 _balance = IERC20Upgradeable(ACS_BTCB).balanceOf(address(this));
        if (_balance > 0) {
            IERC20Upgradeable(ACS_BTCB).safeApprove(ACS_FARM, 0);
            IERC20Upgradeable(ACS_BTCB).safeApprove(ACS_FARM, _balance);
            IFarm(ACS_FARM).deposit(ACS_BTCB, _balance);
        }
    }

    /**
     * @dev Returns the amount of reward that could be harvested now.
     * harvestable > 0 means it's time to call harvest.
     */
    function harvestable() public view virtual override returns (uint256) {
        uint256 _pending = IFarm(ACS_FARM).pendingSushi(ACS_BTCB, address(this));
        uint256 _minimum = IFarm(ACS_FARM).harvestFee();

        return _pending <= _minimum ? 0 : _pending.sub(_minimum);
    }

    /**
     * @dev Harvest additional yield from the investment.
     * Only governance or strategist can call this function.
     */
    function harvest() public virtual override onlyStrategist {
        uint256 _pending = IFarm(ACS_FARM).pendingSushi(ACS_BTCB, address(this));
        uint256 _minimum = IFarm(ACS_FARM).harvestFee();
        if (_pending <= _minimum)   return;

        // Harvest from ACryptoS Farm
        IFarm(ACS_FARM).harvest(ACS_BTCB);

        uint256 _acs = IERC20Upgradeable(ACS).balanceOf(address(this));
        // PancakeSawp: ACS --> WBNB --> BTCB
        if (_acs > 0) {
            IERC20Upgradeable(ACS).safeApprove(PANCAKE_SWAP_ROUTER, 0);
            IERC20Upgradeable(ACS).safeApprove(PANCAKE_SWAP_ROUTER, _acs);

            address[] memory _path = new address[](3);
            _path[0] = ACS;
            _path[1] = WBNB;
            _path[2] = BTCB;

            IUniswapRouter(PANCAKE_SWAP_ROUTER).swapExactTokensForTokens(_acs, uint256(0), _path, address(this), block.timestamp.add(1800));
        }
        // ACrytoS: BTCB --> acsBTCB
        uint256 _btcb = IERC20Upgradeable(BTCB).balanceOf(address(this));
        if (_btcb == 0) return;

        // If there is performance fee, charged in BTCB
        uint256 _fee = 0;
        if (performanceFee > 0) {
            _fee = _btcb.mul(performanceFee).div(PERCENT_MAX);
            IERC20Upgradeable(BTCB).safeTransfer(treasury, _fee);
            _btcb = _btcb.sub(_fee);
        }

        IERC20Upgradeable(BTCB).safeApprove(ACS_BTCB, 0);
        IERC20Upgradeable(BTCB).safeApprove(ACS_BTCB, _btcb);
        IVault(ACS_BTCB).deposit(_btcb);

        // Reinvest to get compound yield
        invest();
        // Also it's a good time to rebase!
        rebase();

        emit Harvested(ACS_BTCB, _btcb, _fee);
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken(). The following two
     * tokens are not salvageable:
     * 1) acsBTCB
     * 2) ACS
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view virtual override returns (bool) {
        return _token != ACS_BTCB && _token != ACS;
    }

    /**
     * @dev Returns the amount of single plus token is worth for one underlying token, expressed in WAD.
     * ACryptoS vault uses YFI's interface.
     */
    function _conversionRate() internal view virtual override returns (uint256) {
        // The share price is in WAD.
        return IVault(ACS_BTCB).getPricePerFullShare();
    }

    /**
     * @dev Returns the total value of the underlying token in terms of the peg value, scaled to 18 decimals
     * and expressed in WAD.
     */
    function _totalUnderlyingInWad() internal view virtual override returns (uint256) {
        uint256 _balance = IERC20Upgradeable(ACS_BTCB).balanceOf(address(this));
        _balance = _balance.add(IFarm(ACS_FARM).userInfo(ACS_BTCB, address(this)).amount);

        // Conversion rate is the amount of single plus token per underlying token, in WAD.
        return _balance.mul(_conversionRate());
    }

    /**
     * @dev Withdraws underlying tokens.
     * @param _receiver Address to receive the token withdraw.
     * @param _amount Amount of underlying token withdraw.
     */
    function _withdraw(address _receiver, uint256  _amount) internal virtual override {
        IERC20Upgradeable _token = IERC20Upgradeable(ACS_BTCB);
        uint256 _balance = _token.balanceOf(address(this));
        if (_balance < _amount) {
            IFarm(ACS_FARM).withdraw(ACS_BTCB, _amount.sub(_balance));
            // In case of rounding errors
            _amount = MathUpgradeable.min(_amount, _token.balanceOf(address(this)));
        }
        _token.safeTransfer(_receiver, _amount);
    }
}