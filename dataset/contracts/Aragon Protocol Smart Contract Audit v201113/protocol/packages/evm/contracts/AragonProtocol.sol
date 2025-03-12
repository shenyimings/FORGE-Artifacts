pragma solidity ^0.5.17;

import "./lib/utils/Uint256Helpers.sol";

import "./arbitration/IArbitrator.sol";
import "./arbitration/IArbitrable.sol";
import "./core/modules/Controller.sol";
import "./disputes/IDisputeManager.sol";


contract AragonProtocol is IArbitrator, Controller {
    using Uint256Helpers for uint256;

    /**
    * @dev Constructor function
    * @param _termParams Array containing:
    *        0. _termDuration Duration in seconds per term
    *        1. _firstTermStartTime Timestamp in seconds when the protocol will open (to give time for guardian on-boarding)
    * @param _governors Array containing:
    *        0. _fundsGovernor Address of the funds governor
    *        1. _configGovernor Address of the config governor
    *        2. _modulesGovernor Address of the modules governor
    * @param _feeToken Address of the token contract that is used to pay for fees
    * @param _fees Array containing:
    *        0. guardianFee Amount of fee tokens that is paid per guardian per dispute
    *        1. draftFee Amount of fee tokens per guardian to cover the drafting cost
    *        2. settleFee Amount of fee tokens per guardian to cover round settlement cost
    * @param _roundStateDurations Array containing the durations in terms of the different phases of a dispute:
    *        0. evidenceTerms Max submitting evidence period duration in terms
    *        1. commitTerms Commit period duration in terms
    *        2. revealTerms Reveal period duration in terms
    *        3. appealTerms Appeal period duration in terms
    *        4. appealConfirmationTerms Appeal confirmation period duration in terms
    * @param _pcts Array containing:
    *        0. penaltyPct Permyriad of min active tokens balance to be locked to each drafted guardians (‱ - 1/10,000)
    *        1. finalRoundReduction Permyriad of fee reduction for the last appeal round (‱ - 1/10,000)
    * @param _roundParams Array containing params for rounds:
    *        0. firstRoundGuardiansNumber Number of guardians to be drafted for the first round of disputes
    *        1. appealStepFactor Increasing factor for the number of guardians of each round of a dispute
    *        2. maxRegularAppealRounds Number of regular appeal rounds before the final round is triggered
    *        3. finalRoundLockTerms Number of terms that a coherent guardian in a final round is disallowed to withdraw (to prevent 51% attacks)
    * @param _appealCollateralParams Array containing params for appeal collateral:
    *        1. appealCollateralFactor Permyriad multiple of dispute fees required to appeal a preliminary ruling
    *        2. appealConfirmCollateralFactor Permyriad multiple of dispute fees required to confirm appeal
    * @param _minActiveBalance Minimum amount of guardian tokens that can be activated
    */
    constructor(
        uint64[2] memory _termParams,
        address[3] memory _governors,
        IERC20 _feeToken,
        uint256[3] memory _fees,
        uint64[5] memory _roundStateDurations,
        uint16[2] memory _pcts,
        uint64[4] memory _roundParams,
        uint256[2] memory _appealCollateralParams,
        uint256 _minActiveBalance
    )
        public
        Controller(
            _termParams,
            _governors,
            _feeToken,
            _fees,
            _roundStateDurations,
            _pcts,
            _roundParams,
            _appealCollateralParams,
            _minActiveBalance
        )
    {
        // solium-disable-previous-line no-empty-blocks
    }

    /**
    * @notice Create a dispute with `_possibleRulings` possible rulings
    * @param _possibleRulings Number of possible rulings allowed for the drafted guardians to vote on the dispute
    * @param _metadata Optional metadata that can be used to provide additional information on the dispute to be created
    * @return Dispute identification number
    */
    function createDispute(uint256 _possibleRulings, bytes calldata _metadata) external returns (uint256) {
        IArbitrable subject = IArbitrable(msg.sender);
        return _disputeManager().createDispute(subject, _possibleRulings.toUint8(), _metadata);
    }

    /**
    * @notice Submit `_evidence` as evidence from `_submitter` for dispute #`_disputeId`
    * @param _disputeId Id of the dispute in the Protocol
    * @param _submitter Address of the account submitting the evidence
    * @param _evidence Data submitted for the evidence related to the dispute
    */
    function submitEvidence(uint256 _disputeId, address _submitter, bytes calldata _evidence) external {
        _submitEvidence(_disputeManager(), _disputeId, _submitter, _evidence);
    }

    /**
    * @notice Submit `_evidence` as evidence from `_submitter` for dispute #`_disputeId`
    * @dev This entry point can be used to submit evidences to previous Dispute Manager instances
    * @param _disputeManager Dispute manager to be used
    * @param _disputeId Id of the dispute in the Protocol
    * @param _submitter Address of the account submitting the evidence
    * @param _evidence Data submitted for the evidence related to the dispute
    */
    function submitEvidenceForModule(IDisputeManager _disputeManager, uint256 _disputeId, address _submitter, bytes calldata _evidence)
        external
        onlyActiveDisputeManager(_disputeManager)
    {
        _submitEvidence(_disputeManager, _disputeId, _submitter, _evidence);
    }

    /**
    * @notice Close the evidence period of dispute #`_disputeId`
    * @param _disputeId Identification number of the dispute to close its evidence submitting period
    */
    function closeEvidencePeriod(uint256 _disputeId) external {
        _closeEvidencePeriod(_disputeManager(), _disputeId);
    }

    /**
    * @notice Close the evidence period of dispute #`_disputeId`
    * @dev This entry point can be used to close evidence periods on previous Dispute Manager instances
    * @param _disputeManager Dispute manager to be used
    * @param _disputeId Identification number of the dispute to close its evidence submitting period
    */
    function closeEvidencePeriodForModule(IDisputeManager _disputeManager, uint256 _disputeId)
        external
        onlyActiveDisputeManager(_disputeManager)
    {
        _closeEvidencePeriod(_disputeManager, _disputeId);
    }

    /**
    * @notice Rule dispute #`_disputeId` if ready
    * @param _disputeId Identification number of the dispute to be ruled
    * @return subject Arbitrable instance associated to the dispute
    * @return ruling Ruling number computed for the given dispute
    */
    function rule(uint256 _disputeId) external returns (address subject, uint256 ruling) {
        return _rule(_disputeManager(), _disputeId);
    }

    /**
    * @notice Rule dispute #`_disputeId` if ready
    * @dev This entry point can be used to rule disputes on previous Dispute Manager instances
    * @param _disputeManager Dispute manager to be used
    * @param _disputeId Identification number of the dispute to be ruled
    * @return subject Arbitrable instance associated to the dispute
    * @return ruling Ruling number computed for the given dispute
    */
    function ruleForModule(IDisputeManager _disputeManager, uint256 _disputeId)
        external
        onlyActiveDisputeManager(_disputeManager)
        returns (address subject, uint256 ruling)
    {
        return _rule(_disputeManager, _disputeId);
    }

    /**
    * @dev Tell the dispute fees information to create a dispute
    * @return recipient Address where the corresponding dispute fees must be transferred to
    * @return feeToken ERC20 token used for the fees
    * @return feeAmount Total amount of fees that must be allowed to the recipient
    */
    function getDisputeFees() external view returns (address recipient, IERC20 feeToken, uint256 feeAmount) {
        IDisputeManager disputeManager = _disputeManager();
        recipient = address(disputeManager);
        (feeToken, feeAmount) = disputeManager.getDisputeFees();
    }

    /**
    * @dev Tell the payments recipient address
    * @return Address of the payments recipient module
    */
    function getPaymentsRecipient() external view returns (address) {
        return currentModules[MODULE_ID_PAYMENTS_BOOK];
    }

    /**
    * @dev Internal function to submit evidence for a dispute
    * @param _disputeManager Dispute manager to be used
    * @param _disputeId Id of the dispute in the Protocol
    * @param _submitter Address of the account submitting the evidence
    * @param _evidence Data submitted for the evidence related to the dispute
    */
    function _submitEvidence(IDisputeManager _disputeManager, uint256 _disputeId, address _submitter, bytes memory _evidence) internal {
        IArbitrable subject = IArbitrable(msg.sender);
        _disputeManager.submitEvidence(subject, _disputeId, _submitter, _evidence);
    }

    /**
    * @dev Internal function to close the evidence period of a dispute
    * @param _disputeManager Dispute manager to be used
    * @param _disputeId Identification number of the dispute to close its evidence submitting period
    */
    function _closeEvidencePeriod(IDisputeManager _disputeManager, uint256 _disputeId) internal {
        IArbitrable subject = IArbitrable(msg.sender);
        _disputeManager.closeEvidencePeriod(subject, _disputeId);
    }

    /**
    * @dev Internal function to rule a dispute
    * @param _disputeManager Dispute manager to be used
    * @param _disputeId Identification number of the dispute to be ruled
    * @return subject Arbitrable instance associated to the dispute
    * @return ruling Ruling number computed for the given dispute
    */
    function _rule(IDisputeManager _disputeManager, uint256 _disputeId) internal returns (address subject, uint256 ruling) {
        (IArbitrable _subject, uint8 _ruling) = _disputeManager.computeRuling(_disputeId);
        return (address(_subject), uint256(_ruling));
    }

    /**
    * @dev Internal function to tell the current DisputeManager module
    * @return Current DisputeManager module
    */
    function _disputeManager() internal view returns (IDisputeManager) {
        return IDisputeManager(_getModuleAddress(MODULE_ID_DISPUTE_MANAGER));
    }
}
