// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../SinglePlus.sol";
import "../../interfaces/autofarm/IAutoBTC.sol";
import "../../interfaces/fortube/IForTubeReward.sol";
import "../../interfaces/fortube/IForTubeBank.sol";
import "../../interfaces/uniswap/IUniswapRouter.sol";

/**
 * @dev Single Plus for AutoFarm BTC+.
 */
contract AutoBTCPlus is SinglePlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    address public constant BTCB = address(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    address public constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address public constant AUTOv2 = address(0xa184088a740c695E156F91f5cC086a06bb78b827);
    // Update when AUTO_BTC is deployed
    address public constant AUTO_BTC = address(0x6B7Ea9F1EF1E6c662761201998Dc876b88Ed7414);
    address public constant PANCAKE_SWAP_ROUTER = address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);

    /**
     * @dev Initializes fBTCB+.
     */
    function initialize() public initializer {
        SinglePlus.initialize(AUTO_BTC, "", "");
        // Trust AutoBTC
        IERC20Upgradeable(BTCB).safeApprove(AUTO_BTC, uint256(int256(-1)));
    }

    /**
     * @dev Returns the amount of reward that could be harvested now.
     * harvestable > 0 means it's time to call harvest.
     */
    function harvestable() public view virtual override returns (uint256) {
        return IAutoBTC(AUTO_BTC).pendingReward(address(this));
    }

    /**
     * @dev Harvest additional yield from the investment.
     * Only governance or strategist can call this function.
     */
    function harvest() public virtual override onlyStrategist {
        // Harvest from AutoBTC
        IAutoBTC(AUTO_BTC).claimRewards();

        uint256 _auto = IERC20Upgradeable(AUTOv2).balanceOf(address(this));
        // PancakeSawp: AUTO --> WBNB --> BTCB
        if (_auto > 0) {
            IERC20Upgradeable(AUTOv2).safeApprove(PANCAKE_SWAP_ROUTER, 0);
            IERC20Upgradeable(AUTOv2).safeApprove(PANCAKE_SWAP_ROUTER, _auto);

            address[] memory _path = new address[](3);
            _path[0] = AUTOv2;
            _path[1] = WBNB;
            _path[2] = BTCB;

            IUniswapRouter(PANCAKE_SWAP_ROUTER).swapExactTokensForTokens(_auto, uint256(0), _path, address(this), block.timestamp.add(1800));
        }
        
        // BTCB --> AutoBTC
        uint256 _btcb = IERC20Upgradeable(BTCB).balanceOf(address(this));
        if (_btcb == 0) return;

        // If there is performance fee, charged in BTCB
        uint256 _fee = 0;
        if (performanceFee > 0) {
            _fee = _btcb.mul(performanceFee).div(PERCENT_MAX);
            IERC20Upgradeable(BTCB).safeTransfer(treasury, _fee);
            _btcb = _btcb.sub(_fee);
        }

        IAutoBTC(AUTO_BTC).mint(_btcb);

        // Reinvest to get compound yield.
        invest();
        // Also it's a good time to rebase!
        rebase();

        emit Harvested(AUTO_BTC, _btcb, _fee);
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken(). The following two
     * tokens are not salvageable:
     * 1) autoBTC
     * 2) AUTO
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view virtual override returns (bool) {
        return _token != AUTO_BTC && _token != AUTOv2;
    }

    /**
     * @dev Returns the amount of single plus token is worth for one underlying token, expressed in WAD.
     */
    function _conversionRate() internal view virtual override returns (uint256) {
        // AutoBTC has 18 decimals and exchangeRate is in WAD
        return IAutoBTC(AUTO_BTC).exchangeRate();
    }
}