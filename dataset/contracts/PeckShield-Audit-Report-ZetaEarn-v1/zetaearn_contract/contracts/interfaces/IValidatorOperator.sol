// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

interface IValidatorOperator {
    /// @notice node operator registry status, update through oracle
    enum NodeOperatorRegistryStatus {
        INACTIVE,
        ACTIVE,
        JAILED,
        EJECTED,
        UNSTAKED,
        WITHDRAWTOTAL
    }

    /// @notice version
    function version() external view returns (string memory);

    /// @notice ratio weight
    function ratio() external view returns (uint256);

    /// @notice get status
    function status() external view returns (NodeOperatorRegistryStatus);

    /// @notice get dao address
    function dao() external view returns (address);

    /// @notice get oracle address
    function oracle() external view returns (address);

    /// @notice get stZETA address
    function stZETA() external view returns (address);

    /// @notice get validator operator delegate address
    function delegateAddress() external view returns (address);

    /// @notice get validator operator reward address
    function rewardAddress() external view returns (address);

    /// @notice get total stake amount
    function totalStake() external view returns (uint256);

    /// @notice get validator operator commission rate
    function commissionRate() external view returns (uint16);

    /// @notice init ValidatorOperator contract
    /// @param _dao dao address
    /// @param _oracle oracle address
    /// @param _stZETA stZETA address
    /// @param _delegateAddress validator operator delegation address
    /// @param _rewardAddress validator operator reward address
    /// @param _commissionRate validator operator commission rate
    /// @param _nodeOperatorRegistry node operator registry address
    function initialize(
        address _dao,
        address _oracle,
        address _stZETA,
        address _delegateAddress,
        address _rewardAddress,
        uint16 _commissionRate,
        address _nodeOperatorRegistry
    ) external;

    /// @notice when node exit, wait oracle process
    function withdrawTotalDelegated() external;

    /// @notice to delegate
    function delegate() external payable;

    /// @notice set new version
    /// @param _newVersion new version
    function setVersion(string memory _newVersion) external;

    /// @notice set new ratio
    /// @param _newRatio new ratio
    function setRatio(uint256 _newRatio) external;

    /// @notice set new status
    /// @param _newStatus new status
    function setStatus(NodeOperatorRegistryStatus _newStatus) external;

    /// @notice set new dao address
    /// @param _newDao new dao address
    function setDao(address _newDao) external;

    /// @notice set new oracle address
    /// @param _newOracle new oracle address
    function setOracle(address _newOracle) external;

    /// @notice set new stZETA address
    /// @param _newStZETA new stZETA address
    function setStZETA(address _newStZETA) external;

    /// @notice set new delegation address
    /// @param _newDelegateAddress new delegation address
    function setDelegateAddress(address _newDelegateAddress) external;

    /// @notice set new reward address
    /// @param _newRewardAddress new reward address
    function setRewardAddress(address _newRewardAddress) external;

    /// @notice set new totalStake
    /// @param _newTotalStake new totalStake
    function setTotalStake(uint256 _newTotalStake) external;

    /// @notice set new commission rate
    /// @param _newCommissionRate new commission rate
    function setCommissionRate(uint16 _newCommissionRate) external;

    /// @notice to unstake, update validator unbond info
    /// @param claimAmount claim amount
    function unStake(uint256 claimAmount) external;

    // unbond data structure
    struct DelegatorUnbond {
        uint256 amount;
        uint256 withdrawEpoch;
    }

    /// @notice get address unbond nonces
    /// @param user user address
    /// @return unbond nonces
    function getUnbondNonces(address user) external view returns (uint256);

    /// @notice get user nonce's unbond info
    /// @param user user address
    /// @param unbondNonce unbond nonce
    /// @return unbond unbond info
    function getDelegatorUnbond(address user, uint256 unbondNonce) external view returns (DelegatorUnbond memory);

    /// @notice oracle reward add to total stake
    /// @param rewardAmount reward amount
    function addOracleReward(uint256 rewardAmount) external;

    /// @notice oracle punish sub total stake
    /// @param punishAmount punishAmount amount
    function subOraclePunish(uint256 punishAmount) external;

    /// @notice get update new version
    function getUpdateVersion() external pure returns(string memory);

    /// @notice set address nonce's unbond info
    /// @param _user user address
    /// @param _unbondNonces unbond nonce
    /// @param _target_epoch target epoch
    function setNoncesEpoch(address _user, uint256[] memory _unbondNonces, uint256 _target_epoch) external;

    /// @notice get epoch unbond amount
    /// @param epoch epoch
    /// @return unbond epoch
    function getfinishedUnbondEpochAmount(uint256 epoch) external view returns (uint256);

    /// @notice finished unbond call
    /// @param delegator_address delegator address
    /// @param epoch epoch
    /// @param blockHeight block height
    function finishUnbond(
        address delegator_address,
        uint256 epoch,
        uint256 blockHeight
    ) external payable;

    /// @notice get total unbond amount
    function totalUnbondAmount() external view returns (uint256);

    /// @notice get last finished unbond epoch
    function lastEpochFinishedUnbond() external view returns (uint256);

    /// @notice unstake claim
    /// @param unbondNonce unbond nonce
    /// @return claim amount
    function unstakeClaimTokens(uint256 unbondNonce) external returns(uint256);

    /// @notice set total unbond amount
    /// @param _totalUnbondAmount total unbond amount
    function setTotalUnbondAmount(uint256 _totalUnbondAmount) external;

    /// @notice set finished unbond epoch amount
    /// @param _epoch epoch
    /// @param _amount amount
    function setFinishedUnbondEpochAmount(uint256 _epoch, uint256 _amount) external;

    /// @notice get NodeOperatorRegistry address
    function nodeOperatorRegistry() external view returns (address);
    
    /// @notice set new NodeOperatorRegistry address
    /// @param _newNodeOperatorRegistry new NodeOperatorRegistry address
    function setNodeOperatorRegistry(address _newNodeOperatorRegistry) external;

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                    EVENTS                          ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @notice set new version event
    /// @param oldVersion old version.
    /// @param newVersion new version.
    event SetVersion(string oldVersion, string newVersion);

    /// @notice set new ratio event
    /// @param oldRatio old Ratio.
    /// @param newRatio new Ratio.
    event SetRatio(uint256 oldRatio, uint256 newRatio);

    /// @notice set new status
    /// @param oldStatus old Status.
    /// @param newStatus new Status.
    event SetStatus(NodeOperatorRegistryStatus oldStatus, NodeOperatorRegistryStatus newStatus);

    /// @notice set new dao address
    /// @param oldDao old dao address.
    /// @param newDao new dao address.
    event SetDao(address oldDao, address newDao);

    /// @notice set new oracle address
    /// @param oldOracle old oracle address.
    /// @param newOracle new oracle address.
    event SetOracle(address oldOracle, address newOracle);

    /// @notice set new stZETA address
    /// @param oldStZETA old stZETA address.
    /// @param newStZETA new stZETA address.
    event SetStZETA(address oldStZETA, address newStZETA);

    /// @notice set new delegation address
    /// @param oldDelegateAddress old delegation address.
    /// @param newDelegateAddress new delegation address.
    event SetDelegateAddress(address oldDelegateAddress, address newDelegateAddress);

    /// @notice set new reward address
    /// @param oldRewardAddress old reward address.
    /// @param newRewardAddress new reward address.
    event SetRewardAddress(address oldRewardAddress, address newRewardAddress);

    /// @notice set new totalStake
    /// @param oldTotalStake old totalStake.
    /// @param newTotalStake new totalStake.
    event SetTotalStake(uint256 oldTotalStake, uint256 newTotalStake);

    /// @notice set new commission rate
    /// @param oldCommissionRate old commission rate.
    /// @param newCommissionRate new commission rate.
    event SetCommissionRate(uint16 oldCommissionRate, uint16 newCommissionRate);

    /// @notice when validator quit emit
    event WithdrawTotalDelegated();

    /// @notice delegate emit.
    /// @param _amount stake amount
    /// @param _rewardAddress - reward address.
    /// @param _totalStake - total stake.
    event Delegate(uint256 indexed _amount, address indexed _rewardAddress, uint256 _totalStake);

    /// @notice unStake emit.
    /// @param currentEpoch current epoch.
    /// @param claimAmount unstake amount.
    /// @param unbondNonce unbond nonce.
    /// @param totalStake rest total stake.
    event UnStake(uint256 indexed currentEpoch, uint256 indexed claimAmount, uint256 indexed unbondNonce, uint256 totalStake);

    /// @notice add new oracle reward emit
    /// @param reward reward.
    /// @param newTotalStake new totalStake.
    event AddOracleReward(uint256 indexed reward, uint256 indexed newTotalStake);

    /// @notice sub oracle punish emit
    /// @param punishAmount punishAmount.
    /// @param newTotalStake new totalStake.
    event SubOracleReward(uint256 indexed punishAmount, uint256 indexed newTotalStake);

    /// @notice set new nonces epoch emit
    /// @param user user address.
    /// @param epoch epoch.
    /// @param nonces nonces.
    event SetNoncesEpoch(address indexed user, uint256 indexed epoch, uint256[] nonces);

    /// @notice finish unbond emit
    /// @param amount amount.
    /// @param epoch epoch.
    /// @param blockHeight blockHeight.
    /// @param delegator_address delegator_address.
    /// @param totalUnbondAmount totalUnbondAmount.
    event FinishUnbond(
        uint256 indexed amount, uint256 indexed epoch, uint256 indexed blockHeight,
        address delegator_address, uint256 totalUnbondAmount);

    /// @notice set total unbond amount emit
    /// @param oldTotalUnbondAmount oldTotalUnbondAmount.
    /// @param newTotalUnbondAmount newTotalUnbondAmount.
    event SetTotalUnbondAmount(uint256 indexed oldTotalUnbondAmount, uint256 indexed newTotalUnbondAmount);

    /// @notice set finished unbond epoch amount emit
    /// @param epoch epoch.
    /// @param oldAmount oldAmount.
    /// @param newAmount newAmount.
    event SetFinishedUnbondEpochAmount(uint256 indexed epoch, uint256 indexed oldAmount, uint256 indexed newAmount);

    /// @notice set new NodeOperatorRegistry address
    /// @param oldNodeOperatorRegistry old NodeOperatorRegistry address.
    /// @param newNodeOperatorRegistry new NodeOperatorRegistry address.
    event SetNodeOperatorRegistry(address oldNodeOperatorRegistry, address newNodeOperatorRegistry);

}