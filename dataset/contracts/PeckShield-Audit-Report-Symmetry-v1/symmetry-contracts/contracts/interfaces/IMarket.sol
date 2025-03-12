// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IMarket {
    /*=== event ===*/

    event Traded(
        address indexed account,
        address indexed token,
        int sizeDelta,
        int fillPrice,
        uint fee,
        uint couponUsed,
        uint orderId
    );
    event Settled(address indexed account, address indexed token, int price, int settled); // settled in baseToken
    event SetPerpTracker(address perpTracker);
    event SetFeeTracker(address feeTracker);
    event SetVolumeTracker(address volumeTracker);
    event SetMarginTracker(address marginTracker);
    event SetCoupon(address coupon);
    event SetOperator(address operator, bool isOperator);

    /*=== struct ===*/

    struct TradeParams {
        address account;
        address token;
        int sizeDelta;
        int execPrice;
        uint fee;
        uint couponUsed;
        uint orderId;
    }

    /*=== function ==*/

    function accountMarginStatus(
        address _account
    ) external view returns (int mtm, int currentMargin, int availableMargin, int positionNotional);

    function allocateIncentives(address _account, int _amount) external;

    function baseToken() external view returns (address);

    function baseTokenToUsd(int _amount, bool _useMax) external view returns (int);

    function tradeSwap(address _account, address _token, int _size, uint _orderTime) external returns (int, uint, uint);

    function liquidationSwap(address _account, address _token) external returns (int, int, int, uint, uint);

    function coverDeficitLoss(int _loss) external returns (uint insuranceOut, uint lpOut);

    function deductFeeToAccount(address _account, uint _fee, address _receiver) external returns (uint amount);

    function deductFeeToLiquidity(address _account, int _amount) external;

    function deductPenaltyToInsurance(address _account, uint _fee) external returns (uint amount);

    function feeTracker() external view returns (address);

    function marginTracker() external view returns (address);

    function globalStatus() external view returns (int lpNetValue, int netOpenInterest, int netSkew);

    function insuranceBalance() external view returns (uint);

    function deductKeeperFee(address _account, int _amount) external;

    function sendKeeperFee(address _account, int _amount, address _receiver) external;

    function perpTracker() external view returns (address);

    function priceOracle() external view returns (address);

    function redeemSwap(int _lp, int _redeemValue) external returns (uint fee);

    function sendToLp(int _amount) external;

    function settings() external view returns (address);

    function settle(address _account, address[] memory _tokens) external returns (int settled);

    function tokenToUsd(address _token, int _amount) external view returns (int);

    function trade(TradeParams memory _params) external;

    function transferLiquidityIn(address _account, uint _amount) external;

    function transferLiquidityOut(address _account, uint _amount) external;

    function transferMarginIn(address _sender, address _receiver, address _token, uint _amount) external payable;

    function transferMarginOut(address _sender, address _receiver, address _token, uint _amount) external;

    function treasury() external returns (address);

    function updateDebt() external;

    function updateFee(address _token) external;

    function updateInfoWithPrice(address _token, bytes[] calldata _priceUpdateData) external payable;

    function updateTokenInfoAndDebt(address _token) external returns (int, int);

    function usdToBaseToken(int _amount, bool _useMax) external view returns (int);

    function usdToToken(address _token, int _amount) external view returns (int);

    function volumeTracker() external view returns (address);

    function wETH() external view returns (address);
}
