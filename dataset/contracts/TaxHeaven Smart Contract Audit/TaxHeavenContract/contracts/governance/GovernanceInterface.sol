// SPDX-License-Identifier: UNLICENSED
pragma solidity 0.7.1;

interface GovernanceInterface {
    function proposeUpdateCoreParameters(
        uint32 preVoteLength,
        uint32 totalVoteLength,
        uint32 expirationLength,
        uint16 minVoteE4,
        uint16 minVoteCoreE4,
        uint16 minCommitE4
    ) external;

    function proposeUpdateWhitelist(address tokenAddress, address oracleAddress) external;

    function proposeDelistWhitelist(address tokenAddress) external;

    function proposeUpdateIncentiveFund(
        address[] memory incentiveAddresses,
        uint256[] memory incentiveAllocation
    ) external;

    function vote(
        bytes32 proposeId,
        bool approval,
        uint128 amount
    ) external;

    function lockinProposal(bytes32 proposeId) external;

    function applyGovernanceForUpdateCore(bytes32 proposeId) external;

    function applyGovernanceForUpdateWhitelist(bytes32 proposeId) external;

    function applyGovernanceForDelistWhitelist(bytes32 proposeId) external;

    function applyGovernanceForUpdateIncentive(bytes32 proposeId) external;

    function withdraw(bytes32 proposeId) external;

    function getTaxTokenAddress() external view returns (address);

    function getCoreParameters()
        external
        view
        returns (
            uint32 preVoteLength,
            uint32 totalVoteLength,
            uint32 expirationLength,
            uint16 minimumVoteE4,
            uint16 minimumVoteCoreE4,
            uint16 minimumCommitE4
        );

    function getUserStatus(bytes32 proposeId, address userAddress)
        external
        view
        returns (uint128 approvalAmount, uint128 denialAmount);

    function getStatus(bytes32 proposeId)
        external
        view
        returns (
            uint128 currentApprovalVoteSum,
            uint128 currentDenialVoteSum,
            uint128 appliedMinimumVote,
            uint32 preVoteDeadline,
            uint32 mainVoteDeadline,
            uint32 expiration,
            bool lockin,
            bool applied
        );

    function getProposals(uint256 offset, uint256 limit)
        external
        view
        returns (bytes32[] memory allProposals);

    function getInfoUpdateCoreParameters(bytes32)
        external
        view
        returns (
            uint64 preVoteLength,
            uint64 totalVoteLength,
            uint64 expirationLength,
            uint16 minVoteE4,
            uint16 minVoteCoreE4,
            uint16 minCommitE4
        );

    function getInfoUpdateWhitelist(bytes32 proposeId)
        external
        view
        returns (address tokenAddress, address oracleAddress);

    function getInfoDelistWhitelist(bytes32 proposeId) external view returns (address tokenAddress);

    function getInfoUpdateIncentive(bytes32 proposeId)
        external
        view
        returns (address[] memory incentiveAddresses, uint256[] memory incentiveAllocation);
}
