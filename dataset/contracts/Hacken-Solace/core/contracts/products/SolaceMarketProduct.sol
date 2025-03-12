// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts-upgradeable/security/ReentrancyGuardUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/utils/cryptography/draft-EIP712Upgradeable.sol";
import "../utils/GovernableInitializable.sol";
import "../interfaces/risk/IPolicyManager.sol";
import "../interfaces/risk/IRiskManager.sol";
import "../interfaces/risk/IRiskStrategy.sol";
//import "../interfaces/utils/IClaimsEscrow.sol";
import "../interfaces/utils/IRegistry.sol";
import "../interfaces/products/IProduct.sol";


/**
 * @title SolaceMarketProduct
 * @author solace.fi
 * @dev For withdrawals to work, the premium pool must call weth.approve(address (SolaceMarketProduct.sol) , UINT_256_MAX)
 * @notice The abstract smart contract that is inherited by every concrete individual **Product** contract.
 *
 * It is required to extend [`IProduct`](../interface/IProduct) and recommended to extend `BaseProduct`. `BaseProduct` extends [`IProduct`](../interface/IProduct) and takes care of the heavy lifting; new products simply need to set some variables in the constructor. It has some helpful functionality not included in [`IProduct`](../interface/IProduct) including claim signers.
 */
//contract SolaceMarketProduct is IProduct, EIP712Upgradeable, ReentrancyGuardUpgradeable, GovernableInitializable, Initializable {
contract SolaceMarketProduct is IProduct, EIP712Upgradeable, ReentrancyGuardUpgradeable, GovernableInitializable {
    using SafeERC20 for IERC20;

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    /// @notice Registry contract.
    IRegistry internal _registry;

    /// @notice The minimum policy period in blocks.
    uint40 internal _minPeriod;

    /// @notice The maximum policy period in blocks.
    uint40 internal _maxPeriod;

    /// @notice Cannot buy new policies while paused. (Default is False)
    bool internal _paused;

    /****
        Book-Keeping Variables
    ****/
    /// @notice The current amount covered (in wei).
    uint256 internal _activeCoverLimit;

    /// @notice The current amount covered (in wei) per strategy.
    mapping(address => uint256) internal _activeCoverLimitPerStrategy;

    /// @notice The authorized signers.
    mapping(address => bool) internal _isAuthorizedSigner;

    // Typehash for claim submissions.
    // Must be unique for all products.
    // solhint-disable-next-line var-name-mixedcase
    bytes32 internal _SUBMIT_CLAIM_TYPEHASH;

    // used in our floating point price math
    // price is measured in wei per block per wei of coverage * Q12
    // divide by Q12 to get premium
    uint256 internal constant Q12 = 1e12;

    /***************************************
    EVENTS
    ***************************************/

    /// @notice Emitted when a claim signer is added.
    event SignerAdded(address indexed signer);
    /// @notice Emitted when a claim signer is removed.
    event SignerRemoved(address indexed signer);

    modifier whileUnpaused() {
        require(!_paused, "cannot buy when paused");
        _;
    }

    /**
     * @notice Initializes the product.
     * @param governance_ The governor.
     * @param minPeriod_ The minimum policy period in blocks to purchase a **policy**.
     * @param maxPeriod_ The maximum policy period in blocks to purchase a **policy**.
     * @param typehash_ The typehash for submitting claims.
     * @param domain_ The user readable name of the EIP712 signing domain.
     * @param version_ The current major version of the signing domain.
     */
    function initialize(
        address governance_,
        IRegistry registry_,
        uint40 minPeriod_,
        uint40 maxPeriod_,
        bytes32 typehash_,
        string memory domain_,
        string memory version_
    ) public virtual initializer {
        __Governable_init(governance_);
        __EIP712_init(domain_, version_);
        __ReentrancyGuard_init();
        require(address(registry_) != address(0x0), "zero address registry");
        _registry = registry_;
        require(_registry.get("policyManager") != address(0x0), "zero address policy manager");
        require(minPeriod_ <= maxPeriod_, "invalid period");
        _minPeriod = minPeriod_;
        _maxPeriod = maxPeriod_;
        _SUBMIT_CLAIM_TYPEHASH = typehash_;
    }

    /***************************************
    POLICYHOLDER FUNCTIONS
    ***************************************/

    /**
     * @notice Purchases and mints a policy on the behalf of the policyholder.
     * User will need to pay **USD**.
     * @param policyholder Holder of the position(s) to cover.
     * @param coverLimit The value to cover in **USD**.
     * @param blocks The length (in blocks) for policy.
     * @param positionDescription A byte encoded description of the position(s) to cover.
     * @param riskStrategy The risk strategy of the product to cover.
     * @return policyID The ID of newly created policy.
     */
    function buyPolicy(address policyholder, uint256 coverLimit, uint40 blocks, bytes memory positionDescription, address riskStrategy) external override nonReentrant whileUnpaused returns (uint256 policyID) {
        require(policyholder != address(0x0), "zero address");
        require(coverLimit > 0, "zero cover value");
        // check that the product can provide coverage for this policy
        (bool acceptable, uint24 price) = IRiskStrategy(riskStrategy).assessRisk(address(this), 0, coverLimit);
        require(acceptable, "cannot accept that risk");
        // check that the buyer has paid the correct premium
        uint256 premium = coverLimit * blocks * price / Q12;
        require(IERC20(getAsset()).balanceOf(msg.sender) >= premium && premium != 0, "insufficient payment");
        // check that the buyer provided valid period
        require(blocks >= _minPeriod && blocks <= _maxPeriod, "invalid period");
        // create the policy
        uint40 expirationBlock = uint40(block.number + blocks);
        policyID = IPolicyManager(_registry.get("policyManager")).createPolicy(policyholder, coverLimit, expirationBlock, price, positionDescription, riskStrategy);
        // update local book-keeping variables
        _activeCoverLimit += coverLimit;
        _activeCoverLimitPerStrategy[riskStrategy] += coverLimit;
        // transfer premium to the premium pool
        _deposit(premium);
        emit PolicyCreated(policyID);
        return policyID;
    }

    /**
     * @notice Increase or decrease the cover limit of the policy.
     * User may need to pay **USD** for increased cover limit or receive a refund for decreased cover limit.
     * Can only be called by the policyholder.
     * @param policyID The ID of the policy.
     * @param coverLimit The new value to cover in **USD**.
     */
    function updateCoverLimit(uint256 policyID, uint256 coverLimit) external override nonReentrant whileUnpaused {
        require(coverLimit > 0, "zero cover value");
        (address policyholder, address product, uint256 previousCoverLimit, uint40 expirationBlock, uint24 purchasePrice, , address riskStrategy) = IPolicyManager(_registry.get("policyManager")).getPolicyInfo(policyID);
        // check msg.sender is policyholder
        require(policyholder == msg.sender, "!policyholder");
        // check for correct product
        require(product == address(this), "wrong product");
        // check for policy expiration
        require(expirationBlock >= block.number, "policy is expired");
        // check that the product can provide coverage for this policy
        (bool acceptable, uint24 price) = IRiskStrategy(riskStrategy).assessRisk(address(this), previousCoverLimit, coverLimit);
        require(acceptable, "cannot accept that risk");
        // update local book-keeping variables
        _activeCoverLimit = _activeCoverLimit + coverLimit - previousCoverLimit;
        _activeCoverLimitPerStrategy[riskStrategy] = _activeCoverLimitPerStrategy[riskStrategy] + coverLimit - previousCoverLimit;
        // calculate premium needed for new cover limit as if policy is bought now
        uint256 remainingBlocks = expirationBlock - block.number;
        uint256 newPremium = coverLimit * remainingBlocks * price / Q12;
        // calculate premium already paid based on current policy
        uint256 paidPremium = previousCoverLimit * remainingBlocks * purchasePrice / Q12;
        if (newPremium >= paidPremium) {
            uint256 premium = newPremium - paidPremium;
            // check that the buyer has paid the correct premium
            require(IERC20(getAsset()).balanceOf(msg.sender) >= premium, "insufficient payment");
            // transfer premium to the premium pool
            _deposit(premium);
        } else {
            _withdraw(paidPremium - newPremium);
        }
        // update policy's URI and emit event
        IPolicyManager(_registry.get("policyManager")).updatePolicyInfo(policyID, coverLimit, expirationBlock, price);
        emit PolicyUpdated(policyID);
    }

    /**
     * @notice Extend a policy.
     * User will need to pay **USD**.
     * Can only be called by the policyholder.
     * @param policyID The ID of the policy.
     * @param extension The length of extension in blocks.
     */
    function extendPolicy(uint256 policyID, uint40 extension) external override nonReentrant whileUnpaused {
        // check that the msg.sender is the policyholder
        (address policyholder, address product, uint256 coverLimit, uint40 expirationBlock, uint24 purchasePrice, bytes memory positionDescription, address riskStrategy) = IPolicyManager(_registry.get("policyManager")).getPolicyInfo(policyID);
        require(policyholder == msg.sender,"!policyholder");
        require(product == address(this), "wrong product");
        require(expirationBlock >= block.number, "policy is expired");
        require(IRiskStrategy(riskStrategy).status(), "strategy inactive");
       
        // compute the premium
        uint256 premium = coverLimit * extension * purchasePrice / Q12;
        // check that the buyer has paid the correct premium
        require(IERC20(getAsset()).balanceOf(msg.sender) >= premium, "insufficient payment");
        // transfer premium to the premium pool
        _deposit(premium);
        // check that the buyer provided valid period
        uint40 newExpirationBlock = expirationBlock + extension;
        uint40 duration = newExpirationBlock - uint40(block.number);
        require(duration >= _minPeriod && duration <= _maxPeriod, "invalid period");
        // update the policy's URI
        IPolicyManager(_registry.get("policyManager")).setPolicyInfo(policyID, coverLimit, newExpirationBlock, purchasePrice, positionDescription, riskStrategy);
        emit PolicyExtended(policyID);
    }

    /**
     * @notice Extend a policy and update its cover limit.
     * User may need to pay **USD** for increased cover limit or receive a refund for decreased cover limit.
     * Can only be called by the policyholder.
     * @param policyID The ID of the policy.
     * @param coverLimit The new value to cover in **USD**.
     * @param extension The length of extension in blocks.
     */
    function updatePolicy(uint256 policyID, uint256 coverLimit, uint40 extension) external override nonReentrant whileUnpaused {
        require(coverLimit > 0, "zero cover value");
        (address policyholder, address product, uint256 previousCoverLimit, uint40 previousExpirationBlock, uint24 purchasePrice, , address riskStrategy) = IPolicyManager(_registry.get("policyManager")).getPolicyInfo(policyID);
        require(policyholder == msg.sender,"!policyholder");
        require(product == address(this), "wrong product");
        require(previousExpirationBlock >= block.number, "policy is expired");
        // check that the product can provide coverage for this policy
        (bool acceptable, uint24 price) = IRiskStrategy(riskStrategy).assessRisk(address(this), previousCoverLimit, coverLimit);
        require(acceptable, "cannot accept that risk");
        // update active cover limit values
        _activeCoverLimit = _activeCoverLimit + coverLimit - previousCoverLimit;
        _activeCoverLimitPerStrategy[riskStrategy] = _activeCoverLimitPerStrategy[riskStrategy] + coverLimit - previousCoverLimit;
        // update policy
        _updatePolicy(policyID, coverLimit, previousCoverLimit, extension, previousExpirationBlock, price, purchasePrice);

    }

    /**
     * @notice Cancel and burn a policy.
     * User will receive a refund for the remaining blocks.
     * Can only be called by the policyholder.
     * @param policyID The ID of the policy.
     */
    function cancelPolicy(uint256 policyID) external override nonReentrant {
        (address policyholder, address product, uint256 coverLimit, uint40 expirationBlock, uint24 purchasePrice, , address riskStrategy) = IPolicyManager(_registry.get("policyManager")).getPolicyInfo(policyID);
        require(policyholder == msg.sender,"!policyholder");
        require(product == address(this), "wrong product");
        uint40 blocksLeft = expirationBlock - uint40(block.number);
        uint256 refundAmount = blocksLeft * coverLimit * purchasePrice / Q12;
        IPolicyManager(_registry.get("policyManager")).burn(policyID);
        _withdraw(refundAmount);
        _activeCoverLimit -= coverLimit;
        _activeCoverLimitPerStrategy[riskStrategy] -= coverLimit;
        emit PolicyCanceled(policyID);
    }

    /**
     * @notice Submit a claim.
     * The user can only submit one claim per policy and the claim must be signed by an authorized signer.
     * If successful the policy is burnt and a new claim is created.
     * The new claim will be in [`ClaimsEscrow`](../ClaimsEscrow) and have the same ID as the policy.
     * Can only be called by the policyholder.
     * @param policyID The policy that suffered a loss.
     * @param amountOut The amount the user will receive.
     * @param deadline Transaction must execute before this timestamp.
     * @param signature Signature from the signer.
     */
    function submitClaim(
        uint256 policyID,
        uint256 amountOut,
        uint256 deadline,
        bytes calldata signature
    ) external nonReentrant {
        // validate inputs
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= deadline, "expired deadline");
        (address policyholder, address product, uint256 coverLimit, , , ,) = IPolicyManager(_registry.get("policyManager")).getPolicyInfo(policyID);
        require(policyholder == msg.sender, "!policyholder");
        require(product == address(this), "wrong product");
        require(amountOut <= coverLimit, "excessive amount out");
        // verify signature
        {
        bytes32 structHash = keccak256(abi.encode(_SUBMIT_CLAIM_TYPEHASH, policyID, msg.sender, amountOut, deadline));
        bytes32 hash = _hashTypedDataV4(structHash);
        address signer = ECDSAUpgradeable.recover(hash, signature);
        require(_isAuthorizedSigner[signer], "invalid signature");
        }
        // update local book-keeping variables
        _activeCoverLimit -= coverLimit;
        // burn policy
        IPolicyManager(_registry.get("policyManager")).burn(policyID);
        // submit claim to ClaimsEscrow
        //IClaimsEscrow(payable(_registry.get("claimsEscrow"))).receiveClaim(policyID, policyholder, amountOut);
        emit ClaimSubmitted(policyID);
    }

    /***************************************
    QUOTE VIEW FUNCTIONS
    ***************************************/

    /**
     * @notice Calculate a premium quote for a policy.
     * @param coverLimit The value to cover in **USD**.
     * @param blocks The duration of the policy in blocks.
     * @param riskStrategy The risk strategy address.
     * @return premium The quote for their policy in **USD**.
     */
    function getQuote(uint256 coverLimit, uint40 blocks, address riskStrategy) external view override returns (uint256 premium) {
        (, uint24 price, ) = IRiskStrategy(riskStrategy).productRiskParams(address(this));
        return coverLimit * blocks * price / Q12;
    }

    /***************************************
    GLOBAL VIEW FUNCTIONS
    ***************************************/

    /** 
     * @notice Returns the minimum policy period in blocks.
     * @return period The minimum period value.
    */
    function minPeriod() external view override returns (uint40 period) {
        return _minPeriod;
    }

    /**
     * @notice Returns the maximum policy period in blocks.
     * @return period The maxiumum period value.
    */
    function maxPeriod() external view override returns (uint40 period) {
        return _maxPeriod;
    }

    /**
     * @notice Returns the current amount covered (in wei).
     * @return amount The current amount.
    */
    function activeCoverLimit() external view override returns (uint256 amount) {
        return _activeCoverLimit;
    }

    /**
     * @notice Returns the current amount covered (in wei) per risk strategy.
     * @param riskStrategy The risk strategy address.
     * @return amount The current amount.
    */
    function activeCoverLimitPerStrategy(address riskStrategy) external view override returns (uint256 amount) {
        return _activeCoverLimitPerStrategy[riskStrategy];
    }

    /**
     * @notice Returns whether or not product is currently in paused state.
     * @return status True if product is paused.
    */
    function paused() external view override returns (bool status) {
        return _paused;
    }

    /**
     * @notice Returns the address of the [`PolicyManager`](../PolicyManager).
     * @return policymanager The policy manager address.
    */
    function policyManager() external view override returns (address policymanager) {
        return _registry.get("policyManager");
    }

    /**
     * @notice Returns the address of the [`Registry`](../Registry).
     * @return registry_ The registry address.
    */
    function registry() external view override returns (address registry_) {
        return address(_registry);
    }

    /**
     * @notice Returns true if the given account is authorized to sign claims.
     * @param account Potential signer to query.
     * @return status True if is authorized signer.
     */
    function isAuthorizedSigner(address account) external view override returns (bool status) {
        return _isAuthorizedSigner[account];
    }

    /***************************************
    MUTATOR FUNCTIONS
    ***************************************/

    /**
     * @notice Updates the product's book-keeping variables.
     * Can only be called by the [`PolicyManager`](../PolicyManager).
     * @param coverDiff The change in active cover limit.
     */
    function updateActiveCoverLimit(int256 coverDiff) external override {
        require(msg.sender == _registry.get("policyManager"), "!policymanager");
        _activeCoverLimit = _add(_activeCoverLimit, coverDiff);
    }

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Sets the minimum number of blocks a policy can be purchased for.
     * @param minPeriod_ The minimum number of blocks.
     */
    function setMinPeriod(uint40 minPeriod_) external override onlyGovernance {
        require(minPeriod_ <= _maxPeriod, "invalid period");
        _minPeriod = minPeriod_;
        emit MinPeriodSet(minPeriod_);
    }

    /**
     * @notice Sets the maximum number of blocks a policy can be purchased for.
     * @param maxPeriod_ The maximum number of blocks
     */
    function setMaxPeriod(uint40 maxPeriod_) external override onlyGovernance {
        require(_minPeriod <= maxPeriod_, "invalid period");
        _maxPeriod = maxPeriod_;
        emit MaxPeriodSet(maxPeriod_);
    }

    /**
     * @notice Adds a new signer that can authorize claims.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param signer The signer to add.
     */
    function addSigner(address signer) external onlyGovernance {
        require(signer != address(0x0), "zero address signer");
        _isAuthorizedSigner[signer] = true;
        emit SignerAdded(signer);
    }

    /**
     * @notice Removes a signer.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param signer The signer to remove.
     */
    function removeSigner(address signer) external onlyGovernance {
        _isAuthorizedSigner[signer] = false;
        emit SignerRemoved(signer);
    }

    /**
     * @notice Pauses or unpauses buying and extending policies.
     * Cancelling policies and submitting claims are unaffected by pause.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @dev Used for security and to gracefully phase out old products.
     * @param paused_ True to pause, false to unpause.
     */
    function setPaused(bool paused_) external onlyGovernance {
        _paused = paused_;
        emit PauseSet(paused_);
    }

    /***************************************
    INTERNAL FUNCTIONS
    ***************************************/

    /**
     * @notice Internal function that updates the policy.
     * @param policyID The ID of the policy.
     * @param newCoverLimit The new value to cover in **USD**.
     * @param prevCoverLimit The new value to cover in **USD**.
     * @param extension The length of extension in blocks.
     * @param prevExpirationBlock The previous expiration block of the policy.
     * @param newPrice The new cover quote price.
     * @param prevPrice The previous cover quote price of the policy.
     */
    function _updatePolicy(
        uint256 policyID,
        uint256 newCoverLimit,
        uint256 prevCoverLimit,
        uint40 extension,
        uint40 prevExpirationBlock,
        uint24 newPrice,
        uint24 prevPrice
        ) internal
    {
        // add new block extension
        uint40 newExpirationBlock = prevExpirationBlock + extension;
        // check if duration is valid
        uint40 duration = newExpirationBlock - uint40(block.number);
        require(duration >= _minPeriod && duration <= _maxPeriod, "invalid period");

        // calculate premium needed for new cover limit as if policy is bought now
        uint256 newPremium = newCoverLimit * duration * newPrice / Q12;
        // calculate premium already paid based on current policy
        uint256 paidPremium = prevCoverLimit * (prevExpirationBlock - uint40(block.number)) * prevPrice / Q12;

        if (newPremium >= paidPremium) {
            uint256 premium = newPremium - paidPremium;
            require(IERC20(getAsset()).balanceOf(msg.sender) >= premium, "insufficient payment");
            _deposit(premium);
        } else {
            _withdraw(paidPremium - newPremium);
        }
        // update policy info
        IPolicyManager(_registry.get("policyManager")).updatePolicyInfo(policyID, newCoverLimit, newExpirationBlock, newPrice);
        emit PolicyUpdated(policyID);
    }

    /**
     * @notice Returns the underlying principal asset for `Solace Cover Product`.
     * @return asset The underlying asset.
    */
    function getAsset() internal view returns (IERC20 asset) {
        return IERC20(_registry.get("dai"));
    }

    /**
     * @notice Sends the amount to the premium pool
     * @param amount amount to send to premium pool
     */
    function _deposit(uint256 amount) internal {
        SafeERC20.safeTransferFrom(getAsset(), msg.sender, _registry.get("premiumPool"), amount);
        emit DepositMade(amount);
    }

    /**
     * @notice Withdraw dai from premium pool, and send it to the user
     * @param amount amount to send to premium pool
     */
    function _withdraw(uint256 amount) internal {
        SafeERC20.safeTransferFrom(getAsset(), _registry.get("premiumPool"), msg.sender, amount);
        emit WithdrawMade(amount);
    }

    /**
     * @notice Adds two numbers.
     * @param a The first number as a uint256.
     * @param b The second number as an int256.
     * @return c The sum as a uint256.
     */
    function _add(uint256 a, int256 b) internal pure returns (uint256 c) {
        return (b > 0)
            ? a + uint256(b)
            : a - uint256(-b);
    }

}
