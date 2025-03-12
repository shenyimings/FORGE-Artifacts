// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

interface IAutomaticBuyback {
    function initialize(address _pancakeRouterAddress, address _cumulatedTokenAddress, address _buybackTokenAddress) external;
    function trigger() external returns (bool buyback_executed);
    function changeBuybackPeriod(uint256 newPeriod) external;
    function updateRouterAddress(address newAddress) external;
    function changeCumulatedToken(address newCumulatedTokenAddress) external;
    function getAutomaticBuybackStatus() external view returns (
            address automatic_buyback_contract_address,
            uint256 next_buyback_timestamp,
            uint256 next_buyback_countdown,
            uint256 current_buyback_period,
            uint256 new_buyback_period,
            address current_cumulated_token,
            uint256 current_cumulated_balance,
            uint256 current_buyback_token_balance,
            uint256 total_buyed_back );
    event Initialized(address indexed _token, address cumulatedToken, address buybackToken, address pancakeRouter);
    event UpdatePancakeRouter(address new_router, address old_router);
    event ChangedBuybackPeriod(uint256 old_period, uint256 new_period, bool immediate);
    event NewBuybackTimestampSet(uint256 period, uint256 buyback_timestamp);
    event BuybackExecuted(uint amount_cumulatedToken, uint256 amount_buybackToken, uint256 buybackToken_current_balance, uint256 total_buyed_back_alltime);
    event ChangedAutomaticBuybackCumulatedToken(address old_cumulatedToken, address new_cumulatedToken);
}