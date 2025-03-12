// SPDX-License-Identifier: MIT
pragma solidity 0.8.20;

interface IMarketConfig {
    function burnFee() external view returns (uint256);

    function config()
        external
        view
        returns (uint256, uint256, uint256, uint256, uint256, uint256, uint256);

    function fees() external view returns (uint256, uint256, uint256, uint256);

    function periods() external view returns (uint256, uint256);

    function disputePeriod() external view returns (uint256);

    function disputePrice() external view returns (uint256);

    function feesSum() external view returns (uint256);

    function foundationFee() external view returns (uint256);

    function marketCreatorFee() external view returns (uint256);

    function verificationFee() external view returns (uint256);

    function verificationPeriod() external view returns (uint256);
}
