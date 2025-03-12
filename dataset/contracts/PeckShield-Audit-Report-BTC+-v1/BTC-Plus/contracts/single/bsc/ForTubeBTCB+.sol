// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../SinglePlus.sol";
import "../../interfaces/compound/ICToken.sol";
import "../../interfaces/fortube/IForTubeReward.sol";
import "../../interfaces/fortube/IForTubeBank.sol";
import "../../interfaces/uniswap/IUniswapRouter.sol";

/**
 * @dev Single Plus for ForTube BCTB.
 */
contract ForTubeBTCBPlus is SinglePlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    address public constant BTCB = address(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    address public constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address public constant FOR = address(0x658A109C5900BC6d2357c87549B651670E5b0539);
    address public constant FORTUBE_BTCB = address(0xb5C15fD55C73d9BeeC046CB4DAce1e7975DcBBBc);
    address public constant FORTUBE_CONTROLLER = address(0xc78248D676DeBB4597e88071D3d889eCA70E5469);
    address public constant FORTUBE_BANK = address(0x0cEA0832e9cdBb5D476040D58Ea07ecfbeBB7672);
    address public constant FORTUBE_REWARD = address(0x55838F18e79cFd3EA22Eea08Bd3Ec18d67f314ed);
    address public constant PANCAKE_SWAP_ROUTER = address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);

    /**
     * @dev Initializes fBTCB+.
     */
    function initialize() public initializer {
        SinglePlus.initialize(FORTUBE_BTCB, "", "");
    }

    /**
     * @dev Returns the amount of reward that could be harvested now.
     * harvestable > 0 means it's time to call harvest.
     */
    function harvestable() public view virtual override returns (uint256) {
        return IForTubeReward(FORTUBE_REWARD).checkBalance(address(this));
    }

    /**
     * @dev Harvest additional yield from the investment.
     * Only governance or strategist can call this function.
     */
    function harvest() public virtual override onlyStrategist {
        // Harvest from FurTube rewards
        uint256 _reward = IForTubeReward(FORTUBE_REWARD).checkBalance(address(this));
        if (_reward > 0) {
            IForTubeReward(FORTUBE_REWARD).claimReward();
        }

        uint256 _for = IERC20Upgradeable(FOR).balanceOf(address(this));
        // PancakeSawp: FOR --> WBNB --> BTCB
        if (_for > 0) {
            IERC20Upgradeable(FOR).safeApprove(PANCAKE_SWAP_ROUTER, 0);
            IERC20Upgradeable(FOR).safeApprove(PANCAKE_SWAP_ROUTER, _for);

            address[] memory _path = new address[](3);
            _path[0] = FOR;
            _path[1] = WBNB;
            _path[2] = BTCB;

            IUniswapRouter(PANCAKE_SWAP_ROUTER).swapExactTokensForTokens(_for, uint256(0), _path, address(this), block.timestamp.add(1800));
        }
        // ForTube: BTCB --> fBTCB
        uint256 _btcb = IERC20Upgradeable(BTCB).balanceOf(address(this));
        if (_btcb > 0) {
            IERC20Upgradeable(BTCB).safeApprove(FORTUBE_CONTROLLER, 0);
            IERC20Upgradeable(BTCB).safeApprove(FORTUBE_CONTROLLER, _btcb);
            IForTubeBank(FORTUBE_BANK).deposit(BTCB, _btcb);
        }
        uint256 _fbtc = IERC20Upgradeable(FORTUBE_BTCB).balanceOf(address(this));
        if (_fbtc == 0) {
            return;
        }
        uint256 _fee = 0;
        if (performanceFee > 0) {
            _fee = _fbtc.mul(performanceFee).div(PERCENT_MAX);
            IERC20Upgradeable(FORTUBE_BTCB).safeTransfer(treasury, _fee);
        }
        // Reinvest to get compound yield.
        invest();
        // Also it's a good time to rebase!
        rebase();

        emit Harvested(FORTUBE_BTCB, _fbtc, _fee);
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken(). The following two
     * tokens are not salvageable:
     * 1) fBTCB
     * 2) FOR
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view virtual override returns (bool) {
        return _token != FORTUBE_BTCB && _token != FOR;
    }

    /**
     * @dev Returns the amount of single plus token is worth for one underlying token, expressed in WAD.
     * ForTube's fToken interface is compactible with Compound's cToken.
     */
    function _conversionRate() internal view virtual override returns (uint256) {
        // fBTC has 18 decimals and exchangeRate is in WAD
        return ICToken(FORTUBE_BTCB).exchangeRateStored();
    }
}