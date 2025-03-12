// SPDX-License-Identifier: MIT
pragma solidity 0.8.0;
pragma experimental ABIEncoderV2;

import "@openzeppelin/contracts-upgradeable/utils/math/MathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/math/SafeMathUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";

import "../../SinglePlus.sol";
import "../../interfaces/IConverter.sol";
import "../../interfaces/curve/ICurveFi.sol";
import "../../interfaces/badger/IBadgerSett.sol";
import "../../interfaces/badger/IBadgerGeyser.sol";
import "../../interfaces/badger/IBadgerTree.sol";
import "../../interfaces/uniswap/IUniswapRouter.sol";

/**
 * @dev Single plus for Badger renCrv.
 */
contract BadgerRenCrvPlus is SinglePlus {
    using SafeERC20Upgradeable for IERC20Upgradeable;
    using SafeMathUpgradeable for uint256;

    address public constant BADGER_RENCRV = address(0x6dEf55d2e18486B9dDfaA075bc4e4EE0B28c1545);
    address public constant BADGER_RENCRV_STAKING = address(0x2296f174374508278DC12b806A7f27c87D53Ca15);
    address public constant BADGER_TREE = address(0x660802Fc641b154aBA66a62137e71f331B6d787A);
    address public constant WBTC = address(0x2260FAC5E5542a773Aa44fBCfeDf7C193bc2C599);
    address public constant WETH = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant BADGER = address(0x3472A5A71965499acd81997a54BBA8D852C6E53d);
    address public constant DIGG = address(0x798D1bE841a82a273720CE31c822C61a67a601C3);
    address public constant RENCRV = address(0x49849C98ae39Fff122806C06791Fa73784FB3675);
    address public constant UNISWAP = address(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);  // Uniswap RouterV2
    address public constant REN_SWAP = address(0x93054188d876f558f4a66B2EF1d97d16eDf0895B); // REN swap

    address public converter;

    /**
     * @dev Initializes brenCrv+.
     */
    function initialize(address _converter) public initializer {
        SinglePlus.initialize(BADGER_RENCRV, "", "");

        converter = _converter;
    }

    /**
     * @dev Retrive the underlying assets from the investment.
     * Only governance or strategist can call this function.
     */
    function divest() public virtual override onlyStrategist {
        IBadgerGeyser _geyser = IBadgerGeyser(BADGER_RENCRV_STAKING);
        _geyser.unstake(_geyser.totalStakedFor(address(this)), '');
    }

    /**
     * @dev Returns the amount that can be invested now. The invested token
     * does not have to be the underlying token.
     * investable > 0 means it's time to call invest.
     */
    function investable() public view virtual override returns (uint256) {
        return IERC20Upgradeable(BADGER_RENCRV).balanceOf(address(this));
    }

    /**
     * @dev Invest the underlying assets for additional yield.
     * Only governance or strategist can call this function.
     */
    function invest() public virtual override onlyStrategist {
        IERC20Upgradeable _token = IERC20Upgradeable(BADGER_RENCRV);
        uint256 _balance = _token.balanceOf(address(this));
        if (_balance > 0) {
            _token.safeApprove(BADGER_RENCRV_STAKING, 0);
            _token.safeApprove(BADGER_RENCRV_STAKING, _balance);
            IBadgerGeyser(BADGER_RENCRV_STAKING).stake(_balance, '');
        }
    }


    /**
     * @dev Harvest additional yield from the investment.
     * Only governance or strategist can call this function.
     */
    function harvest(address[] calldata _tokens, uint256[] calldata _cumulativeAmounts,
        uint256 _index, uint256 _cycle, bytes32[] calldata _merkleProof) public virtual onlyStrategist {
        // 1. Harvest from Badger Tree
        IBadgerTree(BADGER_TREE).claim(_tokens, _cumulativeAmounts, _index, _cycle, _merkleProof);

        // 2. Badger --> WETH --> WBTC
        uint256 _badger = IERC20Upgradeable(BADGER).balanceOf(address(this));
        if (_badger > 0) {
            IERC20Upgradeable(BADGER).safeApprove(UNISWAP, 0);
            IERC20Upgradeable(BADGER).safeApprove(UNISWAP, _badger);

            address[] memory _path = new address[](3);
            _path[0] = BADGER;
            _path[1] = WETH;
            _path[2] = WBTC;

            IUniswapRouter(UNISWAP).swapExactTokensForTokens(_badger, uint256(0), _path, address(this), block.timestamp.add(1800));
        }

        // 3: Digg --> WBTC
        uint256 _digg = IERC20Upgradeable(DIGG).balanceOf(address(this));
        if (_digg > 0) {
            IERC20Upgradeable(DIGG).safeApprove(UNISWAP, 0);
            IERC20Upgradeable(DIGG).safeApprove(UNISWAP, _digg);

            address[] memory _path = new address[](2);
            _path[0] = DIGG;
            _path[1] = WBTC;

            IUniswapRouter(UNISWAP).swapExactTokensForTokens(_digg, uint256(0), _path, address(this), block.timestamp.add(1800));
        }

        // 4: WBTC --> renCrv
        uint256 _wbtc = IERC20Upgradeable(WBTC).balanceOf(address(this));
        if (_wbtc == 0) return;

        // If there is performance fee, charged in WBTC
        uint256 _fee = 0;
        if (performanceFee > 0) {
            _fee = _wbtc.mul(performanceFee).div(PERCENT_MAX);
            IERC20Upgradeable(WBTC).safeTransfer(treasury, _fee);
            _wbtc = _wbtc.sub(_fee);
        }

        IERC20Upgradeable(WBTC).safeApprove(REN_SWAP, 0);
        IERC20Upgradeable(WBTC).safeApprove(REN_SWAP, _wbtc);
        ICurveFi(REN_SWAP).add_liquidity([0, _wbtc], 0);

        // 5: renCrv --> brenCrv
        address _converter = converter;
        uint256 _renCrv = IERC20Upgradeable(RENCRV).balanceOf(address(this));
        IERC20Upgradeable(RENCRV).safeApprove(_converter, 0);
        IERC20Upgradeable(RENCRV).safeApprove(_converter, _renCrv);

        uint256 _before = IERC20Upgradeable(BADGER_RENCRV).balanceOf(address(this));
        uint256 _target = _renCrv.mul(WAD).div(IBadgerSett(BADGER_RENCRV).getPricePerFullShare());
        IConverter(_converter).convert(RENCRV, BADGER_RENCRV, _renCrv, _target);
        uint256 _after = IERC20Upgradeable(BADGER_RENCRV).balanceOf(address(this));
        require(_after >= _before.add(_target), "convert fail");

        invest();

        // Also it's a good time to rebase!
        rebase();

        emit Harvested(BADGER_RENCRV, _wbtc, _fee);
    }

    /**
     * @dev Checks whether a token can be salvaged via salvageToken(). The following
     * tokens are not salvageable:
     * 1) brenCrv
     * 2) renCrv
     * @param _token Token to check salvageability.
     */
    function _salvageable(address _token) internal view virtual override returns (bool) {
        return _token != BADGER_RENCRV && _token != RENCRV;
    }

    /**
     * @dev Returns the amount of single plus token is worth for one underlying token, expressed in WAD.
     */
    function _conversionRate() internal view virtual override returns (uint256) {
        return IBadgerSett(BADGER_RENCRV).getPricePerFullShare();
    }

    /**
     * @dev Returns the total value of the underlying token in terms of the peg value, scaled to 18 decimals
     * and expressed in WAD.
     */
    function _totalUnderlyingInWad() internal view virtual override returns (uint256) {
        uint256 _balance = IERC20Upgradeable(BADGER_RENCRV).balanceOf(address(this));
        uint256 _staked = IBadgerGeyser(BADGER_RENCRV_STAKING).totalStakedFor(address(this));

        // Conversion rate is the amount of single plus token per underlying token, in WAD.
        return _balance.add(_staked).mul(_conversionRate());
    }

    /**
     * @dev Withdraws underlying tokens.
     * @param _receiver Address to receive the token withdraw.
     * @param _amount Amount of underlying token withdraw.
     */
    function _withdraw(address _receiver, uint256  _amount) internal virtual override {
        IERC20Upgradeable _token = IERC20Upgradeable(BADGER_RENCRV);
        uint256 _balance = _token.balanceOf(address(this));
        if (_balance < _amount) {
            IBadgerGeyser(BADGER_RENCRV_STAKING).unstake(_amount.sub(_balance), '');
            // In case of rounding errors
            _amount = MathUpgradeable.min(_amount, _token.balanceOf(address(this)));
        }
        _token.safeTransfer(_receiver, _amount);
    }
}