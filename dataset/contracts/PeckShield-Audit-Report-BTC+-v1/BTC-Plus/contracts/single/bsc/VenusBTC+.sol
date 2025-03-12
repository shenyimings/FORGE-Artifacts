// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../SinglePlus.sol";
import "../../interfaces/venus/IVAIVault.sol";
import "../../interfaces/venus/IVToken.sol";
import "../../interfaces/venus/IVAIController.sol";
import "../../interfaces/venus/IVenusComptroller.sol";
import "../../interfaces/compound/ICToken.sol";
import "../../interfaces/uniswap/IUniswapRouter.sol";

/**
 * @dev Single plus of Venus BTC.
 */
contract VenusBTCPlus is SinglePlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    event VaiRatioUpdated(uint256 oldLower, uint256 oldTarget, uint256 oldUpper, uint256 newLower, uint256 newTarget, uint256 newUpper);

    address public constant BTCB = address(0x7130d2A12B9BCbFAe4f2634d864A1Ee1Ce3Ead9c);
    address public constant WBNB = address(0xbb4CdB9CBd36B01bD1cBaEBF2De08d9173bc095c);
    address public constant VAI = address(0x4BD17003473389A42DAF6a0a729f6Fdb328BbBd7);
    address public constant VAI_VAULT = address(0x0667Eed0a0aAb930af74a3dfeDD263A73994f216);
    address public constant VAI_CONTROLLER = address(0x004065D34C6b18cE4370ced1CeBDE94865DbFAFE);
    address public constant VENUS = address(0xcF6BB5389c92Bdda8a3747Ddb454cB7a64626C63);
    address public constant VENUS_BTC = address(0x882C173bC7Ff3b7786CA16dfeD3DFFfb9Ee7847B);
    address public constant VENUS_COMPTROLLER = address(0xfD36E2c2a6789Db23113685031d7F16329158384);
    address public constant PANCAKE_SWAP_ROUTER = address(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F);

    // VAI ratios based on Venus's VAI mint rate
    uint256 public lowerRatio;  // Lower bound of VAI mint rate = lower ratio * VenusComptroller.vaiMintRate()
    uint256 public targetRatio; // Target VAI mint rate = target ratio * VenusComptroller.vaiMintRate()
    uint256 public upperRatio;  // Upper bound of VAI mint rate = upper ratio * VenusComptroller.vaiMintRate()

    /**
     * @dev Initializes vBTC+.
     */
    function initialize() public initializer {
        SinglePlus.initialize(VENUS_BTC, "", "");

        address[] memory _markets = new address[](1);
        _markets[0] = VENUS_BTC;
        IVenusComptroller(VENUS_COMPTROLLER).enterMarkets(_markets);

        lowerRatio = 7000;   // 70% * 60% = 42%
        targetRatio = 8000;  // 80% * 60% = 48%;
        upperRatio = 9000;   // 90% * 60% = 54%;
    }

    /**
     * @dev Determines the current liquidity of vBTC+
     * @return Total account collateral, total account debt, current ltv
     */
    function getLiquidity() public view returns (uint256, uint256, uint256) {
        // The only debt is VAI
        uint256 _vai = IVenusComptroller(VENUS_COMPTROLLER).mintedVAIs(address(this));
        // The only collateral is BTCB
        (, uint256 _liquidity, uint256 _shortfall) = IVenusComptroller(VENUS_COMPTROLLER).getAccountLiquidity(address(this));
        uint256 _collateral;

        if (_liquidity > 0) {
            // Account liquidity is in excess of collateral requirement
            _collateral = _vai.add(_liquidity);
        } else {
            // Account shortfall below collateral requirement
            _collateral = _vai.sub(_shortfall);
        }

        return (_collateral, _vai, _vai.mul(PERCENT_MAX).div(_collateral));
    }

    /**
     * @dev Retrive the underlying assets from the investment.
     * Only governance or strategist can call this function.
     */
    function divest() public virtual override onlyStrategist {
        // Withdraws all VAI from VAI vault
        uint256 _vai = IVAIVault(VAI_VAULT).userInfo(address(this)).amount;
        if (_vai > 0) {
            IVAIVault(VAI_VAULT).withdraw(_vai);
        }

        // Repays all VAI
        _vai = IERC20Upgradeable(VAI).balanceOf(address(this));
        if ((_vai > 0)) {
            IERC20Upgradeable(VAI).safeApprove(VAI_CONTROLLER, 0);
            IERC20Upgradeable(VAI).safeApprove(VAI_CONTROLLER, _vai);
            IVAIController(VAI_CONTROLLER).repayVAI(_vai);
        }
    }

    /**
     * @dev Returns the amount that can be invested now. The invested token
     * does not have to be the underlying token.
     * investable > 0 means it's time to call invest.
     */
    function investable() public view virtual override returns (uint256) {
        (uint256 _collateral, uint256 _debt, ) = getLiquidity();
        uint256 _vaiMintRate = IVenusComptroller(VENUS_COMPTROLLER).vaiMintRate();

        // vaiMintRate is scaled with 10000
        uint256 _lowerDebt = _collateral.mul(_vaiMintRate).mul(lowerRatio).div(PERCENT_MAX).div(10000);
        uint256 _targetDebt = _collateral.mul(_vaiMintRate).mul(targetRatio).div(PERCENT_MAX).div(10000);
        uint256 _upperDebt = _collateral.mul(_vaiMintRate).mul(upperRatio).div(PERCENT_MAX).div(10000);

        return _debt < _lowerDebt ? _targetDebt.sub(_debt) : (_debt > _upperDebt ? _debt.sub(_targetDebt) : 0);
    }

    /**
     * @dev Invest the underlying assets for additional yield.
     */
    function _invest() internal {
        (uint256 _collateral, uint256 _debt, ) = getLiquidity();
        uint256 _vaiMintRate = IVenusComptroller(VENUS_COMPTROLLER).vaiMintRate();

        // vaiMintRate is scaled with 10000
        uint256 _lowerDebt = _collateral.mul(_vaiMintRate).mul(lowerRatio).div(PERCENT_MAX).div(10000);
        uint256 _targetDebt = _collateral.mul(_vaiMintRate).mul(targetRatio).div(PERCENT_MAX).div(10000);
        uint256 _upperDebt = _collateral.mul(_vaiMintRate).mul(upperRatio).div(PERCENT_MAX).div(10000);

        if (_debt < _lowerDebt) {
            // We need to mint more VAI!
            // Mints maximum VAI using vBTC as collateral
            IVAIController(VAI_CONTROLLER).mintVAI(_targetDebt.sub(_debt));
            uint256 _vai = IERC20Upgradeable(VAI).balanceOf(address(this));

            IERC20Upgradeable(VAI).safeApprove(VAI_VAULT, 0);
            IERC20Upgradeable(VAI).safeApprove(VAI_VAULT, _vai);

            // Stakes VAI into VAI vault
            IVAIVault(VAI_VAULT).deposit(_vai);
        } else if (_debt > _upperDebt) {
            // We need to repay some VAI!
            uint256 _shortfall = _debt.sub(_targetDebt);
            IVAIVault(VAI_VAULT).withdraw(_shortfall);
            IERC20Upgradeable(VAI).safeApprove(VAI_CONTROLLER, 0);
            IERC20Upgradeable(VAI).safeApprove(VAI_CONTROLLER, _shortfall);
            IVAIController(VAI_CONTROLLER).repayVAI(_shortfall);
        }
    }

    /**
     * @dev Invest the underlying assets for additional yield.
     * Only governance or strategist can call this function.
     */
    function invest() public virtual override onlyStrategist {
        _invest();
    }

    /**
     * @dev Returns the amount of reward that could be harvested now.
     * harvestable > 0 means it's time to call harvest.
     */
    function harvestable() public view virtual override returns (uint256) {
        // It will take some code to estimate the pending Venus in Comptroller,
        // and Comptroller does not provide such a view method. Therefore, we
        // use the pending Venus in VAI Vault as an estimate!
        return IVAIVault(VAI_VAULT).pendingXVS(address(this));
    }

    /**
     * @dev Harvest additional yield from the investment.
     * Only governance or strategist can call this function.
     */
    function harvest() public virtual override onlyStrategist {
        // Harvest from Venus comptroller
        IVenusComptroller(VENUS_COMPTROLLER).claimVenus(address(this));

        // Harvest from VAI controller
        IVAIVault(VAI_VAULT).claim();

        uint256 _venus = IERC20Upgradeable(VENUS).balanceOf(address(this));
        // PancakeSawp: XVS --> WBNB --> BTCB
        if (_venus > 0) {
            IERC20Upgradeable(VENUS).safeApprove(PANCAKE_SWAP_ROUTER, 0);
            IERC20Upgradeable(VENUS).safeApprove(PANCAKE_SWAP_ROUTER, _venus);

            address[] memory _path = new address[](3);
            _path[0] = VENUS;
            _path[1] = WBNB;
            _path[2] = BTCB;

            IUniswapRouter(PANCAKE_SWAP_ROUTER).swapExactTokensForTokens(_venus, uint256(0), _path, address(this), block.timestamp.add(1800));
        }
        // Venus: BTCB --> vBTC
        uint256 _btcb = IERC20Upgradeable(BTCB).balanceOf(address(this));
        if (_btcb == 0) return;

        // If there is performance fee, charged in BTCB
        uint256 _fee = 0;
        if (performanceFee > 0) {
            _fee = _btcb.mul(performanceFee).div(PERCENT_MAX);
            IERC20Upgradeable(BTCB).safeTransfer(treasury, _fee);
            _btcb = _btcb.sub(_fee);
        }

        IERC20Upgradeable(BTCB).safeApprove(VENUS_BTC, 0);
        IERC20Upgradeable(BTCB).safeApprove(VENUS_BTC, _btcb);
        IVToken(VENUS_BTC).mint(_btcb);

        // Reinvest to get compound yield.
        _invest();
        // Also it's a good time to rebase!
        rebase();

        emit Harvested(VENUS_BTC, _btcb, _fee);
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken(). The following three
     * tokens are not salvageable:
     * 1) vBTC
     * 2) XVS
     * 3) VAI
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view virtual override returns (bool) {
        return _token != VENUS_BTC && _token != VENUS && _token != VAI;
    }

    /**
     * @dev Returns the amount of single plus token is worth for one underlying token, expressed in WAD.
     * Venus forks Compound so we use cToken interface from Compound.
     */
    function _conversionRate() internal view virtual override returns (uint256) {
        // The exchange rate is in WAD
        return ICToken(VENUS_BTC).exchangeRateStored();
    }

    /**
     * @dev Withdraws underlying tokens.
     * @param _receiver Address to receive the token withdraw.
     * @param _amount Amount of underlying token withdraw.
     */
    function _withdraw(address _receiver, uint256  _amount) internal virtual override {
        (,,uint256 _shortfall) = IVenusComptroller(VENUS_COMPTROLLER).getHypotheticalAccountLiquidity(address(this), VENUS_BTC, _amount, 0);
        if (_shortfall > 0) {
            IVAIVault(VAI_VAULT).withdraw(_shortfall);
            IERC20Upgradeable(VAI).safeApprove(VAI_CONTROLLER, 0);
            IERC20Upgradeable(VAI).safeApprove(VAI_CONTROLLER, _shortfall);
            IVAIController(VAI_CONTROLLER).repayVAI(_shortfall);
        }

        IERC20Upgradeable(VENUS_BTC).safeTransfer(_receiver, _amount);

        // Time to re-invest after withdraw!
        _invest();
    }

    /**
     * @dev Updates VAI ratios. Only strategist can update VAI ratios.
     */
    function setVaiRatios(uint256 _lower, uint256 _target, uint256 _upper) public onlyStrategist {
        require(_lower <= _target && _target <= _upper && _upper <= PERCENT_MAX, "invalid ratio");

        uint256 _oldLower = lowerRatio;
        uint256 _oldTarget = targetRatio;
        uint256 _oldUpper = upperRatio;

        lowerRatio = _lower;
        targetRatio = _target;
        upperRatio = _upper;

        // Time to re-invest after setting new rates!
        _invest();

        emit VaiRatioUpdated(_oldLower, _oldTarget, _oldUpper, _lower, _target, _upper);
    }
}