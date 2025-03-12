// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../SinglePlus.sol";
import "../../interfaces/vesper/IVPool.sol";
import "../../interfaces/vesper/IPoolRewards.sol";
import "../../interfaces/uniswap/IUniswapRouter.sol";

/**
 * @dev Single plus for Vesper WBTC.
 */
contract VesperWBTCPlus is SinglePlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    address public constant VESPER_WBTC = address(0x4B2e76EbBc9f2923d83F5FBDe695D8733db1a17B);
    address public constant VESPER_WBTC_REWARDS = address(0x479A8666Ad530af3054209Db74F3C74eCd295f8D);
    address public constant WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address public constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant VESPER = address(0x1b40183EFB4Dd766f11bDa7A7c3AD8982e998421);
    address public constant UNISWAP = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);  // Uniswap RouterV2

    /**
     * @dev Initializes vWBTC+.
     */
    function initialize() public initializer {
        SinglePlus.initialize(VESPER_WBTC, "", "");
    }

    /**
     * @dev Returns the amount of reward that could be harvested now.
     * harvestable > 0 means it's time to call harvest.
     */
    function harvestable() public view virtual override returns (uint256) {
        return IPoolRewards(VESPER_WBTC_REWARDS).claimable(address(this));
    }

    /**
     * @dev Harvest additional yield from the investment.
     * Only governance or strategist can call this function.
     */
    function harvest() public virtual override onlyStrategist {
        // Harvest from Vesper Pool Rewards
        IPoolRewards(VESPER_WBTC_REWARDS).claimReward(address(this));

        uint256 _vsp = IERC20Upgradeable(VESPER).balanceOf(address(this));
        // Uniswap: VESPER --> WETH --> WBTC
        if (_vsp > 0) {
            IERC20Upgradeable(VESPER).safeApprove(UNISWAP, 0);
            IERC20Upgradeable(VESPER).safeApprove(UNISWAP, _vsp);

            address[] memory _path = new address[](3);
            _path[0] = VESPER;
            _path[1] = WETH;
            _path[2] = WBTC;

            IUniswapRouter(UNISWAP).swapExactTokensForTokens(_vsp, uint256(0), _path, address(this), block.timestamp.add(1800));
        }
        // Vesper: WBTC --> vWBTC
        uint256 _wbtc = IERC20Upgradeable(WBTC).balanceOf(address(this));
        if (_wbtc == 0) return;

        // If there is performance fee, charged in WBTC
        uint256 _fee = 0;
        if (performanceFee > 0) {
            _fee = _wbtc.mul(performanceFee).div(PERCENT_MAX);
            IERC20Upgradeable(WBTC).safeTransfer(treasury, _fee);
            _wbtc = _wbtc.sub(_fee);
        }

        IERC20Upgradeable(WBTC).safeApprove(VESPER_WBTC, 0);
        IERC20Upgradeable(WBTC).safeApprove(VESPER_WBTC, _wbtc);
        IVPool(VESPER_WBTC).deposit(_wbtc);

        // Also it's a good time to rebase!
        rebase();

        emit Harvested(VESPER_WBTC, _wbtc, _fee);
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken(). The following two
     * tokens are not salvageable:
     * 1) vWBTC
     * 2) VESPER
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view virtual override returns (bool) {
        return _token != VESPER_WBTC && _token != VESPER;
    }

    /**
     * @dev Returns the amount of single plus token is worth for one underlying token, expressed in WAD.
     */
    function _conversionRate() internal view virtual override returns (uint256) {
        // WBTC has 8 decimals, vWBTC has 18 decimals
        // The share price is in WAD
        // Therefore, the conversion rate must scaled 10**10!
        return IVPool(VESPER_WBTC).getPricePerShare().mul(uint256(10) ** 10);
    }
}