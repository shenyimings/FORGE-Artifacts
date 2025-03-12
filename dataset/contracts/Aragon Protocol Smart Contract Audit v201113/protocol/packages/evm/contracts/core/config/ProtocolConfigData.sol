pragma solidity ^0.5.17;

import "../../lib/standards/IERC20.sol";


contract ProtocolConfigData {
    struct Config {
        FeesConfig fees;                        // Full fees-related config
        DisputesConfig disputes;                // Full disputes-related config
        uint256 minActiveBalance;               // Minimum amount of tokens guardians have to activate to participate in the Protocol
    }

    struct FeesConfig {
        IERC20 token;                           // ERC20 token to be used for the fees of the Protocol
        uint16 finalRoundReduction;             // Permyriad of fees reduction applied for final appeal round (‱ - 1/10,000)
        uint256 guardianFee;                    // Amount of tokens paid to draft a guardian to adjudicate a dispute
        uint256 draftFee;                       // Amount of tokens paid per round to cover the costs of drafting guardians
        uint256 settleFee;                      // Amount of tokens paid per round to cover the costs of slashing guardians
    }

    struct DisputesConfig {
        uint64 evidenceTerms;                   // Max submitting evidence period duration in terms
        uint64 commitTerms;                     // Committing period duration in terms
        uint64 revealTerms;                     // Revealing period duration in terms
        uint64 appealTerms;                     // Appealing period duration in terms
        uint64 appealConfirmTerms;              // Confirmation appeal period duration in terms
        uint16 penaltyPct;                      // Permyriad of min active tokens balance to be locked for each drafted guardian (‱ - 1/10,000)
        uint64 firstRoundGuardiansNumber;       // Number of guardians drafted on first round
        uint64 appealStepFactor;                // Factor in which the guardians number is increased on each appeal
        uint64 finalRoundLockTerms;             // Period a coherent guardian in the final round will remain locked
        uint256 maxRegularAppealRounds;         // Before the final appeal
        uint256 appealCollateralFactor;         // Permyriad multiple of dispute fees required to appeal a preliminary ruling (‱ - 1/10,000)
        uint256 appealConfirmCollateralFactor;  // Permyriad multiple of dispute fees required to confirm appeal (‱ - 1/10,000)
    }

    struct DraftConfig {
        IERC20 feeToken;                         // ERC20 token to be used for the fees of the Protocol
        uint16 penaltyPct;                      // Permyriad of min active tokens balance to be locked for each drafted guardian (‱ - 1/10,000)
        uint256 draftFee;                       // Amount of tokens paid per round to cover the costs of drafting guardians
    }
}
