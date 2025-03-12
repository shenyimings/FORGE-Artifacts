// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";

import "./INodeOperatorRegistry.sol";
import "./IUnStZETA.sol";

interface IStZETA is IERC20Upgradeable {
    /// @notice fee distribution struct. Not Use Now.
    /// @param dao dao fee.
    /// @param operators operators fee.
    /// @param insurance insurance fee.
    struct FeeDistribution {
        uint8 dao;
        uint8 operators;
        uint8 insurance;
    }

    /// @notice get fees. 
    /// @return dao dao fee.
    /// @return operators operators fee.
    /// @return insurance insurance fee.
    function entityFees() external view returns (uint8, uint8, uint8);

    /// @notice contract version.
    /// @return version contract version.
    function version() external view returns (string memory);

    /// @notice dao address
    /// @return dao dao address
    function dao() external view returns (address);

    /// @notice oracle address
    /// @return oracle oracle address
    function oracle() external view returns (address);

    /// @notice insurance address. Not Use Now.
    /// @return insurance insurance address
    function insurance() external view returns (address);

    /// @notice Node operator registry interface.
    /// @return nodeOperatorRegistry Node operator registry interface.
    function nodeOperatorRegistry() external view returns (INodeOperatorRegistry);

    /// @notice Total amount of buffered Zeta in the contract.
    /// @return amount Total amount of buffered
    function totalBuffered() external view returns (uint256);

    /// @notice Reserved funds.
    /// @return amount Reserved funds.
    function reservedFunds() external view returns (uint256);

    /// @notice DAO role.
    /// @return bytes role bytes
    function DAO() external view returns (bytes32);

    /// @notice PAUSE_ROLE role.
    /// @return bytes role bytes
    function PAUSE_ROLE() external view returns (bytes32);

    /// @notice UNPAUSE_ROLE role.
    /// @return bytes role bytes
    function UNPAUSE_ROLE() external view returns (bytes32);

    /// @notice Protocol fee.
    /// @return amount Protocol fee.
    function protocolFee() external view returns (uint8);

    /// @notice Submit threshold
    /// @return threshold Submit threshold
    function submitThreshold() external view returns (uint256);

    /// @notice Total number of unique stakers ever
    /// @return amount stakers number
    function totalStakers() external view returns (uint256);

    /// @notice Daily APR for the day, reserved to 2 decimal places as a percentage, total of 5 digits  
    /// @return apr APR.
    function apr() external view returns (uint16);

    /// @notice Delegation lower bound.
    /// @return amount Delegation lower bound.
    function delegationLowerBound() external view returns (uint256);

    /// @notice Total staked.
    /// @return amount Total staked.
    function totalStaked() external view returns (uint256);

    /// @notice check address if staked ever.
    /// @param _from address to check.
    /// @return result if staked ever.
    function stakers(address _from) external view returns (bool);

    /// @notice Max submit threshold.
    /// @return threshold Max submit threshold.
    function submitMaxThreshold() external view returns (uint256);

    /// @notice UnStZETA interface
    /// @return unStZETA UnStZETA interface
    function unStZETA() external view returns (IUnStZETA);

    /// @notice Current epoch
    /// @return epoch Current epoch
    function currentEpoch() external view returns (uint256);

    /// @notice Epoch delay period
    function epochDelay() external view returns (uint256);

    /// @notice initialize function
    /// @param _dao - DAO address
    /// @param _insurance - Insurance address
    /// @param _oracle - Oracle address
    /// @param _nodeOperatorRegistry - Node operator registry contract address
    /// @param _unStZETA - UnStZETA contract address
    /// @param _currentEpoch - Current epoch
    function initialize(
        address _dao,
        address _insurance,
        address _oracle,
        address _nodeOperatorRegistry,
        address _unStZETA,
        uint256 _currentEpoch
    ) external;

    /// @notice Send funds to the StZETA contract and mint StZETA
    /// @return Amount minted
    function submit() external payable returns (uint256);

    /// @notice Function to calculate total pooled
    /// @return Total pooled
    function getTotalPooledZETA() external view returns (uint256);

    /// @notice Function to convert any ZETA to stZETA
    /// @param _amountInZETA - Amount of ZETA to convert to stZETA
    /// @return amountInStZETA - Amount of ZETA converted to stZETA
    /// @return totalStZETASupply - Total stZETA supply in contract
    /// @return totalPooledZETA - Total pooled ZETA in stake
    function convertZETAToStZETA(uint256 _amountInZETA)
        external
        view
        returns (
            uint256 amountInStZETA,
            uint256 totalStZETASupply,
            uint256 totalPooledZETA
        );

    /// @notice Function to convert any stZETA to ZETA
    /// @param _amountInStZETA - Amount of stZETA to convert to ZETA
    /// @return amountInZETA - Amount of ZETA converted
    /// @return totalStZETAAmount - Total stZETA in contract
    /// @return totalPooledZETA - Total pooled ZETA in stake
    function convertStZETAToZETA(uint256 _amountInStZETA)
        external
        view
        returns (
            uint256 amountInZETA,
            uint256 totalStZETAAmount,
            uint256 totalPooledZETA
        );
        
    /// @notice set fees.
    /// @param _daoFee the new daoFee
    /// @param _operatorsFee the new operatorsFee
    /// @param _insuranceFee the new insuranceFee
    function setFees(
        uint8 _daoFee,
        uint8 _operatorsFee,
        uint8 _insuranceFee
    ) external;

    /// @notice Function to set protocol fee
    /// @param _newProtocolFee - Insurance fee, in %
    function setProtocolFee(uint8 _newProtocolFee) external;

    /// @notice Allow setting new DaoAddress.
    /// @param _newDaoAddress new DaoAddress.
    function setDaoAddress(address _newDaoAddress) external;

    /// @notice Allow setting new OracleAddress.
    /// @param _newOracleAddress new OracleAddress.
    function setOracleAddress(address _newOracleAddress) external;

    /// @notice Allow setting new InsuranceAddress.
    /// @param _newInsuranceAddress new InsuranceAddress.
    function setInsuranceAddress(address _newInsuranceAddress) external;

    /// @notice Allow setting new version.
    /// @param _newVersion new contract version.
    function setVersion(string calldata _newVersion) external;

    /// @notice Allow setting new submit threshold.
    /// @param _newSubmitThreshold new submit threshold.
    function setSubmitThreshold(uint256 _newSubmitThreshold) external;

    /// @notice Allow setting new apr.
    /// @param _newApr new apr.
    function setApr(uint16 _newApr) external;

    /// @notice Calculate pending amount
    /// @return pendingBufferedTokens Total pending amoun
    function calculatePendingBufferedTokens() external view returns(uint256);

    /// @notice This will be included in cron job
    function delegate() external;

    /// @notice Allow setting new delegationLowerBound.
    /// @param _delegationLowerBound new delegationLowerBound.
    function setDelegationLowerBound(uint256 _delegationLowerBound) external;

    /// @notice Allow setting newNodeOperatorRegistry.
    /// @param _newNodeOperatorRegistryAddress new NodeOperatorRegistryAddress.
    function setNodeOperatorRegistry(address _newNodeOperatorRegistryAddress) external;

    /// @notice Allow setting new submit max threshold.
    /// @param _newSubmitMaxThreshold new submit threshold.
    function setSubmitMaxThreshold(uint256 _newSubmitMaxThreshold) external;
    
    /// @notice Allow setting new UnStZETA.
    /// @param _newUnStZETAAddress new UnStZETA address.
    function setUnStZETA(address _newUnStZETAAddress) external;

    /// @notice Request withdraw struct.
    /// @param amount2WithdrawFromStZETA Amount in ZETA.
    /// @param validatorNonce Validator nonce.
    /// @param requestEpoch Epoch at request.
    /// @param validatorAddress Validator address.
    struct RequestWithdraw {
        uint256 amount2WithdrawFromStZETA;
        uint256 validatorNonce;
        uint256 requestEpoch;
        address validatorAddress;
    }

    /// @notice Request withdraw query struct.
    /// @param amount Amount in ZETA.
    /// @param tokenId Token id.
    /// @param validatorNonce Validator nonce.  
    /// @param requestEpoch Epoch at request.
    /// @param validatorAddress Validator address.
    struct RequestWithdrawQuery {
        uint256 amount;
        uint256 tokenId;
        uint256 validatorNonce;
        uint256 requestEpoch;
        address validatorAddress;
    }

    /// @notice user request withdraws.
    /// @param _amount - Amount of StZETA to request withdraw
    /// @return NFT token id
    function requestWithdraw(uint256 _amount) external returns (uint256);

    /// @notice Allow setting new current epoch
    /// @param _newCurrentEpoch new CurrentEpoch.
    function setCurrentEpoch(uint256 _newCurrentEpoch) external;
    
    /// @notice Allow setting new epoch delay period
    /// @param _newEpochDelay new EpochDelay
    function setEpochDelay(uint256 _newEpochDelay) external;
    
    /// @notice Get tokenIds for a given epoch
    /// @param epoch epoch
    /// @return tokenIds tokenIds list
    function getEpochsTokenIds(uint256 epoch) external view returns (uint256[] memory);

    /// @notice Get all requestWithdraws for a given epoch
    /// @param epoch epoch
    /// @return requestWithdrawQuerys requestWithdrawsQuery list
    function getEpochsRequestWithdraws(uint256 epoch) external view returns (RequestWithdrawQuery[] memory);

    //// @notice Get all requestWithdraws
    /// @param target_address Target address
    /// @return requestWithdrawQuerys List of requestWithdraws
    function getAddressRequestWithdraws(address target_address) external view returns (RequestWithdrawQuery[] memory);

    /// @notice Get epoch for a given tokenId
    /// @param tokenId Token id
    /// @return epoch Epoch
    function getTokenIdEpoch(uint256 tokenId) external view returns (uint256);

    /// @notice Get update version on each update
    /// @return version Version
    function getUpdateVersion() external pure returns(string memory);

    /// @notice set tokenIds epoch
    /// @param tokenIds List of token ids
    /// @param targetEpoch Target epoch
    function setTokenIdsEpoch(uint256[] memory tokenIds, uint256 targetEpoch) external;

    /// @notice Receive ZETA.
    function receiveZETA() external payable;

    /// @notice Claim tokens.
    /// @param _tokenIds Token ids.
    /// @return totalAmountToClaim Amount claimed.
    function claimMultiTokens(uint256[] memory _tokenIds) external returns(uint256);

    /// @notice get the valid last epoch
    /// @return epoch Epoch
    function getValidEpoch() external view returns(uint256);

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                    EVENTS                          ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @notice Emitted on submit.
    /// @param _from from address.
    /// @param _amount Amount.
    /// @param _balanceOfStZETA Balance of stZETA.
    event SubmitEvent(address indexed _from, uint256 indexed _amount, uint256 indexed _balanceOfStZETA);

    /// @notice Emitted when new InsuranceAddress is set.
    /// @param _newInsuranceAddress the new InsuranceAddress.
    event SetInsuranceAddress(address indexed _newInsuranceAddress);

    /// @notice Emitted when new NodeOperatorRegistry is set.
    /// @param _newNodeOperatorRegistryAddress the new NodeOperatorRegistryAddress.
    event SetNodeOperatorRegistry(
        address indexed _newNodeOperatorRegistryAddress
    );

    /// @notice Emitted when new DAO is set.
    /// @param oldDaoAddress the old DAO.
    /// @param newDaoAddress the new DAO.
    event SetDaoAddress(address oldDaoAddress, address newDaoAddress);

    /// @notice Emitted when new Oracle is set.
    /// @param oldOracleAddress the old Oracle.
    /// @param newOracleAddress the new Oracle.
    event SetOracleAddress(address oldOracleAddress, address newOracleAddress);

    /// @notice Emitted when fees are set.
    /// @param daoFee the new daoFee
    /// @param operatorsFee the new operatorsFee
    /// @param insuranceFee the new insuranceFee
    event SetFees(uint256 daoFee, uint256 operatorsFee, uint256 insuranceFee);

    /// @notice Emitted when ProtocolFee is set.
    /// @param oldProtocolFee the new ProtocolFee
    /// @param newProtocolFee the new ProtocolFee
    event SetProtocolFee(uint8 oldProtocolFee, uint8 newProtocolFee);

    /// @notice Emitted when version is set.
    /// @param oldVersion old.
    /// @param newVersion new.
    event SetVersion(string oldVersion, string indexed newVersion);

    /// @notice Emitted when new submit threshold is set.
    /// @param oldSubmitThreshold old.
    /// @param newSubmitThreshold new.
    event SetSubmitThreshold(uint256 oldSubmitThreshold, uint256 indexed newSubmitThreshold);

    /// @notice Emitted when new apr is set.
    /// @param oldApr old.
    /// @param newApr new.
    event SetApr(uint16 oldApr, uint16 indexed newApr);

    /// @notice Emitted on delegate.
    /// @param _amountDelegated amount to delegate.
    /// @param _remainder remainder.
    event DelegateEvent(uint256 indexed _amountDelegated, uint256 indexed _remainder);

    /// @notice Emitted when new delegation lower bound is set.
    /// @param _delegationLowerBound the old DelegationLowerBound.
    event SetDelegationLowerBound(uint256 indexed _delegationLowerBound);

    /// @notice Emitted when new submit max threshold is set.
    /// @param oldSubmitMaxThreshold old.
    /// @param newSubmitMaxThreshold new.
    event SetSubmitMaxThreshold(uint256 oldSubmitMaxThreshold, uint256 indexed newSubmitMaxThreshold);

    /// @notice Emitted when new UnStZETA is set.
    /// @param _newUnStZETAAddress the new UnStZETAAddress.
    event SetUnStZETA(address indexed _newUnStZETAAddress);

    /// @notice Emitted when new current epoch is set.
    /// @param oldCurrentEpoch old.
    /// @param newCurrentEpoch new.
    event SetCurrentEpoch(uint256 oldCurrentEpoch, uint256 indexed newCurrentEpoch);

    /// @notice Emitted when new epoch delay is set.
    /// @param oldEpochDelay old.
    /// @param newEpochDelay new.
    event SetEpochDelay( uint256 oldEpochDelay, uint256 indexed newEpochDelay);

    /// @notice Emitted on request withdraw.
    /// @param _from from address.
    /// @param _amount amount.
    /// @param tokenId tokenId.
    /// @param _balanceOfStZETA Balance of stZETA.
    event RequestWithdrawEvent(address indexed _from, uint256 _amount, uint256 indexed tokenId, uint256 indexed _balanceOfStZETA);

    /// @notice Emitted when epoch is set for token ids.
    /// @param tokenIds List of token ids.
    /// @param targetEpoch Target epoch.
    event SetTokenIdsEpoch(uint256[] tokenIds, uint256 indexed targetEpoch);

    /// @notice Emitted on receiving ZETA.
    /// @param _from from address.
    /// @param _amount amount.
    event ReceiveZETAEvent(
        address indexed _from,
        uint256 indexed _amount
    );

    /// @notice ClaimTokens emit
    /// @param _from from address
    /// @param _id token id
    /// @param _amountClaimed amount Claimed
    /// @param _balanceOfStZETA balance of stZETA
    event ClaimTokensEvent(
        address indexed _from,
        uint256 indexed _id,
        uint256 indexed _amountClaimed,
        uint256 _balanceOfStZETA
    );
}