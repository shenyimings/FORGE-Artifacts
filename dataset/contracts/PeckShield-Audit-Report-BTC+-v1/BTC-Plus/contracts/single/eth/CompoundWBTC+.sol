// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../SinglePlus.sol";
import "../../interfaces/compound/IComptroller.sol";
import "../../interfaces/compound/ICToken.sol";
import "../../interfaces/uniswap/IUniswapRouter.sol";

/**
 * @dev Single plus of Compound WBTC.
 */
contract CompoundWBTCPlus is SinglePlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    address public constant COMPOUND_WBTC = address(0xccF4429DB6322D5C611ee964527D42E5d685DD6a);
    address public constant COMPOUND_COMPTROLLER = address(0x3d9819210A31b4961b30EF54bE2aeD79B9c9Cd3B);
    address public constant WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address public constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant COMP = address(0xc00e94Cb662C3520282E6f5717214004A7f26888);
    address public constant UNISWAP = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);  // Uniswap RouterV2

    /**
     * @dev Initializes cWBTC+.
     */
    function initialize() public initializer {
        SinglePlus.initialize(COMPOUND_WBTC, "", "");

        address[] memory _markets = new address[](1);
        _markets[0] = COMPOUND_WBTC;
        IComptroller(COMPOUND_COMPTROLLER).enterMarkets(_markets);
    }

    /**
     * @dev Harvest additional yield from the investment.
     * Only governance or strategist can call this function.
     */
    function harvest() public virtual override onlyStrategist {
        // Harvest from Compound comptroller
        address[] memory _markets = new address[](1);
        _markets[0] = COMPOUND_WBTC;
        IComptroller(COMPOUND_COMPTROLLER).claimComp(address(this), _markets);

        uint256 _comp = IERC20Upgradeable(COMP).balanceOf(address(this));
        // Uniswap: COMP --> WETH --> BTCB
        if (_comp > 0) {
            IERC20Upgradeable(COMP).safeApprove(UNISWAP, 0);
            IERC20Upgradeable(COMP).safeApprove(UNISWAP, _comp);

            address[] memory _path = new address[](3);
            _path[0] = COMP;
            _path[1] = WETH;
            _path[2] = WBTC;

            IUniswapRouter(UNISWAP).swapExactTokensForTokens(_comp, uint256(0), _path, address(this), block.timestamp.add(1800));
        }
        // Compound: WBTC --> cWBTC
        uint256 _wbtc = IERC20Upgradeable(WBTC).balanceOf(address(this));
        if (_wbtc == 0) return;

        // If there is performance fee, charged in WBTC
        uint256 _fee = 0;
        if (performanceFee > 0) {
            _fee = _wbtc.mul(performanceFee).div(PERCENT_MAX);
            IERC20Upgradeable(WBTC).safeTransfer(treasury, _fee);
            _wbtc = _wbtc.sub(_fee);
        }

        IERC20Upgradeable(WBTC).safeApprove(COMPOUND_WBTC, 0);
        IERC20Upgradeable(WBTC).safeApprove(COMPOUND_WBTC, _wbtc);
        require(ICToken(COMPOUND_WBTC).mint(_wbtc) == 0, "mint failed");

        // Also it's a good time to rebase!
        rebase();

        emit Harvested(COMPOUND_WBTC, _wbtc, _fee);
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken(). The following two
     * tokens are not salvageable:
     * 1) cWBTC
     * 2) COMP
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view virtual override returns (bool) {
        return _token != COMPOUND_WBTC && _token != COMP;
    }

    /**
     * @dev Returns the amount of single plus token is worth for one underlying token, expressed in WAD.
     */
    function _conversionRate() internal view virtual override returns (uint256) {
        // The exchange rate is in WAD
        // WBTC has 8 decimals
        // so it's cWBTC exchange rate * 10**(18 - 8)
        return ICToken(COMPOUND_WBTC).exchangeRateStored().mul(uint256(10) ** 10);
    }
}