// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

import "../../node_modules/@openzeppelin/contracts/token/ERC20/ERC20.sol";

interface TaxTokenInterface is IERC20 {
    function mintToken(
        address,
        uint256,
        address
    ) external;

    function registerWhitelist(address, address) external;

    function unregisterWhitelist(address) external;

    function updateLendingAddress(address) external;

    function updateIncentiveAddresses(address[] memory, uint256[] memory) external;

    function updateGovernanceAddress(address) external;

    function mintDeveloperFund() external;

    function mintIncentiveFund() external;

    function getGovernanceAddress() external view returns (address);

    function getDeveloperAddress() external view returns (address);

    function getLendingAddress() external view returns (address);

    function getFunds() external view returns (uint256 developerFund, uint256 incentiveFund);

    function getConfigs()
        external
        view
        returns (
            uint256 maxTotalSupply,
            uint256 halvingStartLendValue,
            uint256 halvingDecayRateE8,
            uint256 developerFundRateE8,
            uint256 incentiveFundRateE8
        );

    function getIncentiveFundAddresses()
        external
        view
        returns (
            address[] memory incentiveFundAddresses,
            uint256[] memory incentiveFundAllocationE8
        );

    function getMintUnit() external view returns (uint256);

    function getOracleAddress(address) external view returns (address);

    function name() external view returns (string memory);

    function symbol() external view returns (string memory);

    function decimals() external view returns (uint8);
}
