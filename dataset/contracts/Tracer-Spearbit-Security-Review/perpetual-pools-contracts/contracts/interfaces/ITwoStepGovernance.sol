//SPDX-License-Identifier: CC-BY-NC-ND-4.0
pragma solidity 0.8.7;

interface ITwoStepGovernance {
    /**
     * @notice Represents proposed change in governance address
     * @param newAddress Proposed address
     */
    event ProvisionalGovernanceChanged(address indexed newAddress);

    /**
     * @notice Represents change in governance address
     * @param oldAddress Previous address
     * @param newAddress Address after change
     */
    event GovernanceAddressChanged(address indexed oldAddress, address indexed newAddress);

    function governance() external returns (address);

    function provisionalGovernance() external returns (address);

    function governanceTransferInProgress() external returns (bool);

    function transferGovernance(address _governance) external;

    function claimGovernance() external;
}
