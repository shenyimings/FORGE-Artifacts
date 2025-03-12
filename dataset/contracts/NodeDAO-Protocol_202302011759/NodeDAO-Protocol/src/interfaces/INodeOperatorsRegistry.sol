// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.7;

/**
 * @title Node Operator registry
 *
 * Registration and management of Node Operator
 */
interface INodeOperatorsRegistry {
    /**
     * @notice Add node operator named `name` with reward address `rewardAddress` and staking limit = 0 validators
     * @param _name Human-readable name
     * @param _rewardAddress Ethereum 1 address which receives ETH rewards for this operator
     * @param _controllerAddress Ethereum 1 address for the operator's management authority
     * @return id a unique key of the added operator
     */
    function registerOperator(string memory _name, address _rewardAddress, address _controllerAddress)
        external
        payable
        returns (uint256 id);

    /**
     * @notice Set an operator as trusted
     * @param _id operator id
     */
    function setTrustedOperator(uint256 _id) external;

    /**
     * @notice Remove an operator as trusted
     * @param _id operator id
     */
    function removeTrustedOperator(uint256 _id) external;

    /**
     * @notice Set the name of the operator
     * @param _id operator id
     * @param _name operator new name
     */
    function setNodeOperatorName(uint256 _id, string memory _name) external;

    /**
     * @notice Set the rewardAddress of the operator
     * @param _id operator id
     * @param _rewardAddress Ethereum 1 address which receives ETH rewards for this operator
     */
    function setNodeOperatorRewardAddress(uint256 _id, address _rewardAddress) external;

    /**
     * @notice Set the controllerAddress of the operator
     * @param _id operator id
     * @param _controllerAddress Ethereum 1 address for the operator's management authority
     */
    function setNodeOperatorControllerAddress(uint256 _id, address _controllerAddress) external;

    /**
     * @notice Get information about an operator
     * @param _id operator id
     * @param _fullInfo Get all information
     */
    function getNodeOperator(uint256 _id, bool _fullInfo)
        external
        view
        returns (
            bool trusted,
            string memory name,
            address rewardAddress,
            address controllerAddress,
            address vaultContractAddress
        );

    /**
     * @notice Get information about an operator vault contract address
     * @param _id operator id
     */
    function getNodeOperatorVaultContract(uint256 _id) external view returns (address vaultContractAddress);

    /**
     * @notice Returns total number of node operators
     */
    function getNodeOperatorsCount() external view returns (uint256);

    /**
     * @notice Returns total number of trusted operators
     */
    function getTrustedOperatorsCount() external view returns (uint256);

    /**
     * @notice Returns whether an operator is trusted
     */
    function isTrustedOperator(uint256 _id) external view returns (bool);

    /**
     * @notice Returns whether an operator is trusted
     */
    function isTrustedOperator(address _controllerAddress) external view returns (uint256);

    event NodeOperatorRegistered(
        uint256 id, string name, address rewardAddress, address controllerAddress, address _vaultContractAddress
    );
    event NodeOperatorTrustedSet(uint256 id, string name, bool trusted);
    event NodeOperatorTrustedRemove(uint256 id, string name, bool trusted);
    event NodeOperatorNameSet(uint256 id, string name);
    event NodeOperatorRewardAddressSet(uint256 id, string name, address rewardAddress);
    event NodeOperatorControllerAddressSet(uint256 id, string name, address controllerAddress);
}
