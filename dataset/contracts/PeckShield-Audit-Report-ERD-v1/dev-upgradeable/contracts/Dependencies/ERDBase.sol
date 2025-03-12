// SPDX-License-Identifier: MIT

pragma solidity 0.8.18;

import "./BaseMath.sol";
import "./ERDMath.sol";
import "../Interfaces/IActivePool.sol";
import "../Interfaces/ICollateralManager.sol";
import "../Interfaces/IDefaultPool.sol";
import "../Interfaces/IEUSDToken.sol";
import "../Interfaces/IPriceFeed.sol";
import "../Interfaces/ITroveDebt.sol";
import "../Interfaces/IERDBase.sol";

/*
 * Base contract for TroveManager, BorrowerOperations and StabilityPool. Contains global system constants and
 * common functions.
 */
contract ERDBase is BaseMath, IERDBase {
    using SafeMathUpgradeable for uint256;

    uint256 public constant _100pct = 1000000000000000000; // 1e18 == 100%

    // uint constant public MIN_NET_DEBT = 0;

    uint256 public constant PERCENT_DIVISOR = 200; // dividing by 200 yields 0.5%

    IActivePool public activePool;
    ICollateralManager public collateralManager;

    IDefaultPool public defaultPool;
    IEUSDToken public eusdToken;
    ITroveDebt public troveDebt;

    IPriceFeed public override priceFeed;

    address public gasPoolAddress;

    // --- Gas compensation functions ---

    // Returns the composite debt (drawn debt + gas compensation) of a trove, for the purpose of ICR calculation
    function _getCompositeDebt(
        uint256 _debt,
        uint256 _gas
    ) internal pure returns (uint256) {
        return _debt.add(_gas);
    }

    function _getNetDebt(
        uint256 _debt,
        uint256 _gas
    ) internal pure returns (uint256) {
        return _debt.sub(_gas);
    }

    // Return the amount of collateral to be drawn from a trove's collateral and sent as gas compensation.
    function _getCollGasCompensation(
        uint256[] memory _entireColl
    ) internal pure returns (uint256[] memory) {
        uint256 collLen = _entireColl.length;
        uint256[] memory collGas = new uint256[](collLen);
        for (uint256 i = 0; i < collLen; ) {
            collGas[i] = _entireColl[i] / PERCENT_DIVISOR;
            unchecked {
                i++;
            }
        }
        return collGas;
    }

    // function getEntireSystemColl()
    //     public
    //     view
    //     returns (address[] memory, uint256[] memory, uint256)
    // {
    //     return collateralManager.getEntireCollValue();
    // }

    function getEntireSystemColl()
        public
        view
        returns (address[] memory, uint256[] memory)
    {
        (
            ,
            address[] memory collaterals,
            uint256[] memory activeColls
        ) = activePool.getTotalCollateral();
        (, , uint256[] memory liquidatedColls) = defaultPool
            .getTotalCollateral();

        return (
            collaterals,
            ERDMath._addArray(activeColls, liquidatedColls)
        );
    }

    function getEntireSystemColl(uint256 _price)
        public
        view
        returns (address[] memory, uint256[] memory, uint256)
    {
        return collateralManager.getEntireCollValue(_price);
    }

    function getEntireSystemDebt()
        public
        view
        returns (uint256 entireSystemDebt)
    {
        uint activeDebt = troveDebt.totalSupply();
        uint closedDebt = defaultPool.getEUSDDebt();
        uint gasEUSD = eusdToken.balanceOf(gasPoolAddress);
        return activeDebt.add(closedDebt).add(gasEUSD);
    }

    function _getTCR(
        uint256 collValue,
        uint256 debt
    ) internal pure returns (uint256 TCR) {
        TCR = ERDMath._computeCR(collValue, debt);

        return TCR;
    }

    function _getTCR(uint256 collValue) internal view returns (uint256 TCR) {
        TCR = ERDMath._computeCR(collValue, getEntireSystemDebt());

        return TCR;
    }

    function _checkRecoveryMode(
        uint256 _value,
        uint256 _debt,
        uint256 _ccr
    ) internal pure returns (bool) {
        uint256 TCR = _getTCR(_value, _debt);

        return TCR < _ccr;
    }

    function _requireUserAcceptsFee(
        uint256 _fee,
        uint256 _amount,
        uint256 _maxFeePercentage
    ) internal pure {
        uint256 feePercentage = _fee.mul(DECIMAL_PRECISION).div(_amount);
        require(
            feePercentage <= _maxFeePercentage,
            "Fee exceeded provided maximum"
        );
    }
}
