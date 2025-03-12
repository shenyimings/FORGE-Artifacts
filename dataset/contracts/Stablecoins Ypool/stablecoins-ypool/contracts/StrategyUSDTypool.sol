// SPDX-License-Identifier: AGPL-3.0
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

import {
    BaseStrategy,
    StrategyParams
} from "@yearnvaults/contracts/BaseStrategy.sol";
import "@openzeppelinV3/contracts/token/ERC20/IERC20.sol";
import "@openzeppelinV3/contracts/math/SafeMath.sol";
import "@openzeppelinV3/contracts/utils/Address.sol";
import "@openzeppelinV3/contracts/token/ERC20/SafeERC20.sol";

import "../interfaces/yearn/Vault.sol";
import "../interfaces/curve/ICurve.sol";


contract StrategyUSDTypool is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address constant public ypool = address(0x45F783CCE6B7FF23B2ab2D70e416cdb7D6055f51);
    address constant public ycrv = address(0xdF5e0e81Dff6FAF3A7e52BA697820c5e32D806A8);
    address constant public yycrv = address(0x5dbcF33D8c2E976c6b560249878e6F1491Bca25c);

    address constant public dai = address(0x6B175474E89094C44Da98b954EedeAC495271d0F);
    address constant public ydai = address(0x16de59092dAE5CcF4A1E6439D611fd0653f0Bd01);
    address constant public usdc = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address constant public yusdc = address(0xd6aD7a6750A7593E092a9B218d66C0A814a3436e);
    address constant public usdt = address(0xdAC17F958D2ee523a2206206994597C13D831ec7);
    address constant public yusdt = address(0x83f798e925BcD4017Eb265844FDDAbb448f1707D);
    address constant public tusd = address(0x0000000000085d4780B73119b644AE5ecd22b376);
    address constant public ytusd = address(0x73a052500105205d34Daf004eAb301916DA8190f);

    uint256 constant public DENOMINATOR = 10000;
    uint256 public threshold;
    uint256 public slip;
    uint256 public tank;
    uint256 public p;

    constructor(address _vault) public BaseStrategy(_vault) {
        // minReportDelay = 6300;
        // profitFactor = 100;
        // debtThreshold = 0;
        threshold = 8000;
        slip = 100;
        want.safeApprove(yusdt, uint256(-1));
        IERC20(ydai).safeApprove(ypool, uint256(-1));
        IERC20(yusdc).safeApprove(ypool, uint256(-1));
        IERC20(yusdt).safeApprove(ypool, uint256(-1));
        IERC20(ytusd).safeApprove(ypool, uint256(-1));
        IERC20(ycrv).safeApprove(yycrv, uint256(-1));
        IERC20(ycrv).safeApprove(ypool, uint256(-1));
    }

    function setThreshold(uint256 _threshold) external onlyAuthorized {
        threshold = _threshold;
    }

    function setSlip(uint256 _slip) external onlyAuthorized {
        slip = _slip;
    }

    function name() external override pure returns (string memory) {
        return "StrategyCurveypoolUSDT";
    }

    function estimatedTotalAssets() public override view returns (uint256) {
        return balanceOfWant().add(balanceOfYYCRVinWant());
    }

    function balanceOfWant() public view returns (uint256) {
        return want.balanceOf(address(this));
    }

    function balanceOfYYCRV() public view returns (uint256) {
        return IERC20(yycrv).balanceOf(address(this));
    }

    function balanceOfYYCRVinWant() public view returns (uint256) {
        return balanceOfYYCRV()
                .mul(Vault(yycrv).getPricePerFullShare()).div(1e18)
                .mul(ICurve(ypool).get_virtual_price()).div(1e30);
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        _profit = want.balanceOf(address(this));
        uint256 _p = Vault(yycrv).getPricePerFullShare();
        _p = _p.mul(ICurve(ypool).get_virtual_price()).div(1e18);
        if (_p >= p) {
            _profit = _profit.add((_p.sub(p)).mul(balanceOfYYCRV()).div(1e30));
        }
        else {
            _loss = (p.sub(_p)).mul(balanceOfYYCRV()).div(1e30);
        }
        p = _p;

        if (_debtOutstanding > 0) {
            _debtPayment = liquidatePosition(_debtOutstanding);
        }
    }

    function adjustPosition(uint256 _debtOutstanding) internal override {
        rebalance();
        _deposit();
    }

    function _deposit() internal {
        uint256 _want = (want.balanceOf(address(this))).sub(tank);
        if (_want > 0) {
            Vault(yusdt).deposit(_want);
        }
        uint256 _y = IERC20(yusdt).balanceOf(address(this));
        if (_y > 0) {
            uint256 v = _want.mul(1e30).div(ICurve(ypool).get_virtual_price());
            ICurve(ypool).add_liquidity([0, 0, _y, 0], v.mul(DENOMINATOR.sub(slip)).div(DENOMINATOR));
        }
        uint256 _bal = IERC20(ycrv).balanceOf(address(this));
        if (_bal > 0) {
            Vault(yycrv).deposit(_bal);
        }
    }

    function exitPosition(uint256 _debtOutstanding)
        internal
        override
        returns (uint256 _profit, uint256 _loss, uint256 _debtPayment)
    {
        (_profit, _loss, _debtPayment) = prepareReturn(_debtOutstanding);
        _withdrawAll();
        _debtPayment = want.balanceOf(address(this));
    }

    function _withdrawAll() internal {
        uint256 _yycrv = IERC20(yycrv).balanceOf(address(this));
        if (_yycrv > 0) {
            Vault(yycrv).withdraw(_yycrv);
            _withdrawOne(IERC20(ycrv).balanceOf(address(this)));
        }
    }

    function _withdrawOne(uint256 _amnt) internal returns (uint256) {
        uint256 _aux = _amnt.mul(DENOMINATOR.sub(slip)).div(DENOMINATOR);
        uint256 _t = IERC20(ycrv).totalSupply();
        ICurve(ypool).remove_liquidity(_amnt, [
            ICurve(ypool).balances(0).mul(_aux).div(_t), 
            ICurve(ypool).balances(1).mul(_aux).div(_t), 
            ICurve(ypool).balances(2).mul(_aux).div(_t), 
            ICurve(ypool).balances(3).mul(_aux).div(_t)]);

        uint256 _ydai = IERC20(ydai).balanceOf(address(this));
        uint256 _yusdc = IERC20(yusdc).balanceOf(address(this));
        uint256 _ytusd = IERC20(ytusd).balanceOf(address(this));

        uint256 tmp;
        if (_ydai > 0) {
            tmp = ICurve(ypool).get_dy(0, 2, _ydai);
            ICurve(ypool).exchange(0, 2, _ydai, tmp.mul(DENOMINATOR.sub(slip)).div(DENOMINATOR));
        }
        if (_yusdc > 0) {
            tmp = ICurve(ypool).get_dy(1, 2, _yusdc);
            ICurve(ypool).exchange(1, 2, _yusdc, tmp.mul(DENOMINATOR.sub(slip)).div(DENOMINATOR));
        }
        if (_ytusd > 0) {
            tmp = ICurve(ypool).get_dy(3, 2, _ytusd);
            ICurve(ypool).exchange(3, 2, _ytusd, tmp.mul(DENOMINATOR.sub(slip)).div(DENOMINATOR));
        }

        uint256 _before = want.balanceOf(address(this));
        Vault(yusdt).withdraw(IERC20(yusdt).balanceOf(address(this)));
        uint256 _after = want.balanceOf(address(this));

        return _after.sub(_before);
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _amountFreed)
    {
        uint256 _balance = want.balanceOf(address(this));
        if (_balance < _amountNeeded) {
            _amountFreed = _withdrawSome(_amountNeeded.sub(_balance));
            _amountFreed = _amountFreed.add(_balance);
            tank = 0;
        }
        else {
            _amountFreed = _amountNeeded;
            if (tank >= _amountNeeded) tank = tank.sub(_amountNeeded);
            else tank = 0;
        }
    }

    function _withdrawSome(uint256 _amount) internal returns (uint256) {
        uint256 _amnt = _amount.mul(1e30).div(ICurve(ypool).get_virtual_price());
        uint256 _amt = _amnt.mul(1e18).div(Vault(yycrv).getPricePerFullShare());
        uint256 _before = IERC20(ycrv).balanceOf(address(this));
        Vault(yycrv).withdraw(_amt);
        uint256 _after = IERC20(ycrv).balanceOf(address(this));
        return _withdrawOne(_after.sub(_before));
    }

    // NOTE: Can override `tendTrigger` and `harvestTrigger` if necessary
    function tendTrigger(uint256 callCost) public override view returns (bool) {
        (uint256 _t, uint256 _c) = tick();
        return (_c > _t);
    }

    function prepareMigration(address _newStrategy) internal override {
        IERC20(yycrv).safeTransfer(_newStrategy, IERC20(yycrv).balanceOf(address(this)));
        IERC20(ycrv).safeTransfer(_newStrategy, IERC20(ycrv).balanceOf(address(this)));
    }

    function protectedTokens()
        internal
        override
        view
        returns (address[] memory)
    {
        address[] memory protected = new address[](2);
        protected[0] = ycrv;
        protected[1] = yycrv;
        return protected;
    }

    function tick() public view returns (uint256 _t, uint256 _c) {
        _t = ICurve(ypool).balances(2)
                .mul(Vault(yusdt).getPricePerFullShare()).div(1e18)
                .mul(threshold).div(DENOMINATOR);
        _c = balanceOfYYCRVinWant();
    }

    function rebalance() public {
        (uint256 _t, uint256 _c) = tick();
        if (_c > _t) {
            _withdrawSome(_c.sub(_t));
            tank = want.balanceOf(address(this));
        }
    }

    function forceD(uint256 _amount) external onlyAuthorized {
        Vault(yusdt).deposit(_amount);
        uint256 _y = IERC20(yusdt).balanceOf(address(this));
        uint256 v = _amount.mul(1e30).div(ICurve(ypool).get_virtual_price());
        ICurve(ypool).add_liquidity([0, 0, _y, 0], v.mul(DENOMINATOR.sub(slip)).div(DENOMINATOR));

        uint256 _bal = IERC20(ycrv).balanceOf(address(this));
        Vault(yycrv).deposit(_bal);

        if (_amount < tank) tank = tank.sub(_amount);
        else tank = 0;
    }

    function forceW(uint256 _amt) external onlyAuthorized {
        uint256 _before = IERC20(ycrv).balanceOf(address(this));
        Vault(yycrv).withdraw(_amt);
        uint256 _after = IERC20(ycrv).balanceOf(address(this));
        _amt = _after.sub(_before);

        _before = want.balanceOf(address(this));
        _withdrawOne(_amt);
        _after = want.balanceOf(address(this));
        tank = tank.add(_after.sub(_before));
    }
}
