pragma solidity ^0.5.17;

import "../../lib/standards/IERC20.sol";


interface IConfig {

    /**
    * @dev Tell the full Protocol configuration parameters at a certain term
    * @param _termId Identification number of the term querying the Protocol config of
    * @return token Address of the token used to pay for fees
    * @return fees Array containing:
    *         0. guardianFee Amount of fee tokens that is paid per guardian per dispute
    *         1. draftFee Amount of fee tokens per guardian to cover the drafting cost
    *         2. settleFee Amount of fee tokens per guardian to cover round settlement cost
    * @return roundStateDurations Array containing the durations in terms of the different phases of a dispute:
    *         0. evidenceTerms Max submitting evidence period duration in terms
    *         1. commitTerms Commit period duration in terms
    *         2. revealTerms Reveal period duration in terms
    *         3. appealTerms Appeal period duration in terms
    *         4. appealConfirmationTerms Appeal confirmation period duration in terms
    * @return pcts Array containing:
    *         0. penaltyPct Permyriad of min active tokens balance to be locked for each drafted guardian (‱ - 1/10,000)
    *         1. finalRoundReduction Permyriad of fee reduction for the last appeal round (‱ - 1/10,000)
    * @return roundParams Array containing params for rounds:
    *         0. firstRoundGuardiansNumber Number of guardians to be drafted for the first round of disputes
    *         1. appealStepFactor Increasing factor for the number of guardians of each round of a dispute
    *         2. maxRegularAppealRounds Number of regular appeal rounds before the final round is triggered
    * @return appealCollateralParams Array containing params for appeal collateral:
    *         0. appealCollateralFactor Multiple of dispute fees required to appeal a preliminary ruling
    *         1. appealConfirmCollateralFactor Multiple of dispute fees required to confirm appeal
    * @return minActiveBalance Minimum amount of tokens guardians have to activate to participate in the Protocol
    */
    function getConfig(uint64 _termId) external view
        returns (
            IERC20 feeToken,
            uint256[3] memory fees,
            uint64[5] memory roundStateDurations,
            uint16[2] memory pcts,
            uint64[4] memory roundParams,
            uint256[2] memory appealCollateralParams,
            uint256 minActiveBalance
        );

    /**
    * @dev Tell the draft config at a certain term
    * @param _termId Identification number of the term querying the draft config of
    * @return feeToken Address of the token used to pay for fees
    * @return draftFee Amount of fee tokens per guardian to cover the drafting cost
    * @return penaltyPct Permyriad of min active tokens balance to be locked for each drafted guardian (‱ - 1/10,000)
    */
    function getDraftConfig(uint64 _termId) external view returns (IERC20 feeToken, uint256 draftFee, uint16 penaltyPct);

    /**
    * @dev Tell the min active balance config at a certain term
    * @param _termId Term querying the min active balance config of
    * @return Minimum amount of tokens guardians have to activate to participate in the Protocol
    */
    function getMinActiveBalance(uint64 _termId) external view returns (uint256);
}
