// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "./IValidatorOperator.sol";


interface INodeOperatorRegistry {
    /// @notice node operator full data structure
    /// @param operatorAddress validator operator address
    /// @param commissionRate validator commission rate
    /// @param delegateAddress validator delegation address
    /// @param rewardAddress validator reward address
    /// @param delegation delegation
    /// @param status validator status
    struct FullNodeOperatorRegistry {
        address operatorAddress;
        uint256 commissionRate;
        address delegateAddress;
        address rewardAddress;
        bool delegation;
        IValidatorOperator.NodeOperatorRegistryStatus status;
    }

    /// @notice node operator data structure
    /// @param operatorAddress validator operator address
    /// @param delegateAddress validator delegation address
    /// @param rewardAddress validator reward address
    struct ValidatorData {
        address operatorAddress;
        address delegateAddress;
        address rewardAddress;
    }

    /// @notice dao address. 
    function dao() external view returns (address);

    /// @notice add new node operator
    /// @param operatorAddress validator operator address
    function addNodeOperator(address operatorAddress) external;

    /// @notice quit node operator registry
    function exitNodeOperatorRegistry() external;

    /// @notice remove a node operator and update state, let oracle take all delegated tokens
    /// @param operatorAddress validator operator address
    function removeNodeOperator(address operatorAddress) external;

    /// @notice if node operator is invalid, then remove
    /// @param operatorAddress validator operator address
    function removeInvalidNodeOperator(address operatorAddress) external;

    /// @notice update node operator reward address
    /// @param newRewardAddress new reward address
    function setRewardAddress(address newRewardAddress) external;

    /// @notice set new version
    /// @param _newVersion new version
    function setVersion(string memory _newVersion) external;

    /// @notice list can delegated operators
    /// @return activeNodeOperators node operator list
    function listDelegatedNodeOperators()
        external
        view
        returns (ValidatorData[] memory);

    /// @notice list all can withdraw operators
    /// @return nodeOperators node operator list
    function listWithdrawNodeOperators()
        external
        view
        returns (ValidatorData[] memory);

    /// @notice calculate total delegation distribute between active validators, 
    /// @return validators all active node operators
    /// @return stakePerOperator stake amount per operator
    /// @return operatorRatios ratio per operator
    /// @return totalRatio total ratio
    /// @return totalStaked total staked amount
    function getValidatorsDelegationAmount()
        external
        view
        returns (
            ValidatorData[] memory validators,
            uint256[] memory stakePerOperator,
            uint256[] memory operatorRatios,
            uint256 totalRatio,
            uint256 totalStaked
        );

    /// @notice return a node operator by operator address
    /// @param operatorAddress validator operator address
    /// @return nodeOperator a node operator
    function getNodeOperatorByOperatorAddress(address operatorAddress)
        external
        view
        returns (FullNodeOperatorRegistry memory nodeOperator);

    /// @notice return a node operator by reward address
    /// @param rewardAddress reward address
    /// @return nodeOperator a node operator
    function getNodeOperatorByRewardAddress(address rewardAddress)
        external
        view
        returns (FullNodeOperatorRegistry memory nodeOperator);

    /// @notice return node operator status
    /// @param  operatorAddress node operator address
    /// @return operatorStatus return node operator status
    function getNodeOperatorStatus(address operatorAddress)
        external
        view
        returns (IValidatorOperator.NodeOperatorRegistryStatus operatorStatus);

    /// @notice return all operatorAddress list
    function getOperatorAddresses() external view returns (address[] memory);

    /// @notice calculate validators if can withdraw
    /// @param _withdrawAmount can withdrawed amount
    /// @return validators all validators
    /// @return totalDelegated total delegated amount
    /// @return bigNodeOperatorAddresses TODO Addresses of node operators with delegation above average 
    /// @return smallNodeOperatorAddresses TODO Addresses of node operators with delegation below average
    /// @return operatorAmountCanBeRequested TODO Amount that can be requested from specific validator if system imbalanced
    /// @return totalValidatorToWithdrawFrom when balance, amount can withdraw validator
    /// @return minStakeAmount when balance, validator smallest stake amount
    function getValidatorsRequestWithdraw(uint256 _withdrawAmount)
        external
        view
        returns (
            ValidatorData[] memory validators,
            uint256 totalDelegated,
            address[] memory bigNodeOperatorAddresses,
            address[] memory smallNodeOperatorAddresses,
            uint256[] memory operatorAmountCanBeRequested,
            uint256 totalValidatorToWithdrawFrom,
            uint256 minStakeAmount
        );

    /// @notice get update version
    function getUpdateVersion() external pure returns(string memory);

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                    EVENTS                          ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @notice add Node Operator event
    /// @param operatorAddress validator operator address.
    /// @param delegateAddress delegate address.
    /// @param rewardAddress reward address.
    event AddNodeOperator(address operatorAddress, address delegateAddress, address rewardAddress);

    /// @notice remove Node Operator event
    /// @param operatorAddress validator operator address.
    /// @param delegateAddress delegate address.
    /// @param rewardAddress reward address.
    event RemoveNodeOperator(address operatorAddress, address delegateAddress, address rewardAddress);

    /// @notice remove Invalid Node Operator event
    /// @param operatorAddress validator operator address.
    /// @param delegateAddress delegate address.
    /// @param rewardAddress reward address.
    event RemoveInvalidNodeOperator(address operatorAddress, address delegateAddress, address rewardAddress);

    /// @notice set reward address event
    /// @param operatorAddress validator operator address.
    /// @param oldRewardAddress old reward address.
    /// @param newRewardAddress new reward address.
    event SetRewardAddress(
        address operatorAddress,
        address oldRewardAddress,
        address newRewardAddress
    );

    /// @notice set new version event
    /// @param oldVersion old version.
    /// @param newVersion new version.
    event SetVersion(string oldVersion, string newVersion);

    /// @notice when node operator quit registry emit
    /// @param operatorAddress node operator address
    /// @param delegateAddress node operator delegate address
    /// @param rewardAddress node operator reward address
    event ExitNodeOperator(address operatorAddress, address delegateAddress, address rewardAddress);

}