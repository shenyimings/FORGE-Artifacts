// SPDX-License-Identifier: MIT

pragma solidity 0.6.11;

interface ICommunityIssuance {

    // --- Events ---

    event LQTYTokenAddressSet(address _lqtyTokenAddress);
    event StabilityPoolAddressSet(address _stabilityPoolAddress);
    event TotalLQTYIssuedUpdated(uint _totalLQTYIssued);

    // --- Functions ---

    function setPaused(bool _isPaused) external;

    function shutdownAdmin() external view returns (address);

    function LQTYSupplyCap() external view returns (uint);

    function setAddresses(address _lqtyTokenAddress, address _stabilityPoolAddress, address _lqtyTreasuryAddress, address _shutdownAdminAddress) external;

    function issueLQTY() external returns (uint);

    function sendLQTY(address _account, uint _LQTYamount) external;
}
