// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.8.19;

import "@openzeppelin/contracts-upgradeable/token/ERC20/ERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/IERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/token/ERC20/utils/SafeERC20Upgradeable.sol";
import "@openzeppelin/contracts-upgradeable/security/PausableUpgradeable.sol";

import "./interfaces/IStZETA.sol";
import "./interfaces/INodeOperatorRegistry.sol";
import "./interfaces/IValidatorOperator.sol";
import "./interfaces/IUnStZETA.sol";

contract StZETA is
    IStZETA,
    ERC20Upgradeable,
    AccessControlUpgradeable,
    PausableUpgradeable
{
    using SafeERC20Upgradeable for IERC20Upgradeable;

    /// @notice All roles
    bytes32 public constant override DAO = keccak256("ZETAEARN_DAO");
    bytes32 public constant ORACLE_ROLE = keccak256("ZETAEARN_ORACLE");
    bytes32 public constant override PAUSE_ROLE = keccak256("ZETAEARN_PAUSE_OPERATOR");
    bytes32 public constant override UNPAUSE_ROLE = keccak256("ZETAEARN_UNPAUSE_OPERATOR");

    /// @notice Fee distribution. Not Use Now.
    FeeDistribution public override entityFees;

    /// @notice Contract version
    string public override version;

    /// @notice DAO address
    address public override dao;

    /// @notice Oracle address
    address public override oracle;

    /// @notice Insurance address. Not Use Now.
    address public override insurance;

    /// @notice Node Operator Registry contract interface
    INodeOperatorRegistry public override nodeOperatorRegistry;

    /// @notice Total buffered ZETA in the contract
    uint256 public override totalBuffered;

    /// @notice Reserved funds in ZETA
    uint256 public override reservedFunds;

    /// @notice Protocol fee
    uint8 public override protocolFee;

    /// @notice Submission threshold
    uint256 public override submitThreshold;

    /// @notice Total number of unique stakers
    uint256 public override totalStakers;

    /// @notice Daily annual percentage rate (APR), with two decimal places, represented as a percentage with a total of 5 digits
    uint16 public override apr;

    /// @notice Delegation lower bound
    uint256 public override delegationLowerBound;

    /// @notice All users who have staked ever
    mapping(address => bool) private _stakers;

    // @notice These state variables are used to mark entry and exit of contract functions
    uint256 private constant _NOT_ENTERED = 1;
    uint256 private constant _ENTERED = 2;
    uint256 private _status;

    // @notice Used for executing recovery once, NOT USE NOW
    bool private recovered;

    /// @notice Maximum submission threshold
    uint256 public override submitMaxThreshold;

    /// @notice UnStZETA interface
    IUnStZETA public override unStZETA;

    /// @notice Current epoch
    uint256 public override currentEpoch;

    /// @notice Epoch delay period
    uint256 public override epochDelay;

    /// @notice Mapping of token to Array RequestWithdraw
    mapping(uint256 => RequestWithdraw[]) public token2WithdrawRequests;

    /// @notice Token IDs for a specific epoch
    mapping(uint256 => uint256[]) public epochsTokenIds;

    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                   Functions                        ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @notice Prevents reentrancy attacks
    modifier nonReentrant() {
        _nonReentrant();
        _status = _ENTERED;
        _;
        _status = _NOT_ENTERED;
    }

    /// @notice initialize function
    /// @param _dao - Address of the DAO
    /// @param _insurance - Address of the insurance contract
    /// @param _oracle - Address of the oracle
    /// @param _nodeOperatorRegistry - Address of the node operator registry contract
    /// @param _unStZETA - Address of the UnStZETA contract
    /// @param _currentEpoch - Current epoch
    function initialize(
        address _dao,
        address _insurance,
        address _oracle,
        address _nodeOperatorRegistry,
        address _unStZETA,
        uint256 _currentEpoch
    ) external override initializer {
        __AccessControl_init();
        __Pausable_init();
        __ERC20_init("Staked ZETA", "stZETA");

        // Set roles
        _grantRole(DEFAULT_ADMIN_ROLE, msg.sender);
        _grantRole(DAO, _dao);
        _grantRole(ORACLE_ROLE, _oracle);
        _grantRole(PAUSE_ROLE, msg.sender);
        _grantRole(UNPAUSE_ROLE, _dao);

        // Set addresses
        dao = _dao;
        insurance = _insurance;
        oracle = _oracle;
        nodeOperatorRegistry = INodeOperatorRegistry(_nodeOperatorRegistry);
        unStZETA = IUnStZETA(_unStZETA);

        // Set fee distribution
        entityFees = FeeDistribution(25, 50, 25);
        // Set threshold
        submitThreshold = 10 ** 10;
        // Set maximum submit threshold
        submitMaxThreshold = 10 ** 34;
        // Set protocol fee
        protocolFee = 10;
        // Set delegation lower bound
        delegationLowerBound = 0;
        // Set current epoch
        currentEpoch = _currentEpoch;
        // Set epoch delay
        epochDelay = 5;
        // version number
        version = "1.0.5";
    }

    /// @notice Check if an address has ever staked
    function stakers(address _from) external view override returns (bool){
        return _stakers[_from];
    }

    /// @notice Send funds to the StZETA contract and mint StZETA tokens
    /// @return The amount of StZETA tokens minted
    function submit()
        external
        override
        payable
        whenNotPaused
        nonReentrant
        returns (uint256) {
        uint _amount = msg.value;
        _require(_amount >= submitThreshold, "Invalid amount");
        _require(_amount <= submitMaxThreshold, "Invalid amount");

        // Calculate the amount of stZETA tokens to mint based on the current exchange rate
        (uint256 amountToMint,,) = convertZETAToStZETA(_amount);

        // Check if the amount of stZETA tokens to mint is greater than 0
        _require(amountToMint > 0, "Mint ZERO");

        // Mint stZETA tokens
        _mint(msg.sender, amountToMint);

        // Update totalBuffered
        totalBuffered += _amount;

        // update stakers
        if (!_stakers[msg.sender]) {
            _stakers[msg.sender] = true;
        }

        // Emit the SubmitEvent event
        emit SubmitEvent(msg.sender, _amount, balanceOf(msg.sender));

        // Return the amount of stZETA tokens minted
        return amountToMint;
    }

    /// @notice Function to convert any ZETA to stZETA
    /// @param _amountInZETA - Amount of ZETA to convert to stZETA
    /// @return amountInStZETA - Amount of ZETA converted to stZETA
    /// @return totalStZETASupply - Total stZETA supply in contract
    /// @return totalPooledZETA - Total pooled ZETA in stake
    function convertZETAToStZETA(uint256 _amountInZETA)
        public
        view
        override
        returns (
            uint256 amountInStZETA,
            uint256 totalStZETASupply,
            uint256 totalPooledZETA
        ) {
        totalStZETASupply = totalSupply();
        totalPooledZETA = getTotalPooledZETA();
        return (
            _convertZETAToStZETA(_amountInZETA, totalPooledZETA),
            totalStZETASupply,
            totalPooledZETA
        );
    }

    /// @notice Function to convert any stZETA to ZETA
    /// @param _amountInStZETA - Amount of stZETA to convert to ZETA
    /// @return amountInZETA - Amount of ZETA converted
    /// @return totalStZETAAmount - Total stZETA in contract
    /// @return totalPooledZETA - Total pooled ZETA in stake
    function convertStZETAToZETA(uint256 _amountInStZETA)
        external
        view
        override
        returns (
            uint256 amountInZETA,
            uint256 totalStZETAAmount,
            uint256 totalPooledZETA
        ) {
        totalStZETAAmount = totalSupply();
        totalPooledZETA = getTotalPooledZETA();
        return (
            _convertStZETAToZETA(_amountInStZETA, totalPooledZETA),
            totalStZETAAmount,
            totalPooledZETA
        );
    }

    /// @notice get total pooled ZETA
    /// @return Total pooled ZETA
    function getTotalPooledZETA() public view override returns (uint256) {
        // Get the total amount of ZETA staked
        uint256 staked = totalStaked();
        // Calculate the total amount of ZETA in the pool
        return _getTotalPooledZETA(staked);
    }

    /// @notice Total staked.
    /// @return amount Total staked.
    function totalStaked() public view override returns (uint256){
        // This is the final total stake of ZETA to be returned
        uint256 totalStake;
        // Get all node operators
        INodeOperatorRegistry.ValidatorData[] memory nodeOperators = nodeOperatorRegistry.listWithdrawNodeOperators();

        // Calculate the total stake of all node operators
        for (uint256 i = 0; i < nodeOperators.length; i++) {
            // Get the validator operator
            IValidatorOperator validatorOperator = IValidatorOperator(nodeOperators[i].operatorAddress);
            // Accumulate the stake amount
            totalStake += validatorOperator.totalStake();
        }

        return totalStake;
    }


    /// @notice Calculate the total amount of ZETA based on the total stake
    function _getTotalPooledZETA(uint256 _totalStaked)
        private
        view
        returns (uint256) {
        // This is divided into 4 parts
        // 1. totalstaked: The total amount of ZETA staked
        // 2. totalBuffered: The total amount of ZETA buffered in the contract
        // 3. calculatePendingBufferedTokens(): Calculate the pending amount when validator exist. Not Use Now.
        // 4. reservedFunds: The reserved funds in the contract
        return
            _totalStaked +
            totalBuffered +
            calculatePendingBufferedTokens() -
            reservedFunds;
    }

    /// @notice Calculate the pending amount when validator exist. Not Use Now.
    /// @return pendingBufferedTokens The total amount pending
    function calculatePendingBufferedTokens()
        public
        pure
        override
        returns (uint256 pendingBufferedTokens) {
        // Not Use Now.
        return 0;
    }

    /// @notice convert ZETA to stZETA
    /// @param _ZETAAmount - The amount of ZETA to convert to stZETA.
    /// @return amountInStZETA - The amount of stZETA to be converted.
    function _convertZETAToStZETA(uint256 _ZETAAmount, uint256 _totalPooledZETA) 
        private view returns (uint256) {
        uint256 totalStZETASupply = totalSupply();
        // This is mainly for handling the initial case
        totalStZETASupply = totalStZETASupply == 0 ? 1 : totalStZETASupply;
        _totalPooledZETA = _totalPooledZETA == 0 ? 1 : _totalPooledZETA;

        // The core calculation part
        uint256 amountInStZETA = (_ZETAAmount * totalStZETASupply) /
            _totalPooledZETA;

        return amountInStZETA;
    }

    /// @notice convert stZETA to ZETA
    /// @param _stZETAAmount - The amount of stZETA to convert to ZETA.
    /// @return amountInZETA - The amount of ZETA to be converted.
    function _convertStZETAToZETA(uint256 _stZETAAmount, uint256 _totalPooledZETA) private view returns (uint256) {
        uint256 totalStZETASupply = totalSupply();
        // This is mainly for handling the initial case
        totalStZETASupply = totalStZETASupply == 0 ? 1 : totalStZETASupply;
        _totalPooledZETA = _totalPooledZETA == 0 ? 1 : _totalPooledZETA;
        // The core calculation part
        uint256 amountInZETA = (_stZETAAmount * _totalPooledZETA) /
            totalStZETASupply;
        
        return amountInZETA;
    }

    /// @notice This is included in the cron job and can only be called by ORACLE_ROLE.
    function delegate() external override whenNotPaused nonReentrant onlyRole(ORACLE_ROLE) {
        // Store totalBuffered and reservedFunds temporarily
        uint256 ltotalBuffered = totalBuffered;
        uint256 lreservedFunds = reservedFunds;
        // Check if totalBuffered is greater than delegationLowerBound + reservedFunds
        _require(
            ltotalBuffered > delegationLowerBound + lreservedFunds,
            "Amount lower than minimum"
        );
        // Check if the balance of the current contract is greater than totalBuffered
        _require(
            address(this).balance >= ltotalBuffered,
            "Balance lower than Buffered"
        );

        // The total amount to delegate is equal to totalBuffered - reservedFunds
        uint256 amountToDelegate = ltotalBuffered - lreservedFunds;
        
        // Get the stake information of all active node operators
        (
            INodeOperatorRegistry.ValidatorData[] memory validators,
            ,
            uint256[] memory operatorRatios,
            uint256 totalRatio,
        ) = nodeOperatorRegistry.getValidatorsDelegationAmount();
        // Get the length of validators
        uint256 validatorsOperatorLength = validators.length;
        // Remainder, the remaining amount of money
        uint256 remainder;
        // Actual delegated amount
        uint256 amountDelegated;
        // Temporary variable for the amount delegated by the validator used
        uint256 validatorAmountDelegated;
        // Iterate through all validators
        for (uint256 i = 0; i < validatorsOperatorLength; i++) {
            // Get the current validator's ratio
            uint256 operatorRatio = operatorRatios[i];
            // Calculate the delegated amount for the current validator
            validatorAmountDelegated = (amountToDelegate * operatorRatio) / totalRatio;
            // If the delegated amount for the current validator is 0, skip
            if (validatorAmountDelegated == 0) continue;
            // Delegate the tokens
            IValidatorOperator(validators[i].operatorAddress).delegate{value: validatorAmountDelegated}();
            // Update the actual delegated amount
            amountDelegated += validatorAmountDelegated;
        }
        // Remainder, the remaining amount of money
        remainder = amountToDelegate - amountDelegated;
        // update totalBuffered
        totalBuffered = remainder + lreservedFunds;
        // Emit the event
        emit DelegateEvent(amountDelegated, remainder);
    }

    /// @notice user request withdraws.
    /// @param _amount - Amount of StZETA to request withdraw
    /// @return NFT token id
    function requestWithdraw(uint256 _amount)
        external
        override
        whenNotPaused
        nonReentrant
        returns (uint256) {
        // Check if the amount of stZETA is greater than 0 and if the sender's balance is greater than or equal to the amount
        _require(
            _amount > 0 && balanceOf(msg.sender) >= _amount,
            "Invalid amount"
        );
        // NFT id
        uint256 tokenId;

        // Create a separate scope to resolve "stack too deep" error
        {
            // Get the total amount of ZETA in the pool, including staked, buffered, reserved funds, and future withdrawal requests
            uint256 totalPooledZETA = getTotalPooledZETA();
            // Convert the amount of stZETA to ZETA
            uint256 totalAmount2WithdrawInZETA = _convertStZETAToZETA(
                _amount, totalPooledZETA
            );
            // Check if the amount of ZETA to withdraw is greater than 0
            _require(totalAmount2WithdrawInZETA > 0, "Withdraw 0 Zeta");
            // Get validators
            (
                INodeOperatorRegistry.ValidatorData[] memory activeNodeOperators,
                uint256 totalDelegated,
                ,
                ,
                ,
                uint256 totalValidatorsToWithdrawFrom,
                uint256 minStakeAmount
            ) = nodeOperatorRegistry.getValidatorsRequestWithdraw(totalAmount2WithdrawInZETA);
            
            {
                // Temporary variables for totalBuffered and reservedFunds
                uint256 totalBufferedMem = totalBuffered;
                uint256 reservedFundsMem = reservedFunds;
                // Local available balance
                uint256 localActiveBalance = totalBufferedMem > reservedFundsMem
                    ? totalBufferedMem - reservedFundsMem
                    : 0;
                uint256 liquidity = totalDelegated + localActiveBalance;
                _require(
                    liquidity >= totalAmount2WithdrawInZETA,
                    "Too much withdraw"
                );
            }

            // Added a scope to fix "stack too deep" error
            {
                // Temporary variable to store the remaining amount of ZETA to withdraw
                uint256 currentAmount2WithdrawInZETA = totalAmount2WithdrawInZETA;
                // Create an NFT for the user
                tokenId = unStZETA.mint(msg.sender);
                // If totalDelegated is not 0 and minStakeAmount is not 0, meaning there are delegates
                if ((totalDelegated != 0) && (minStakeAmount * totalValidatorsToWithdrawFrom) != 0) {
                    // Currently only considering balanced state
                    currentAmount2WithdrawInZETA = _requestWithdrawBalanced(
                        tokenId,
                        activeNodeOperators,
                        totalAmount2WithdrawInZETA,
                        totalValidatorsToWithdrawFrom,
                        totalDelegated,
                        currentAmount2WithdrawInZETA,
                        minStakeAmount
                    );
                }
                // For the part greater than minAmount * totalValidatorsToWithdrawFrom, use reservedFunds
                if (totalAmount2WithdrawInZETA > (minStakeAmount * totalValidatorsToWithdrawFrom)) {
                    uint256 amountGap = totalAmount2WithdrawInZETA - (minStakeAmount * totalValidatorsToWithdrawFrom);
                    token2WithdrawRequests[tokenId].push(
                        RequestWithdraw(
                            amountGap,
                            0,
                            currentEpoch + epochDelay,
                            address(0)
                        )
                    );
                    // update reservedFunds
                    reservedFunds += amountGap;
                    currentAmount2WithdrawInZETA = 0;
                }
            }
            // Burn the user's stZETA
            _burn(msg.sender, _amount);
        }
        // update epochsTokenIds
        epochsTokenIds[currentEpoch+epochDelay].push(tokenId);
        emit RequestWithdrawEvent(msg.sender, _amount, tokenId, balanceOf(msg.sender));

        return tokenId;
    }

    /// @notice Request withdrawal when the system is balanced
    /// @param tokenId - NFT token id
    /// @param activeNodeOperators - Active node operators
    /// @param totalAmount2WithdrawInZETA - Total amount of ZETA to withdraw
    /// @param totalValidatorsToWithdrawFrom - Total number of validators to withdraw from
    /// @param totalDelegated - Total amount of delegated ZETA
    /// @param currentAmount2WithdrawInZETA - Current amount of ZETA to withdraw
    /// @param minStakeAmount - Minimum stake amount for validators
    function _requestWithdrawBalanced(
        uint256 tokenId,
        INodeOperatorRegistry.ValidatorData[] memory activeNodeOperators,
        uint256 totalAmount2WithdrawInZETA,
        uint256 totalValidatorsToWithdrawFrom,
        uint256 totalDelegated,
        uint256 currentAmount2WithdrawInZETA,
        uint256 minStakeAmount
    ) private returns (uint256) {
        // Calculate the amount of ZETA to withdraw from each node directly based on minStakeAmount
        uint256 totalAmount = min(minStakeAmount * totalValidatorsToWithdrawFrom, totalAmount2WithdrawInZETA);
        totalAmount = min(totalDelegated, totalAmount);
        // The amount of ZETA to withdraw from each validator
        uint256 amount2WithdrawFromValidator = totalAmount / totalValidatorsToWithdrawFrom;
        // Iterate over validators
        for (uint256 idx = 0; idx < totalValidatorsToWithdrawFrom; idx++) {
            // Get the validator
            IValidatorOperator validatorOperator = IValidatorOperator(activeNodeOperators[idx].operatorAddress);
            // Require the validator's stake amount
            _require(validatorOperator.totalStake() >= amount2WithdrawFromValidator, "stake too low");
            // Call the validator's withdraw method
            currentAmount2WithdrawInZETA = _requestWithdraw(
                tokenId,
                validatorOperator,
                amount2WithdrawFromValidator,
                currentAmount2WithdrawInZETA
            );
        }
        // Return the remaining amount
        return currentAmount2WithdrawInZETA;
    }

    /// @notice Call the unstake method of the validator
    /// @param tokenId - NFT token id
    /// @param validatorOperator - validatorOperator contract interface
    /// @param amount2WithdrawFromValidator - The amount of ZETA to withdraw
    /// @param currentAmount2WithdrawInZETA - The current total amount of ZETA to withdraw
    /// @return The remaining amount of ZETA to withdraw
    function _requestWithdraw(
        uint256 tokenId,
        IValidatorOperator validatorOperator,
        uint256 amount2WithdrawFromValidator,
        uint256 currentAmount2WithdrawInZETA
    ) private returns (uint256) {
        // Unstake and update the unbond content inside the validator
        validatorOperator.unStake(amount2WithdrawFromValidator);
        // update token2WithdrawRequests
        token2WithdrawRequests[tokenId].push(
            RequestWithdraw(
                0,
                validatorOperator.getUnbondNonces(address(this)),
                currentEpoch + epochDelay,
                address(validatorOperator)
            )
        );
        // Update the current amount
        currentAmount2WithdrawInZETA -= amount2WithdrawFromValidator;
        // Return the remaining amount
        return currentAmount2WithdrawInZETA;
    }

    /**
     * @dev Hook that is called before any transfer of tokens. This includes
     * minting and burning.
     *
     * Calling conditions:
     *
     * - when `from` and `to` are both non-zero, `amount` of ``from``'s tokens
     * will be transferred to `to`.
     * - when `from` is zero, `amount` tokens will be minted for `to`.
     * - when `to` is zero, `amount` of ``from``'s tokens will be burned.
     * - `from` and `to` are never both zero.
     *
     * To learn more about hooks, head to xref:ROOT:extending-contracts.adoc#using-hooks[Using Hooks].
     */
    function _beforeTokenTransfer(address, address to, uint256) internal override {
        // update stakers
        if (!_stakers[to]) {
            totalStakers += 1;
        }
    }

    /// @notice Get the tokenIds for a specific epoch
    /// @param epoch Epoch
    /// @return tokenIds
    function getEpochsTokenIds(uint256 epoch) external view override returns (uint256[] memory) {
        return epochsTokenIds[epoch];
    }

    /// @notice Get all requestWithdraw information for a specific epoch
    /// @param epoch Epoch
    /// @return requestWithdrawsQuerys requestWithdrawQuery list
    function getEpochsRequestWithdraws(uint256 epoch) 
        external view override returns (RequestWithdrawQuery[] memory) {
        // get all tokenIds
        uint256[] memory tokenIds = epochsTokenIds[epoch];
        return _getRequestWithdrawQuerysByTokenIds(tokenIds);
    }

    /// @notice Get all requestWithdraw information for a specific address
    /// @param target_address Target address
    /// @return requestWithdrawsQuerys requestWithdrawQuery list
    function getAddressRequestWithdraws(address target_address) 
        external view override returns (RequestWithdrawQuery[] memory) {
        // get all tokenIds
        uint256[] memory tokenIds = unStZETA.getOwnedTokens(target_address);
        return _getRequestWithdrawQuerysByTokenIds(tokenIds);
    }

    /// @notice Get the requestWithdrawQuery list corresponding to a list of tokenIds
    /// @param tokenIds List of tokenIds
    /// @return requestWithdrawQuerys requestWithdrawQuery list
    function _getRequestWithdrawQuerysByTokenIds(uint256[] memory tokenIds) 
        internal view returns (RequestWithdrawQuery[] memory) {
        // Get the total length
        uint256 tokenIdsLength = tokenIds.length;
        uint256 tokenId;
        uint256 requestTotalLength;
        RequestWithdraw memory requestWithdrawItem;
        for (uint256 i = 0; i < tokenIdsLength; i++) {
            tokenId = tokenIds[i];
            requestTotalLength += token2WithdrawRequests[tokenId].length;
        }
        IValidatorOperator.DelegatorUnbond memory delegatorUnbond;
        RequestWithdrawQuery[] memory requestWithdrawQuerys = new RequestWithdrawQuery[](requestTotalLength);
        uint256 requestWithdrawQuerysIndex = 0;
        // Iterate through all tokenIds
        for (uint256 i = 0; i < tokenIdsLength; i++) {
            tokenId = tokenIds[i];
            // Iterate through all requests
            for (uint256 j = 0; j < token2WithdrawRequests[tokenId].length; j++) {
                requestWithdrawItem = token2WithdrawRequests[tokenId][j];
                // If it is reserved
                if (requestWithdrawItem.validatorAddress == address(0)) {
                    requestWithdrawQuerys[requestWithdrawQuerysIndex] = RequestWithdrawQuery(
                        requestWithdrawItem.amount2WithdrawFromStZETA,
                        tokenId,
                        requestWithdrawItem.validatorNonce,
                        requestWithdrawItem.requestEpoch,
                        requestWithdrawItem.validatorAddress
                    );
                } else {
                    // Get the unbond information of the validator
                    delegatorUnbond = IValidatorOperator(requestWithdrawItem.validatorAddress).getDelegatorUnbond(address(this), requestWithdrawItem.validatorNonce);
                    requestWithdrawQuerys[requestWithdrawQuerysIndex] = RequestWithdrawQuery(
                        delegatorUnbond.amount,
                        tokenId,
                        requestWithdrawItem.validatorNonce,
                        delegatorUnbond.withdrawEpoch,
                        requestWithdrawItem.validatorAddress
                    );
                }
                requestWithdrawQuerysIndex += 1;
            }
        }
        return requestWithdrawQuerys;
    }

    /// @notice Get the epoch corresponding to a specific tokenId
    /// @param tokenId The target tokenId
    /// @return epoch Epoch
    function getTokenIdEpoch(uint256 tokenId) 
        external view override returns (uint256) {
        return token2WithdrawRequests[tokenId][0].requestEpoch;
    }

    /// @notice Get the requestWithdraw information corresponding to a specific tokenId
    /// @param tokenId The target tokenId
    /// @return requestWithdraws requestWithdraw list
    function getTokenIdRequestWithdraws(uint256 tokenId) 
        external view returns (RequestWithdraw[] memory) {
        return token2WithdrawRequests[tokenId];
    }

    /// @notice Receive ZETA
    function receiveZETA() external payable override {
        // Check if msg.value is greater than 0
        _require(msg.value > 0, "Invalid amount");
        // Emit event
        emit ReceiveZETAEvent(msg.sender, msg.value);
    }

    /// @notice min function
    /// @param _valueA - valueA
    /// @param _valueB - valueB
    /// @return min value
    function min(uint256 _valueA, uint256 _valueB) private pure returns(uint256) {
        return _valueA > _valueB ? _valueB : _valueA;
    }

    /// @notice Ensure non-reentrancy
    function _nonReentrant() private view {
        _require(_status != _ENTERED, "ReentrancyGuard: reentrant call");
    }

    /// @notice Ensure condition is met
    /// @param _condition - condition
    /// @param _message - error message
    function _require(bool _condition, string memory _message) private pure {
        require(_condition, _message);
    }

    /// @notice Pauses the contract
    function pause() external onlyRole(PAUSE_ROLE) {
        _pause();
    }

    /// @notice Unpauses the contract
    function unpause() external onlyRole(UNPAUSE_ROLE) {
        _unpause();
    }

    /// @notice Get the version of each update
    /// @return version version
    function getUpdateVersion() external pure override returns(string memory) {
        return "1.0.5";
    }

    /// @notice claim multi tokens
    /// @param _tokenIds - the tokenIds of the NFT
    /// @return totalAmountToClaim - the total amount of ZETA to claim
    function claimMultiTokens(uint256[] memory _tokenIds) 
        external override whenNotPaused nonReentrant returns(uint256) {
        uint256 length = _tokenIds.length;
        uint256 totalAmountToClaim;
        for (uint256 idx = 0; idx < length; idx++) {
            totalAmountToClaim += _claimTokens(_tokenIds[idx]);
        }

        return totalAmountToClaim;
    }
    
    /// @notice Claims tokens
    /// @param _tokenId - the tokenId of the NFT
    /// @return amountToClaim - the amount to claim
    function _claimTokens(uint256 _tokenId) private returns(uint256) {
        // Check if msg.sender is the owner of the tokenId
        _require(unStZETA.isApprovedOrOwner(msg.sender, _tokenId), "Not owner");
        // List of withdrawal requests to be processed
        RequestWithdraw[] memory usersRequest = token2WithdrawRequests[_tokenId];
        // Check if the current epoch is greater than or equal to the user's request epoch
        _require(currentEpoch >= usersRequest[0].requestEpoch, "Epoch early");
        // Burn the user's NFT
        unStZETA.burn(_tokenId);
        // Delete the user's withdrawal request
        delete token2WithdrawRequests[_tokenId];
        // Remove this tokenId from the tokenIds in the epoch
        _deleteEpochsTokenId(usersRequest[0].requestEpoch, _tokenId);

        uint256 length = usersRequest.length;
        uint256 amountToClaim;
        uint256 _amountToClaim;

        // Iterate the requests
        for (uint256 idx = 0; idx < length; idx++) {
            // If the validator address is not equal to 0, it means it is extracted from the validator
            if (usersRequest[idx].validatorAddress != address(0)) {
                // Extract based on the unbond information
                _amountToClaim = unstakeClaimTokens(
                    usersRequest[idx].validatorAddress,
                    usersRequest[idx].validatorNonce
                );
                amountToClaim += _amountToClaim;
            } else {
                // Otherwise, it means it is to be extracted from the reserved funds
                _amountToClaim = usersRequest[idx].amount2WithdrawFromStZETA;
                // Update state variables
                reservedFunds -= _amountToClaim;
                totalBuffered -= _amountToClaim;
                // Add the amount to be withdrawn to amountToClaim
                amountToClaim += _amountToClaim;
            }
        }
        // Transfer to the user
        (bool success, ) = payable(msg.sender).call{value: amountToClaim}("");
        // Check if the transfer is successful
        _require(success, "Transfer failed");
        // Emit the ClaimTokensEvent event
        emit ClaimTokensEvent(msg.sender, _tokenId, amountToClaim, balanceOf(msg.sender));

        return amountToClaim;
    }

    /// @notice delete target tokenId from epochsTokenIds
    /// @param epoch - epoch
    /// @param tokenId - tokenId
    function _deleteEpochsTokenId(uint256 epoch, uint256 tokenId) internal {
        uint256[] storage tokenIds = epochsTokenIds[epoch];
        uint256 tokenIdsLength = tokenIds.length;
        for (uint256 i = 0; i < tokenIdsLength; i++) {
            if (tokenIds[i] == tokenId) {
                tokenIds[i] = tokenIds[tokenIdsLength - 1];
                tokenIds.pop();
                break;
            }
        }
    }

    /// @notice unstake claim from validator
    /// @param _validatorAddress - validator address
    /// @param _unbondNonce - unbond nonce
    /// @return amount the amount of funds transferred back
    function unstakeClaimTokens(address _validatorAddress, uint256 _unbondNonce) private returns(uint256) {
        // according to unbond information to claim, return the amount of funds transferred back
        return IValidatorOperator(_validatorAddress).unstakeClaimTokens(_unbondNonce);
    }

    /// @notice get the valid last epoch
    /// @return epoch - epoch
    function getValidEpoch() external view returns(uint256) {
        // Iterate through all validator
        uint256 smallestEpoch = type(uint256).max;
        INodeOperatorRegistry.ValidatorData[] memory validators = nodeOperatorRegistry.listDelegatedNodeOperators();
        uint256 validatorsLength = validators.length;
        uint256 lastEpochFinishedUnbond;
        for (uint256 idx = 0; idx < validatorsLength; idx++) {
            lastEpochFinishedUnbond = IValidatorOperator(validators[idx].operatorAddress).lastEpochFinishedUnbond();
            if (lastEpochFinishedUnbond < smallestEpoch) {
                smallestEpoch = lastEpochFinishedUnbond;
            }
        }
        return smallestEpoch;
    }


    ////////////////////////////////////////////////////////////
    /////                                                    ///
    /////                    Setters                         ///
    /////                                                    ///
    ////////////////////////////////////////////////////////////

    /// @notice Set new fees
    /// @notice Only DAO role can call this function.
    /// @param _daoFee - DAO fee in %
    /// @param _operatorsFee - Operator fees in %
    /// @param _insuranceFee - Insurance fee in %
    function setFees(uint8 _daoFee, uint8 _operatorsFee, uint8 _insuranceFee) external override onlyRole(DAO) {
        // Check if the sum of fees is equal to 100
        _require(
            _daoFee + _operatorsFee + _insuranceFee == 100,
            "sum(fee)!=100"
        );
        entityFees.dao = _daoFee;
        entityFees.operators = _operatorsFee;
        entityFees.insurance = _insuranceFee;

        emit SetFees(_daoFee, _operatorsFee, _insuranceFee);
    }

    /// @notice Allow setting new DaoAddress.
    /// @param _newDaoAddress new DaoAddress.
    function setDaoAddress(address _newDaoAddress) external override onlyRole(DAO) {
        address oldDAOAddress = dao;
        dao = _newDaoAddress;
        emit SetDaoAddress(oldDAOAddress, _newDaoAddress);
    }

    /// @notice Allow setting new OracleAddress.
    /// @notice Only the DAO can call this function.
    /// @param _newOracleAddress new OracleAddress.
    function setOracleAddress(address _newOracleAddress) external override onlyRole(DAO) {
        address oldOracleAddress = oracle;
        oracle = _newOracleAddress;
        emit SetOracleAddress(oldOracleAddress, _newOracleAddress);
    }

    /// @notice Set a new protocol fee.
    /// @param _newProtocolFee - The new protocol fee, in percentage.
    function setProtocolFee(uint8 _newProtocolFee)
        external
        override
        onlyRole(DAO) {
        // Check if the protocol fee is greater than 0 and less than or equal to 100
        _require(
            _newProtocolFee > 0 && _newProtocolFee <= 100,
            "Invalid protocol fee"
        );
        uint8 oldProtocolFee = protocolFee;
        protocolFee = _newProtocolFee;

        emit SetProtocolFee(oldProtocolFee, _newProtocolFee);
    }

    /// @notice Allow setting new InsuranceAddress.
    /// @notice Only the DAO can call this function.
    /// @param _newInsuranceAddress new InsuranceAddress.
    function setInsuranceAddress(address _newInsuranceAddress)
        external
        override
        onlyRole(DAO) {
        insurance = _newInsuranceAddress;
        emit SetInsuranceAddress(_newInsuranceAddress);
    }

    /// @notice Set a new version.
    /// @param _newVersion - The new contract version.
    function setVersion(string memory _newVersion)
        external
        override
        onlyRole(DAO) {
        emit SetVersion(version, _newVersion);
        version = _newVersion;
    }

    /// @notice Set a new submit threshold.
    /// @notice Only the DAO role can call this function.
    /// @param _newSubmitThreshold - The new submit threshold.
    function setSubmitThreshold(uint256 _newSubmitThreshold) 
        external
        override
        onlyRole(DAO) {
        uint256 oldSubmitThreshold = submitThreshold;
        submitThreshold = _newSubmitThreshold;
        emit SetSubmitThreshold(oldSubmitThreshold, _newSubmitThreshold);
    }

    /// @notice Set a new APR.
    /// @notice Only the ORACLE_ROLE can call this function.
    /// @param _newApr - The new APR.
    function setApr(uint16 _newApr) 
        external
        override
        onlyRole(ORACLE_ROLE) {
        uint16 oldApr = apr;
        apr = _newApr;
        emit SetApr(oldApr, _newApr);
    }

    // @notice This function is used to set a new delegation lower bound.
    /// @notice Only the DAO can call this function.
    /// @param _delegationLowerBound - The new delegation lower bound.
    function setDelegationLowerBound(uint256 _delegationLowerBound)
        external
        override
        onlyRole(DAO) {
        delegationLowerBound = _delegationLowerBound;
        emit SetDelegationLowerBound(_delegationLowerBound);
    }

    /// @notice Allow setting newNodeOperatorRegistry.
    /// @notice Only the DAO can call this function.
    /// @param _newNodeOperatorRegistryAddress new NodeOperatorRegistryAddress.
    function setNodeOperatorRegistry(address _newNodeOperatorRegistryAddress)
        external
        override
        onlyRole(DAO) {
        nodeOperatorRegistry = INodeOperatorRegistry(_newNodeOperatorRegistryAddress);
        emit SetNodeOperatorRegistry(_newNodeOperatorRegistryAddress);
    }

    /// @notice Set a new submit max threshold.
    /// @notice Only the DAO can call this function.
    /// @param _newSubmitMaxThreshold - The new submit max threshold.
    function setSubmitMaxThreshold(uint256 _newSubmitMaxThreshold) 
        external
        override
        onlyRole(DAO) {
        uint256 oldSubmitMaxThreshold = submitMaxThreshold;
        submitMaxThreshold = _newSubmitMaxThreshold;
        emit SetSubmitMaxThreshold(oldSubmitMaxThreshold, _newSubmitMaxThreshold);
    }

    /// @notice Allow setting new UnStZETA.
    /// @notice Only the DAO can call this function.
    /// @param _newUnStZETAAddress new UnStZETA address.
    function setUnStZETA(address _newUnStZETAAddress)
        external
        override
        onlyRole(DAO) {
        unStZETA = IUnStZETA(_newUnStZETAAddress);
        emit SetUnStZETA(_newUnStZETAAddress);
    }

    /// @notice Allows setting a new current epoch
    /// @notice Only the ORACLE_ROLE role can call this function.
    /// @param _newCurrentEpoch new CurrentEpoch.
    function setCurrentEpoch(uint256 _newCurrentEpoch) 
        external
        override
        onlyRole(ORACLE_ROLE) {
        uint256 oldCurrentEpoch = currentEpoch;
        currentEpoch = _newCurrentEpoch;
        emit SetCurrentEpoch(oldCurrentEpoch, _newCurrentEpoch);
    }

    /// @notice Allows setting a new epoch delay
    /// @notice Only the DAO role can call this function.
    /// @param _newEpochDelay new EpochDelay
    function setEpochDelay(uint256 _newEpochDelay)
        external
        override
        onlyRole(DAO) {
        uint256 oldEpochDelay = epochDelay;
        epochDelay = _newEpochDelay;
        emit SetEpochDelay(oldEpochDelay, _newEpochDelay);
    }

    /// @notice set tokenIds epoch
    /// @param tokenIds List of token ids
    /// @param targetEpoch Target epoch
    function setTokenIdsEpoch(uint256[] memory tokenIds, uint256 targetEpoch)
        external override onlyRole(DAO) {
        // Iterate through all tokenIds
        for (uint256 i = 0; i < tokenIds.length; i++) {
            // Iterate through all requests
            for (uint256 j = 0; j < token2WithdrawRequests[tokenIds[i]].length; j++) {
                token2WithdrawRequests[tokenIds[i]][j].requestEpoch = targetEpoch;
            }
        }
        emit SetTokenIdsEpoch(tokenIds, targetEpoch);
    }

}