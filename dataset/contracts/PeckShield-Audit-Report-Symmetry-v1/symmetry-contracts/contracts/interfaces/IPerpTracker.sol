// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.0;

interface IPerpTracker {
    /*=== struct ===*/

    struct LpPosition {
        int longSize; // long position hold by lp in underlying, positive, 18 decimals
        int shortSize; // short position hold by lp in underlying, negative, 18 decimals
        int avgPrice; // average price for the lp net position (long + short)
        int accFunding; // accumulate funding fee for unit position size at the time of latest open/close position or lp in/out
        int accLongFinancingFee; // accumulate long financing fee for unit position size at the latest position modification
        int accShortFinancingFee; // accumulate short financing fee for unit position size at the latest position modification
        int unsettled; // pnl and fee that realized but not settled yet
    }

    struct Position {
        int size; // position size, positive for long, negative for short, 18 decimals
        int accFunding; // accumulate funding fee for unit position size at the latest position modification
        int accFinancingFee; // accumulate financing fee for unit position size at the latest position modification
        int avgPrice;
    }

    struct FeeInfo {
        int accFunding; // the latest accumulate funding fee for unit position size
        int fundingRate; // the latest funding rate
        int accLongFinancingFee; // the latest long financing fee
        int accShortFinancingFee; // the latest short financing fee
        int updateTime; // the latest fee update time
    }

    struct TokenInfo {
        int lpNetValue; // latest lp net value when any position of the token is updated
        int netOpenInterest; // latest net open interest when any position of the token is updated
        int skew; // latest token skew(in USD) when any position of the token is updated
    }

    struct PriceInfo {
        int longByMidPrice; // p_{long} / p_{mid} in latest trade, should be always >= 1
        int shortByMidPrice; // p_{short} / p_{mid} in latest trade, should be always between (0, 1]
        uint updateTime; // the latest trade timestamp
    }

    struct SwapParams {
        address token;
        int skew;
        int size;
        int oraclePrice;
        int lpNetValue;
    }

    /*=== event ===*/

    event NewMarket(address token);
    event RemoveMarket(address token);
    event TokenInfoUpdated(address indexed token, int lpNetValue, int netOpenInterest, int skew);
    event FeeInfoUpdated(
        address indexed token,
        int nextFundingRate,
        int nextLongFinancingRate,
        int nextShortFinancingRate,
        int nextAccFundingFee,
        int nextAccLongFinancingFee,
        int nextAccShortFinancingFee
    );
    event PositionUpdated(
        address indexed account,
        address indexed token,
        int size,
        int avgPrice,
        int accFunding,
        int accFinancingFee
    );

    /*=== function ===*/

    function accountStatus(
        address _account
    ) external view returns (int mtm, int pnlOracle, int pnlMid, int positionNotional);

    function swapOnAMM(SwapParams memory _params) external returns (int avgPrice);

    function currentSkew(address _token) external view returns (int);

    function getFeeInfo(address _token) external view returns (FeeInfo memory);

    function getLpPosition(address _token) external view returns (LpPosition memory);

    function getMarketTokens() external view returns (address[] memory);

    function getNetPositionSize(address _token) external view returns (int, int);

    function getPosition(address _account, address _token) external view returns (Position memory);

    function getPositionSize(address _account, address _token) external view returns (int);

    function getPriceInfo(address _token) external view returns (PriceInfo memory);

    function getTokenInfo(address _token) external view returns (TokenInfo memory);

    function latestUpdated(address _token) external view returns (uint);

    function lpHardLimit(int _lp) external view returns (int);

    function lpLimitForToken(int _lp, address _token) external view returns (int);

    function lpPositions(
        address
    )
        external
        view
        returns (
            int longSize,
            int shortSize,
            int avgPrice,
            int accFunding,
            int accLongFinancingFee,
            int accShortFinancingFee,
            int unsettled
        );

    function lpSoftLimit(int _lp) external view returns (int);

    function lpStatus() external view returns (int pnl, int netOpenInterest, int netSkew);

    function market() external view returns (address);

    function domainKey(address _token) external pure returns (bytes32);

    function marketTokensLength() external view returns (uint);

    function marketTokensList(uint) external view returns (address);

    function marketTokensListed(address) external view returns (bool);

    function nextAccFinancingFee(address _token, int _price) external view returns (int, int, int, int);

    function nextAccFunding(address _token, int _price) external view returns (int, int);

    function removeMarketToken(address _token) external;

    function settings() external view returns (address);

    function settleTradeForLp(address _token, int _execPrice, int _oldSize, int _newSize, int _settled) external;

    function settleTradeForUser(
        address _account,
        address _token,
        int _sizeDelta,
        int _execPrice
    ) external returns (int, int, int);

    function updateFee(address _token, int _price) external;

    function updateTokenInfo(address _token, TokenInfo memory _tokenInfo) external;
}
