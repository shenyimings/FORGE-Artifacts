// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "./interfaces/IValidatorOperator.sol";
import "./interfaces/INodeOperatorRegistry.sol";


contract NodeOperatorRegistry is
    INodeOperatorRegistry,
    PausableUpgradeable,
    AccessControlUpgradeable,
    ReentrancyGuardUpgradeable
{
    /// @notice All roles.
    bytes32 public constant DAO_ROLE = keccak256("ZETAEARN_DAO");
    bytes32 public constant PAUSE_ROLE = keccak256("ZETAEARN_PAUSE_OPERATOR");
    bytes32 public constant UNPAUSE_ROLE = keccak256("ZETAEARN_UNPAUSE_OPERATOR");
    bytes32 public constant ADD_NODE_OPERATOR_ROLE = keccak256("ZETAEARN_ADD_NODE_OPERATOR_ROLE");
    bytes32 public constant REMOVE_NODE_OPERATOR_ROLE = keccak256("ZETAEARN_REMOVE_NODE_OPERATOR_ROLE");

    /// @notice Contract version.
    string public version;

    /// @notice DAO address.
    address public override dao;

    /// @notice List of all operator addresses.
    address[] public operatorAddresses;

    /// @notice Mapping of owner to node operator address. 
    mapping(address => address) public validatorOperatorAddressToRewardAddress;

    /// @notice Mapping of validator reward address to operator address. 
    mapping(address => address) public validatorRewardAddressToOperatorAddress;

    /// @notice Initialize NodeOperatorRegistry contract.
    function initialize(address _dao) external initializer {
        __Pausable_init();
        __AccessControl_init();
        __ReentrancyGuard_init();

        // Set roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(PAUSE_ROLE, msg.sender);
        _grantRole(UNPAUSE_ROLE, _dao);
        _grantRole(DAO_ROLE, _dao);
        _grantRole(ADD_NODE_OPERATOR_ROLE, _dao);
        _grantRole(REMOVE_NODE_OPERATOR_ROLE, _dao);

        // Set addresses
        dao = _dao;

        version = "1.0.5";
    }

    /// @notice Add new node operator to the system.  
    /// Only ADD_NODE_OPERATOR_ROLE can execute this function.
    /// @param _operatorAddress - operator address.
    function addNodeOperator(address _operatorAddress)
        external
        override
        onlyRole(ADD_NODE_OPERATOR_ROLE)
        nonReentrant {
        // Operator address cannot be 0
        require(_operatorAddress != address(0), "invalid operator address");
        // Operator address cannot already exist
        require(
            validatorOperatorAddressToRewardAddress[_operatorAddress] == address(0),
            "operator exists"
        );
        // Get validator
        IValidatorOperator validator = IValidatorOperator(_operatorAddress);
        address _rewardAddress = validator.rewardAddress();
        address _delegateAddress = validator.delegateAddress();
        // Reward address cannot already exist
        require(
            validatorRewardAddressToOperatorAddress[_rewardAddress] == address(0),
            "reward exists"
        );
        // Reward address cannot be 0
        require(_rewardAddress != address(0), "Invalid reward address");
        // Delegate address cannot be 0
        require(_delegateAddress != address(0), "Invalid delegate address");
        // Validator status must be active
        require(
            validator.status() == IValidatorOperator.NodeOperatorRegistryStatus.ACTIVE,
            "Validator isn't ACTIVE"
        );
        // Update operator address to reward address mapping
        validatorOperatorAddressToRewardAddress[_operatorAddress] = _rewardAddress;
        // Update reward address to validator address mapping
        validatorRewardAddressToOperatorAddress[_rewardAddress] = _operatorAddress;
        // Add operator address to operator address list
        operatorAddresses.push(_operatorAddress);

        emit AddNodeOperator(_operatorAddress, _delegateAddress, _rewardAddress);
    }

    /// @notice Exit node operator registry
    /// Only callable by node operator owner
    function exitNodeOperatorRegistry() external override nonReentrant {
        // Get validator address
        address operatorAddress = validatorRewardAddressToOperatorAddress[msg.sender];
        // Get reward address
        address rewardAddress = validatorOperatorAddressToRewardAddress[operatorAddress];
        // Reward address must be caller
        require(rewardAddress == msg.sender, "Unauthorized");
        // Get validator
        IValidatorOperator validator = IValidatorOperator(operatorAddress);
        // Remove from record
        _removeOperator(operatorAddress, rewardAddress);

        emit ExitNodeOperator(operatorAddress, validator.delegateAddress(), rewardAddress);
    }

    /// @notice Remove a node operator from the system
    /// Only callable by REMOVE_NODE_OPERATOR_ROLE
    /// @param operatorAddress validator operator address
    function removeNodeOperator(address operatorAddress)
        external
        override
        onlyRole(REMOVE_NODE_OPERATOR_ROLE)
        nonReentrant {
        // Get reward address
        address rewardAddress = validatorOperatorAddressToRewardAddress[operatorAddress];
        // Reward address cannot be 0
        require(rewardAddress != address(0), "Validator doesn't exist");
        // Get validator
        IValidatorOperator validator = IValidatorOperator(operatorAddress);
        // Remove from record
        _removeOperator(operatorAddress, rewardAddress);

        emit RemoveNodeOperator(operatorAddress, validator.delegateAddress(), rewardAddress);
    }

    /// @notice Remove a node operator if it does not meet conditions
    // only callable by DAO_ROLE
    /// @param operatorAddress validator's validator operator address
    function removeInvalidNodeOperator(address operatorAddress)
        external
        override
        onlyRole(DAO_ROLE)
        whenNotPaused
        nonReentrant {
        // Get reward address
        address rewardAddress = validatorOperatorAddressToRewardAddress[operatorAddress];
        // Get validator status and validator
        IValidatorOperator validator = IValidatorOperator(operatorAddress);
        IValidatorOperator.NodeOperatorRegistryStatus operatorStatus = validator.status();
        // Validator status must not be unstaked or ejected
        require(
            operatorStatus == IValidatorOperator.NodeOperatorRegistryStatus.UNSTAKED ||
                operatorStatus == IValidatorOperator.NodeOperatorRegistryStatus.EJECTED,
            "Cannot remove valid operator."
        );
        // Remove from record
        _removeOperator(operatorAddress, rewardAddress);

        emit RemoveInvalidNodeOperator(operatorAddress, validator.delegateAddress(), rewardAddress);
    }

    /// @notice Remove operator from record
    /// @param _operatorAddress validator operator address
    /// @param _rewardAddress validator reward address
    function _removeOperator(address _operatorAddress, address _rewardAddress) private {
        // Iterate through validator IDs list to remove 
        uint256 length = operatorAddresses.length;
        for (uint256 idx = 0; idx < length - 1; idx++) {
            if (_operatorAddress == operatorAddresses[idx]) {
                operatorAddresses[idx] = operatorAddresses[length - 1];
                operatorAddresses.pop();
                break;
            }
        }
        require(operatorAddresses.length == (length - 1), "Operator not found");
        // Update validator to withdraw all delegated flagged, for oracle to execute
        IValidatorOperator validator = IValidatorOperator(_operatorAddress);
        validator.withdrawTotalDelegated();
        // Remove from validator address to reward address mapping
        delete validatorOperatorAddressToRewardAddress[_operatorAddress];
        delete validatorRewardAddressToOperatorAddress[_rewardAddress];
    }

    /// @notice Get update version on each update
    function getUpdateVersion() external pure override returns(string memory) {
        return "1.0.5";
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                    Setters                         ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @notice Update  reward address.
    /// @param _newRewardAddress - New reward address.
    function setRewardAddress(address _newRewardAddress)
        external
        override
        whenNotPaused {
        // only old reward address can call this function
        require(_newRewardAddress != msg.sender, "Invalid reward address");
        address operatorAddress = validatorRewardAddressToOperatorAddress[msg.sender];
        address oldRewardAddress = validatorOperatorAddressToRewardAddress[operatorAddress];
        require(oldRewardAddress == msg.sender, "Unauthorized");
        require(_newRewardAddress != address(0), "Invalid reward address");

        validatorOperatorAddressToRewardAddress[operatorAddress] = _newRewardAddress;
        require(validatorRewardAddressToOperatorAddress[_newRewardAddress] == address(0), "reward exists");
        validatorRewardAddressToOperatorAddress[_newRewardAddress] = operatorAddress;
        delete validatorRewardAddressToOperatorAddress[msg.sender];

        emit SetRewardAddress(operatorAddress, oldRewardAddress, _newRewardAddress);
    }

    /// @notice Set contract version.
    /// @notice Only callable by DAO role.
    /// @param _newVersion - New contract version.
    function setVersion(string memory _newVersion)
        external
        override
        onlyRole(DAO_ROLE) {
        string memory oldVersion = version;
        version = _newVersion;
        emit SetVersion(oldVersion, _newVersion);
    }

    /// @notice Pause contract
    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @notice Unpause contract
    function unpause() external onlyRole(UNPAUSE_ROLE) {
        _unpause();
    }

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                    Getters                         ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @notice List all delegated node operators.
    /// @return nodeOperators A list of node operators.
    function listDelegatedNodeOperators()
        external
        view
        override
        returns (ValidatorData[] memory) {
        return _listNodeOperators(true);
    }

    /// @notice List all operators that can be withdrawn
    /// @return nodeOperators A list of node operators.
    function listWithdrawNodeOperators()
        external
        view
        override
        returns (ValidatorData[] memory) {
        return _listNodeOperators(false);
    }

    /// @notice List all operators depending on if it is for delegation or withdraw
    /// @param _isForDelegation Whether it is for delegation
    /// @return nodeOperators A list of node operators.
    function _listNodeOperators(bool _isForDelegation)
        private
        view
        returns (ValidatorData[] memory){
        // Total node operators
        uint256 totalNodeOperators = 0;
        // Temp validator
        IValidatorOperator validator;
        // Temp operator status
        IValidatorOperator.NodeOperatorRegistryStatus operatorStatus;
        // Validator address list
        address[] memory memOperatorAddresses = operatorAddresses;
        // Length of validator list
        uint256 length = memOperatorAddresses.length;
        // Newly created list of node operators
        ValidatorData[] memory activeValidators = new ValidatorData[](length);
        // Iterate through validator list
        for (uint256 i = 0; i < length; i++) {
            // Get reward address
            address rewardAddress = validatorOperatorAddressToRewardAddress[memOperatorAddresses[i]];
            // Get node operator status and validator
            validator = IValidatorOperator(memOperatorAddresses[i]);
            operatorStatus = validator.status();
            // Get node status, different condition based on whether it is for delegation
            bool condition = _listNodeOperatorCondition(operatorStatus, _isForDelegation);
            if (!condition) continue;
            // Add to node operators list
            activeValidators[totalNodeOperators] = ValidatorData(
                memOperatorAddresses[i],
                validator.delegateAddress(),
                rewardAddress
            );
            // Increment node operators count
            totalNodeOperators++;
        }
        // If node operators count less than validator list length, reallocate memory
        if (totalNodeOperators < length) {
            assembly {
                mstore(activeValidators, totalNodeOperators)
            }
        }
        // Return node operators list
        return activeValidators;
    }

    /// @notice Get validator status
    /// @param _operatorStatus Node operator status
    /// @param _isForDelegation Whether it is for delegation
    /// @return status Node operator status
    function _listNodeOperatorCondition(
        IValidatorOperator.NodeOperatorRegistryStatus _operatorStatus,
        bool _isForDelegation
    ) private pure returns (bool) {
        // If for delegation, check validator status is active
        if (_isForDelegation) {
            if (_operatorStatus == IValidatorOperator.NodeOperatorRegistryStatus.ACTIVE) return true;
            return false;
        } else {
            // Otherwise check validator status is not inactive
            if (_operatorStatus != IValidatorOperator.NodeOperatorRegistryStatus.INACTIVE) return true;
            return false;
        }
    }

    /// @notice Calculate delegation amount for each validator
    /// @return validators validators
    /// @return stakePerOperator Stake per node operator  
    /// @return operatorRatios Ratio list for each node operator. 
    /// @return totalRatio Total ratio
    /// @return totalStaked Total staked
    function getValidatorsDelegationAmount()
        external
        view
        override
        returns (
            ValidatorData[] memory validators,
            uint256[] memory stakePerOperator,
            uint256[] memory operatorRatios,
            uint256 totalRatio,
            uint256 totalStaked
        ) {
        // Require at least 1 node operator
        require(operatorAddresses.length > 0, "Not enough operators to delegate");
        // Get validator infos
        (
            validators,
            stakePerOperator,
            operatorRatios,
            totalStaked,
            totalRatio
        ) = _getValidatorsDelegationInfos();
    }

    /// @notice Return operator delegation infos.
    /// @return validators List of node operators.
    /// @return stakePerOperator Delegate amount within each validator.
    /// @return operatorRatios Ratio list for each validator.
    /// @return totalStaked Total delegate amount across active validators.  
    /// @return totalRatio Total ratio across active node operators.
    function _getValidatorsDelegationInfos()
        private
        view
        returns (
            ValidatorData[] memory validators,
            uint256[] memory stakePerOperator,
            uint256[] memory operatorRatios,
            uint256 totalStaked,
            uint256 totalRatio
        ) {
        // Active operators count
        uint256 activeOperatorCount;
        // operator Addresses
        address[] memory operatorAddressesMem = operatorAddresses;
        // Newly created list of node operators
        validators = new ValidatorData[](operatorAddressesMem.length);
        // Newly created delegate amount per validator list
        stakePerOperator = new uint256[](operatorAddressesMem.length);
        // Newly created ratio list per validator
        operatorRatios = new uint256[](operatorAddressesMem.length);
        // Temp validator address
        address operatorAddress;
        // Temp reward address
        address rewardAddress;
        // Temp validator
        IValidatorOperator validator;
        // Temp operator status
        IValidatorOperator.NodeOperatorRegistryStatus status;
        // Iterate through operator address list
        for (uint256 i = 0; i < operatorAddressesMem.length; i++) {
            // Get operator address
            operatorAddress = operatorAddressesMem[i];
            // Get reward address
            rewardAddress = validatorOperatorAddressToRewardAddress[operatorAddress];
            // Get node operator status and validator
            validator = IValidatorOperator(operatorAddress);
            status = validator.status();
            // If node operator status is inactive, skip
            if (status == IValidatorOperator.NodeOperatorRegistryStatus.INACTIVE) continue;
            // Require node operator status is not ejected
            require(
                !(status == IValidatorOperator.NodeOperatorRegistryStatus.EJECTED),
                "Could not calculate the stake data, an operator was EJECTED"
            );
            // Require node operator status is not unstaked
            require(
                !(status == IValidatorOperator.NodeOperatorRegistryStatus.UNSTAKED),
                "Could not calculate the stake data, an operator was UNSTAKED"
            );
            // Get validator total delegated in stZETA contract
            uint256 amount = validator.totalStake();
            // Add to total staked
            totalStaked += amount;
            // If node operator status is active, add to node operators list
            if (status == IValidatorOperator.NodeOperatorRegistryStatus.ACTIVE) 
            {
                // Update delegate amount per validator
                stakePerOperator[activeOperatorCount] = amount;
                // Update node operators list at index
                validators[activeOperatorCount] = ValidatorData(
                    operatorAddress,
                    validator.delegateAddress(),
                    rewardAddress
                );
                // Update node operator ratio 
                operatorRatios[activeOperatorCount] = validator.ratio();
                // Increment active operators count
                activeOperatorCount++;
                // Update total ratio
                totalRatio += validator.ratio();
            }
        }
        // Require at least 1 active validator
        require(activeOperatorCount > 0, "There are no active validator");

        // If active validators count less than validator list length, reallocate memory
        if (activeOperatorCount < operatorAddressesMem.length) {
            assembly {
                mstore(validators, activeOperatorCount)
                mstore(stakePerOperator, activeOperatorCount)
                mstore(operatorRatios, activeOperatorCount)
            }
        }
    }

    /// @notice Return a node operator by operator address
    /// @param operatorAddress validator operator address
    /// @return nodeOperator A node operator structure
    function getNodeOperatorByOperatorAddress(address operatorAddress)
        external
        view
        returns (FullNodeOperatorRegistry memory nodeOperator) {
        // Get reward address
        address rewardAddress = validatorOperatorAddressToRewardAddress[operatorAddress];
        require(rewardAddress != address(0), "Reward not found");
        // Get node operator status and validator
        IValidatorOperator validator = IValidatorOperator(operatorAddress);
        // Get node operator other infos
        nodeOperator.operatorAddress = operatorAddress;
        nodeOperator.delegateAddress = validator.delegateAddress();
        nodeOperator.rewardAddress = rewardAddress;
        nodeOperator.status = validator.status();
        nodeOperator.commissionRate = validator.commissionRate();
    }

    /// @notice Return a node operator by reward address
    /// @param rewardAddress Reward address
    /// @return nodeOperator A node operator structure
    function getNodeOperatorByRewardAddress(address rewardAddress)
        external
        view
        returns (FullNodeOperatorRegistry memory nodeOperator) {
        // Get operator address from reward address
        address operatorAddress = validatorRewardAddressToOperatorAddress[rewardAddress];
        require(operatorAddress != address(0), "Operator not found");
        // Get node operator status and validator
        IValidatorOperator validator = IValidatorOperator(operatorAddress);
        // Get node operator other infos
        nodeOperator.operatorAddress = operatorAddress;
        nodeOperator.delegateAddress = validator.delegateAddress();
        nodeOperator.rewardAddress = rewardAddress;
        nodeOperator.status = validator.status();
        nodeOperator.commissionRate = validator.commissionRate();
    }

    /// @notice Return a node operator's status
    /// @param  operatorAddress Node operator address  
    /// @return operatorStatus Return a node operator's status
    function getNodeOperatorStatus(address operatorAddress)
        external
        view
        returns (IValidatorOperator.NodeOperatorRegistryStatus operatorStatus) {
        // Ensure node operator exists via reward address
        address rewardAddress = validatorOperatorAddressToRewardAddress[operatorAddress];
        require(rewardAddress != address(0), "Reward not found");
        // Get node operator status and validator
        IValidatorOperator validator = IValidatorOperator(operatorAddress);
        operatorStatus = validator.status();
    }


    /// @notice Return list of all operatorAddresses
    function getOperatorAddresses() external view returns (address[] memory) {
        return operatorAddresses;
    }

    /// @notice get validators request withdraw
    /// @param _withdrawAmount Amount that can be withdrawn
    /// @return validators validators
    /// @return totalDelegated Total delegated
    /// @return bigNodeOperatorAddresses TODO Addresses of node operators with delegation above average 
    /// @return smallNodeOperatorAddresses TODO Addresses of node operators with delegation below average
    /// @return operatorAmountCanBeRequested TODO Amount that can be requested from specific validator if system imbalanced
    /// @return totalValidatorToWithdrawFrom Number of validators to withdraw from if system balanced  
    /// @return minStakeAmount Minimum validator stake if system balanced
    function getValidatorsRequestWithdraw(uint256 _withdrawAmount)
    external
    view
    override
    returns (
        ValidatorData[] memory validators,
        uint256 totalDelegated,
        address[] memory bigNodeOperatorAddresses,
        address[] memory smallNodeOperatorAddresses,
        uint256[] memory operatorAmountCanBeRequested,
        uint256 totalValidatorToWithdrawFrom,
        uint256 minStakeAmount
    ) {
        require(_withdrawAmount > 0, "Invalid amount");
        // Require at least 1 node operator
        if (operatorAddresses.length == 0) {
            return (
                validators,
                totalDelegated,
                bigNodeOperatorAddresses,
                smallNodeOperatorAddresses,
                operatorAmountCanBeRequested,
                totalValidatorToWithdrawFrom,
                0
            );
        }
        uint256[] memory stakePerOperator;
        uint256 minAmount;
        uint256 maxAmount;
        // Get validator infos
        (
            validators,
            stakePerOperator,
            totalDelegated,
            minAmount,
            maxAmount
        ) = _getValidatorsRequestWithdraw();
        // If currently no delegation, directly return
        if (totalDelegated == 0) {
            return (
                validators,
                totalDelegated,
                bigNodeOperatorAddresses,
                smallNodeOperatorAddresses,
                operatorAmountCanBeRequested,
                totalValidatorToWithdrawFrom,
                0
            );
        }
        // only consider the case of balance
        totalValidatorToWithdrawFrom = validators.length;
        return (
            validators,
            totalDelegated,
            bigNodeOperatorAddresses,
            smallNodeOperatorAddresses,
            operatorAmountCanBeRequested,
            totalValidatorToWithdrawFrom,
            minAmount
        );
    }

    /// @notice Return validator request withdraw infos
    /// @return activeValidators active node operators.
    /// @return stakePerOperator stake amount per validator. 
    /// @return totalDelegated Total delegation across validators.
    /// @return minAmount Minimum delegation in validator.
    /// @return maxAmount Maximum delegation in validator.
    function _getValidatorsRequestWithdraw()
    private
    view
    returns (
        ValidatorData[] memory activeValidators,
        uint256[] memory stakePerOperator,
        uint256 totalDelegated,
        uint256 minAmount,
        uint256 maxAmount
    ) {
        address[] memory operatorAddressesMem = operatorAddresses;
        activeValidators = new ValidatorData[](operatorAddressesMem.length);
        stakePerOperator = new uint256[](operatorAddressesMem.length);

        address rewardAddress;
        IValidatorOperator validator;
        IValidatorOperator.NodeOperatorRegistryStatus status;
        minAmount = type(uint256).max;
        uint256 activeValidatorsCounter;

        // Iterate through validator list
        for (uint256 i = 0; i < operatorAddresses.length; i++) {
            // Get reward address
            rewardAddress = validatorOperatorAddressToRewardAddress[operatorAddresses[i]];
            // Get validator status and validator
            // Get node operator status and validator
            validator = IValidatorOperator(operatorAddresses[i]);
            status = validator.status();
            // If validator status is inactive, skip
            if (status ==  IValidatorOperator.NodeOperatorRegistryStatus.INACTIVE) continue;

            // Get validator total delegated in stZETA contract
            uint256 amount = validator.totalStake();
            // Update return values
            stakePerOperator[activeValidatorsCounter] = amount;
            totalDelegated += amount;
            // Update min max delegation
            if (maxAmount < amount) {
                maxAmount = amount;
            }
            if (minAmount > amount) {
                minAmount = amount;
            }
            // Update active node operators list and count
            activeValidators[activeValidatorsCounter] = ValidatorData(
                operatorAddresses[i],
                validator.delegateAddress(),
                rewardAddress
            );
            activeValidatorsCounter++;
        }
        // If active node operators count less than validator list length, reallocate memory
        if (activeValidatorsCounter < operatorAddresses.length) {
            assembly {
                mstore(activeValidators, activeValidatorsCounter)
                mstore(stakePerOperator, activeValidatorsCounter)
            }
        }
    }
}