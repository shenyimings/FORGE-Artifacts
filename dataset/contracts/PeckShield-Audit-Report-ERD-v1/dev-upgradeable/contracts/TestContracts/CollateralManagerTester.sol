// SPDX-License-Identifier: MIT
pragma solidity 0.8.18;

import "../CollateralManager.sol";

/* Tester contract inherits from TroveManager, and provides external functions 
for testing the parent's internal functions. */

contract CollateralManagerTester is CollateralManager {
    using SafeMathUpgradeable for uint256;
    function computeICR(
        address[] memory _tokens,
        uint256[] memory _amounts,
        uint256 _debt
    ) external view returns (uint256) {
        (uint256 totalValue, ) = getValue(
            _tokens,
            _amounts
        );
        return ERDMath._computeCR(totalValue, _debt);
    }

    function getCompositeDebt(uint256 _debt) external view returns (uint256) {
        return _getCompositeDebt(_debt, EUSD_GAS_COMPENSATION);
    }


    function getActualDebtFromComposite(
        uint256 _debtVal
    ) external view returns (uint256) {
        return _getNetDebt(_debtVal, EUSD_GAS_COMPENSATION);
    }

    // Return the amount of collateral to be drawn from a trove's collateral and sent as gas compensation.
    function getCollGasCompensation(
        uint256[] memory _entireColl
    ) external pure returns (uint256[] memory) {
        return _getCollGasCompensation(_entireColl);
    }

    function getNewICRFromTroveChange(
        uint256 _newVC,
        uint256 _debt,
        uint256 _debtChange,
        bool _isDebtIncrease
    ) external pure returns (uint256) {
        uint256 newDebt = _isDebtIncrease
            ? _debt.add(_debtChange)
            : _debt.sub(_debtChange);
        return ERDMath._computeCR(_newVC, newDebt);
    }

    function checkRecoveryMode() external view returns (bool) {
        return troveManager.checkRecoveryMode(priceFeed.fetchPrice_view());
    }

    function getCurrentICR(address _borrower) external view returns (uint256) {
        return troveManager.getCurrentICR(_borrower, priceFeed.fetchPrice_view());
    }

    function getTCR() external view returns (uint256) {
        uint256 price = priceFeed.fetchPrice_view();
        return troveManager.getTCR(price);
    }
}
