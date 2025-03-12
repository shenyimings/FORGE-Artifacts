// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IMarginTracker {
    /*=== event ===*/

    event NewCollateral(address _token);
    event RemoveCollateral(address _token);
    event MarginTransferred(address indexed account, address token, int delta);
    event DeficitLoss(address account, uint deficitLoss, uint insuranceOut, uint lpOut);
    event Liquidated(
        address account,
        address token,
        uint liquidateAmount,
        uint repayAmount,
        uint penaltyToLp,
        uint penaltyToTreasury,
        uint deficitLoss
    );
    event DebtUpdated(int accDebt);
    event UserDebtUpdated(address account, int accDebt);

    /*=== function ===*/

    function baseToken() external view returns (address);

    function userCollaterals(address _account, address _token) external view returns (int);

    function freezed(address _account) external view returns (int);

    function accountMargin(address _account) external view returns (int baseMargin, int otherMargin);

    function liquidate(address _account, address _token, uint _maxAmount) external payable;

    function nextDebt() external view returns (int nextAccDebt, int nextUnsettledInterest);

    function modifyMargin(address _account, address _token, int _delta) external;

    function withdrawMargin(address _account, address _token, int _amount) external;

    function freeze(address _account, int _value) external;

    function transferByMarket(address _from, address _to, address _token, int _amount) external;

    function unfreeze(address _account, int _value, address _receiver) external;

    function totalDebt() external view returns (int);

    function updateDebt(int _lpNetValue, int _netSkew) external;

    function coverDeficitLoss(address _account) external;
}
