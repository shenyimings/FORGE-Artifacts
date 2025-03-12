//SPDX-License-Identifier: BUSL-1.1
pragma solidity 0.8.10;

import "./interfaces/IAllowlist.1.sol";
import "./interfaces/IOperatorRegistry.1.sol";
import "./interfaces/IRiver.1.sol";
import "./interfaces/IELFeeRecipient.1.sol";

import "./components/ConsensusLayerDepositManager.1.sol";
import "./components/UserDepositManager.1.sol";
import "./components/SharesManager.1.sol";
import "./components/OracleManager.1.sol";
import "./Initializable.sol";
import "./libraries/LibOwnable.sol";

import "./state/shared/AdministratorAddress.sol";
import "./state/river/AllowlistAddress.sol";
import "./state/river/OperatorsRegistryAddress.sol";
import "./state/river/TreasuryAddress.sol";
import "./state/river/OperatorRewardsShare.sol";
import "./state/river/GlobalFee.sol";
import "./state/river/ELFeeRecipientAddress.sol";

/// @title River (v1)
/// @author Kiln
/// @notice This contract merges all the manager contracts and implements all the virtual methods stitching all components together
contract RiverV1 is
    ConsensusLayerDepositManagerV1,
    UserDepositManagerV1,
    SharesManagerV1,
    OracleManagerV1,
    Initializable,
    IRiverV1
{
    uint256 public constant BASE = 100000;
    uint256 internal constant DEPOSIT_MASK = 0x1;
    uint256 internal constant TRANSFER_MASK = 0;
    /// @notice Prevents unauthorized calls

    modifier onlyAdmin() override (OracleManagerV1) {
        if (msg.sender != LibOwnable._getAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        _;
    }

    /// @notice Initializes the River system
    /// @param _depositContractAddress Address to make Consensus Layer deposits
    /// @param _elFeeRecipientAddress Address that receives the execution layer fees
    /// @param _withdrawalCredentials Credentials to use for every validator deposit
    /// @param _systemAdministratorAddress Administrator address
    /// @param _allowlistAddress Address of the allowlist contract
    /// @param _operatorRegistryAddress Address of the operator registry
    /// @param _treasuryAddress Address receiving the fee minus the operator share
    /// @param _globalFee Amount retained when the eth balance increases, splitted between the treasury and the operators
    /// @param _operatorRewardsShare Share of the global fee used to reward node operators
    function initRiverV1(
        address _depositContractAddress,
        address _elFeeRecipientAddress,
        bytes32 _withdrawalCredentials,
        address _oracleAddress,
        address _systemAdministratorAddress,
        address _allowlistAddress,
        address _operatorRegistryAddress,
        address _treasuryAddress,
        uint256 _globalFee,
        uint256 _operatorRewardsShare
    )
        external
        init(0)
    {
        if (_systemAdministratorAddress == address(0)) {
            // only check on initialization
            revert Errors.InvalidZeroAddress();
        }
        LibOwnable._setAdmin(_systemAdministratorAddress);
        TreasuryAddress.set(_treasuryAddress);
        GlobalFee.set(_globalFee);
        OperatorRewardsShare.set(_operatorRewardsShare);
        ELFeeRecipientAddress.set(_elFeeRecipientAddress);

        ConsensusLayerDepositManagerV1.initConsensusLayerDepositManagerV1(
            _depositContractAddress, _withdrawalCredentials
        );
        OracleManagerV1.initOracleManagerV1(_oracleAddress);
        AllowlistAddress.set(_allowlistAddress);
        OperatorsRegistryAddress.set(_operatorRegistryAddress);
    }

    /// @notice Changes the global fee parameter
    /// @param newFee New fee value
    function setGlobalFee(uint256 newFee) external onlyAdmin {
        if (newFee > BASE) {
            revert Errors.InvalidArgument();
        }

        GlobalFee.set(newFee);
    }

    /// @notice Get the current global fee
    function getGlobalFee() external view returns (uint256) {
        return GlobalFee.get();
    }

    /// @notice Changes the operator rewards share.
    /// @param newOperatorRewardsShare New share value
    function setOperatorRewardsShare(uint256 newOperatorRewardsShare) external onlyAdmin {
        if (newOperatorRewardsShare > BASE) {
            revert Errors.InvalidArgument();
        }

        OperatorRewardsShare.set(newOperatorRewardsShare);
    }

    /// @notice Get the current operator rewards share
    function getOperatorRewardsShare() external view returns (uint256) {
        return OperatorRewardsShare.get();
    }

    /// @notice Changes the allowlist address
    /// @param _newAllowlist New address for the allowlist
    function setAllowlist(address _newAllowlist) external onlyAdmin {
        AllowlistAddress.set(_newAllowlist);
    }

    /// @notice Retrieve the allowlist address
    function getAllowlist() external view returns (address) {
        return address(AllowlistAddress.get());
    }

    /// @notice Changes the treasury address
    /// @param _newTreasury New address for the treasury
    function setTreasury(address _newTreasury) external onlyAdmin {
        TreasuryAddress.set(_newTreasury);
    }

    /// @notice Retrieve the treasury address
    function getTreasury() external view returns (address) {
        return TreasuryAddress.get();
    }

    /// @notice Changes the admin but waits for new admin approval
    /// @param _newAdmin New address for the admin
    function transferOwnership(address _newAdmin) external onlyAdmin {
        LibOwnable._setPendingAdmin(_newAdmin);
    }

    /// @notice Accepts the ownership of the system
    function acceptOwnership() external {
        if (msg.sender != LibOwnable._getPendingAdmin()) {
            revert Errors.Unauthorized(msg.sender);
        }
        LibOwnable._setAdmin(msg.sender);
        LibOwnable._setPendingAdmin(address(0));
    }

    /// @notice Retrieve system administrator address
    function getAdministrator() external view returns (address) {
        return LibOwnable._getAdmin();
    }

    /// @notice Retrieve system pending administrator address
    function getPendingAdministrator() external view returns (address) {
        return LibOwnable._getPendingAdmin();
    }

    /// @notice Changes the execution layer fee recipient
    /// @param _newELFeeRecipient New address for the recipient
    function setELFeeRecipient(address _newELFeeRecipient) external onlyAdmin {
        ELFeeRecipientAddress.set(_newELFeeRecipient);
    }

    /// @notice Retrieve the execution layer fee recipient
    function getELFeeRecipient() external view returns (address) {
        return ELFeeRecipientAddress.get();
    }

    /// @notice Input for execution layer fee earnings
    function sendELFees() external payable {
        if (msg.sender != ELFeeRecipientAddress.get()) {
            revert Errors.Unauthorized(msg.sender);
        }
    }

    /// @notice Handler called whenever a token transfer is triggered
    /// @param _from Token sender
    /// @param _to Token receiver
    function _onTransfer(address _from, address _to) internal view override {
        IAllowlistV1(AllowlistAddress.get()).onlyAllowed(_from, TRANSFER_MASK); // this call reverts if unauthorized or denied
        IAllowlistV1(AllowlistAddress.get()).onlyAllowed(_to, TRANSFER_MASK); // this call reverts if unauthorized or denied
    }

    /// @notice Handler called whenever a user deposits ETH to the system. Mints the adequate amount of shares.
    /// @param _depositor User address that made the deposit
    /// @param _amount Amount of ETH deposited
    function _onDeposit(address _depositor, address _recipient, uint256 _amount) internal override {
        uint256 mintedShares = SharesManagerV1._mintShares(_depositor, _amount);
        if (_depositor == _recipient) {
            IAllowlistV1(AllowlistAddress.get()).onlyAllowed(_depositor, DEPOSIT_MASK); // this call reverts if unauthorized or denied
        } else {
            IAllowlistV1(AllowlistAddress.get()).onlyAllowed(_depositor, DEPOSIT_MASK + TRANSFER_MASK); // this call reverts if unauthorized or denied
            IAllowlistV1(AllowlistAddress.get()).onlyAllowed(_recipient, TRANSFER_MASK);
            _transfer(_depositor, _recipient, mintedShares);
        }
    }

    /// @notice Handler called whenever a deposit to the consensus layer is made. Should retrieve _requestedAmount or lower keys
    /// @param _requestedAmount Amount of keys required. Contract is expected to send _requestedAmount or lower.
    function _getNextValidators(uint256 _requestedAmount)
        internal
        override
        returns (bytes[] memory publicKeys, bytes[] memory signatures)
    {
        return IOperatorsRegistryV1(OperatorsRegistryAddress.get()).pickNextValidators(_requestedAmount);
    }

    /// @notice Internal utility managing reward distribution amongst node operators
    /// @param _reward Amount of shares to split between operators
    function _rewardOperators(uint256 _reward) internal returns (uint256) {
        Operators.Operator[] memory operators =
            IOperatorsRegistryV1(OperatorsRegistryAddress.get()).listActiveOperators();
        uint256[] memory validatorCounts = new uint256[](operators.length);

        uint256 totalActiveValidators = 0;
        for (uint256 idx = 0; idx < operators.length;) {
            uint256 operatorActiveValidatorCount = operators[idx].funded - operators[idx].stopped;
            totalActiveValidators += operatorActiveValidatorCount;
            validatorCounts[idx] = operatorActiveValidatorCount;
            unchecked {
                ++idx;
            }
        }

        if (totalActiveValidators > 0) {
            uint256 rewardsPerActiveValidator = _reward / totalActiveValidators;

            for (uint256 idx = 0; idx < validatorCounts.length;) {
                _mintRawShares(operators[idx].feeRecipient, validatorCounts[idx] * rewardsPerActiveValidator);
                unchecked {
                    ++idx;
                }
            }
        } else {
            _reward = 0;
        }

        return _reward;
    }

    /// @notice Internal utility to pull funds from the execution layer fee recipient to River and return the delta in the balance
    function _pullELFees() internal override returns (uint256) {
        address elFeeRecipient = ELFeeRecipientAddress.get();
        if (elFeeRecipient == address(0)) {
            return 0;
        }
        uint256 initialBalance = address(this).balance;
        IELFeeRecipientV1(payable(elFeeRecipient)).pullELFees();
        uint256 collectedELFees = address(this).balance - initialBalance;
        emit PulledELFees(collectedELFees);
        return collectedELFees;
    }

    /// @notice Handler called whenever the balance of ETH handled by the system increases. Splits funds between operators and treasury.
    /// @param _amount Additional eth received
    function _onEarnings(uint256 _amount) internal override {
        uint256 currentTotalSupply = _totalSupply();
        if (currentTotalSupply == 0) {
            revert ZeroMintedShares();
        }
        uint256 globalFee = GlobalFee.get();
        uint256 numerator = _amount * currentTotalSupply * globalFee;
        uint256 denominator = (_assetBalance() * BASE) - (_amount * globalFee);
        uint256 sharesToMint = denominator == 0 ? 0 : (numerator / denominator);

        uint256 operatorRewards = (sharesToMint * OperatorRewardsShare.get()) / BASE;

        uint256 mintedRewards = _rewardOperators(operatorRewards);

        _mintRawShares(TreasuryAddress.get(), sharesToMint - mintedRewards);
    }

    /// @notice Handler called whenever the total balance of ETH is requested
    function _assetBalance() internal view override returns (uint256) {
        uint256 beaconValidatorCount = BeaconValidatorCount.get();
        uint256 depositedValidatorCount = DepositedValidatorCount.get();
        if (beaconValidatorCount < depositedValidatorCount) {
            return BeaconValidatorBalanceSum.get() + address(this).balance
                + (depositedValidatorCount - beaconValidatorCount) * ConsensusLayerDepositManagerV1.DEPOSIT_SIZE;
        } else {
            return BeaconValidatorBalanceSum.get() + address(this).balance;
        }
    }
}
