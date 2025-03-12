// SPDX-License-Identifier: BUSL-1.1
pragma solidity ^0.8.0;

import { EnumerableSetUpgradeable } from "@openzeppelin/contracts-upgradeable/utils/structs/EnumerableSetUpgradeable.sol";

struct PerformanceFeeSuggestion {
    address affiliateAddress;
    uint256 tokenAmountToMint;
}

interface IFee {
    event PerformanceFeeApproved(
        uint256 newSeqNum,
        PerformanceFeeSuggestion[] performanceFeeSuggestion
    );

    error IncorrectSeqNum(uint256 expectedSeqNum);
    error UnauthorizedPerformanceFeeSuggester();
    error UnauthorizedAffiliateAddress();

    function suggestPerformanceFees(
        PerformanceFeeSuggestion[] calldata performanceFeeSuggestions,
        uint256 seqNum
    ) external;

    function getSuggestedPerformanceFee()
        external
        view
        returns (PerformanceFeeSuggestion[] memory performanceFeeSuggestions);

    function approvePerformanceFees() external;

    function setFeeSuggester(address newFeeSuggester) external;

    function getFeeSuggester() external view returns (address feeSuggester);

    function addAddressesToFeeWhitelist(address[] calldata addressesToAdd)
        external;

    function removeAddressesFromFeeWhitelist(
        address[] calldata addressesToRemove
    ) external;

    function getAddressesInFeeWhitelist()
        external
        view
        returns (address[] memory feeWhiteListToReturn);

    function getSeqNum() external view returns (uint256);
}
