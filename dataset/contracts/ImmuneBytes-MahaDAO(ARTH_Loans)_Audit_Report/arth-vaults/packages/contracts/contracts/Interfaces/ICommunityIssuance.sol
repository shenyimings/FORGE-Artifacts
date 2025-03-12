// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface ICommunityIssuance {
    // --- Events ---

    event LQTYTokenAddressSet(address _lqtyTokenAddress);
    event StabilityPoolAddressSet(address _stabilityPoolAddress);
    event TotalLQTYIssuedUpdated(uint256 _totalLQTYIssued);

    // --- Functions ---

    function setAddresses(address _lqtyTokenAddress, address _stabilityPoolAddress) external;

    function issueLQTY() external returns (uint256);

    function sendLQTY(address _account, uint256 _LQTYamount) external;
}
