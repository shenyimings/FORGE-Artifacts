pragma solidity 0.5.10;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

import {BytesLib} from "@summa-tx/bitcoin-spv-sol/contracts/BytesLib.sol";
import {BTCUtils} from "@summa-tx/bitcoin-spv-sol/contracts/BTCUtils.sol";

import './FundsInterface.sol';
import './SalesInterface.sol';
import './CollateralInterface.sol';
import './DSMath.sol';
import './Medianizer.sol';

/**
 * @title Atomic Loans Loans Contract
 * @author Atomic Loans
 */
contract Loans is DSMath {
    FundsInterface funds;
    Medianizer med;
    SalesInterface sales;
    CollateralInterface col;

    uint256 public constant APPROVE_EXP_THRESHOLD = 4 hours;    // approval expiration threshold
    uint256 public constant ACCEPT_EXP_THRESHOLD = 2 days;      // acceptance expiration threshold
    uint256 public constant LIQUIDATION_EXP_THRESHOLD = 7 days; // liquidation expiration threshold
    uint256 public constant SEIZURE_EXP_THRESHOLD = 2 days;     // seizable expiration threshold
    uint256 public constant LIQUIDATION_DISCOUNT = 930000000000000000; // 93% (7% discount)
    uint256 public constant MAX_NUM_LIQUIDATIONS = 3; // Maximum number of liquidations that can occur
    uint256 public constant MAX_UINT_256 = 2**256-1;

    mapping (bytes32 => Loan)                     public loans;
    mapping (bytes32 => PubKeys)                  public pubKeys;             // Bitcoin Public Keys
    mapping (bytes32 => SecretHashes)             public secretHashes;        // Secret Hashes
    mapping (bytes32 => Bools)                    public bools;               // Boolean state of Loan
    mapping (bytes32 => bytes32)                  public fundIndex;           // Mapping of Loan Index to Fund Index
    mapping (bytes32 => uint256)                  public repayments;          // Amount paid back in a Loan
    mapping (address => bytes32[])                public borrowerLoans;
    mapping (address => bytes32[])                public lenderLoans;
    mapping (address => mapping(uint256 => bool)) public addressToTimestamp;
    uint256                                       public loanIndex;           // Current Loan Index

    ERC20 public token; // ERC20 Debt Stablecoin
    uint256 public decimals;

    address deployer;

    /**
     * @notice Container for loan information
     * @member borrower The address of the borrower
     * @member lender The address of the lender
     * @member arbiter The address of the arbiter
     * @member createdAt The creation timestamp of the loan
     * @member loanExpiration The timestamp for the end of the loan
     * @member requestTimestamp The timestamp for when the loan is requested
     * @member closedTimestamp The timestamp for when the loan is closed
     * @member penalty The amount of tokens to be paid as a penalty for defaulting or allowing the loan to be liquidated
     * @member principal The amount of principal in tokens to be paid back at the end of the loan
     * @member interest The amount of interest in tokens to be paid back by the end of the loan
     * @member penalty The amount of tokens to be paid as a penalty for defaulting or allowing the loan to be liquidated
     * @member fee The amount of tokens paid to the arbiter
     * @member liquidationRatio The ratio of collateral to debt where the loan can be liquidated
     */
    struct Loan {
        address borrower;
        address lender;
        address arbiter;
        uint256 createdAt;
        uint256 loanExpiration;
        uint256 requestTimestamp;
        uint256 closedTimestamp;
        uint256 principal;
        uint256 interest;
        uint256 penalty;
        uint256 fee;
        uint256 liquidationRatio;
    }

    /**
     * @notice Container for Bitcoin public key information
     * @member borrowerPubKey Borrower Bitcoin Public Key
     * @member lenderPubKey Lender Bitcoin Public Key
     * @member arbiterPubKey Arbiter Bitcoin Public Key
     *
     *         Note: This struct is unnecessary for the Ethereum
     *               contract itself, but is used as a point of
     *               reference for generating the correct P2WSH for
     *               locking Bitcoin collateral
     */
    struct PubKeys {
        bytes   borrowerPubKey;
        bytes   lenderPubKey;
        bytes   arbiterPubKey;
    }

    /**
     * @notice Container for borrower, lender, and arbiter Secret Hashes
     * @member secretHashA1 Borrower Secret Hash for the loan
     * @member secretHashAs Borrower Secret Hashes for up to three liquidations
     * @member secretHashB1 Lender Secret Hash for the loan
     * @member secretHashBs Lender Secret Hashes for up to three liquidations
     * @member secretHashC1 Arbiter Secret Hash for the loan
     * @member secretHashCs Arbiter Secret Hashes for up to three liquidations
     * @member withdrawSecret Secret A1 when revealed by borrower
     * @member acceptSecret Secret B1 or Secret C1 when revelaed by the lender or arbiter
     * @member set Secret Hashes set for particular loan
     */
    struct SecretHashes {
        bytes32    secretHashA1;
        bytes32[3] secretHashAs;
        bytes32    secretHashB1;
        bytes32[3] secretHashBs;
        bytes32    secretHashC1;
        bytes32[3] secretHashCs;
        bytes32    withdrawSecret;
        bytes32    acceptSecret;
        bool       set;
    }

    /**
     * @notice Container for states of loan agreement
     * @member funded Indicates that the loan has been funded with tokens
     * @member approved Indicates that the lender has approved locking of the Bitcoin collateral
     * @member withdrawn Indicates that the borrower has withdrawn the tokens from the contract
     * @member sale Indicates that the collateral liquidation process has started
     * @member paid Indicates that the loan has been repaid
     * @member off Indicates that the loan has been cancelled or the loan repayment has been accepted
     */
    struct Bools {
        bool funded;
        bool approved;
        bool withdrawn;
        bool sale;
        bool paid;
        bool off;
    }

    event Create(bytes32 loan);

    event SetSecretHashes(bytes32 loan);

    event FundLoan(bytes32 loan);

    event Approve(bytes32 loan);

    event Withdraw(bytes32 loan, bytes32 secretA1);

    event Repay(bytes32 loan, uint256 amount);

    event Refund(bytes32 loan);

    event Cancel(bytes32 loan, bytes32 secret);

    event Accept(bytes32 loan, bytes32 secret);

    event Liquidate(bytes32 loan, bytes32 secretHash, bytes20 pubKeyHash);

    /**
     * @notice Get the Borrower of a Loan
     * @param loan The Id of a Loan
     * @return Borrower address of Loan
     */
    function borrower(bytes32 loan) external view returns (address) {
        return loans[loan].borrower;
    }

    /**
     * @notice Get the Lender of a Loan
     * @param loan The Id of a Loan
     * @return Lender address of Loan
     */
    function lender(bytes32 loan) external view returns (address) {
        return loans[loan].lender;
    }

    /**
     * @notice Get the Arbiter of a Loan
     * @param loan The Id of a Loan
     * @return Arbiter address of Loan
     */
    function arbiter(bytes32 loan) external view returns (address) {
        return loans[loan].arbiter;
    }

    /**
     * @notice Get the Approve Expiration of a Loan
     * @param loan The Id of a Loan
     * @return Approve Expiration Timestamp
     */
    function approveExpiration(bytes32 loan) public view returns (uint256) { // Approval Expiration
        return add(loans[loan].createdAt, APPROVE_EXP_THRESHOLD);
    }

    /**
     * @notice Get the Accept Expiration of a Loan
     * @param loan The Id of a Loan
     * @return Accept Expiration Timestamp
     */
    function acceptExpiration(bytes32 loan) public view returns (uint256) { // Acceptance Expiration
        return add(loans[loan].loanExpiration, ACCEPT_EXP_THRESHOLD);
    }

    /**
     * @notice Get the Liquidation Expiration of a Loan
     * @param loan The Id of a Loan
     * @return Liquidation Expiration Timestamp
     */
    function liquidationExpiration(bytes32 loan) public view returns (uint256) { // Liquidation Expiration
        return add(loans[loan].loanExpiration, LIQUIDATION_EXP_THRESHOLD);
    }

    /**
     * @notice Get the Seizure Expiration of a Loan
     * @param loan The Id of a Loan
     * @return Seizure Expiration Timestamp
     */
    function seizureExpiration(bytes32 loan) public view returns (uint256) {
        return add(liquidationExpiration(loan), SEIZURE_EXP_THRESHOLD);
    }

    /**
     * @notice Get the Principal of a Loan
     * @param loan The Id of a Loan
     * @return Amount of Principal in stablecoin tokens
     */
    function principal(bytes32 loan) public view returns (uint256) {
        return loans[loan].principal;
    }

    /**
     * @notice Get the Interest of a Loan
     * @param loan The Id of a Loan
     * @return Amount of Interest in stablecoin tokens
     */
    function interest(bytes32 loan) public view returns (uint256) {
        return loans[loan].interest;
    }

    /**
     * @notice Get the Fee of a Loan
     * @param loan The Id of a Loan
     * @return Amount of Fee in stablecoin tokens
     */
    function fee(bytes32 loan) public view returns (uint256) {
        return loans[loan].fee;
    }

    /**
     * @notice Get the Penalty of a Loan (if not repaid)
     * @dev Upon liquidation penalty is paid out to oracles to give incentive for users to continue updating them
     * @param loan The Id of a Loan
     * @return Amount of Penalty in stablecoin tokens
     */
    function penalty(bytes32 loan) public view returns (uint256) {
        return loans[loan].penalty;
    }

    /**
     * @notice Get the Collateral of a Loan
     * @param loan The Id of a Loan
     * @return Amount of collateral backing the loan (in sats)
     */
    function collateral(bytes32 loan) public view returns (uint256) {
        return col.collateral(loan);
    }

    /**
     * @notice Get the Refundable Collateral of a Loan
     * @param loan The Id of a Loan
     * @return Amount of refundable collateral backing the loan (in sats)
     */
    function refundableCollateral(bytes32 loan) external view returns (uint256) {
        return col.refundableCollateral(loan);
    }

    /**
     * @notice Get the Seizable Collateral of a Loan
     * @param loan The Id of a Loan
     * @return Amount of seizable collateral backing the loan (in sats)
     */
    function seizableCollateral(bytes32 loan) external view returns (uint256) {
        return col.seizableCollateral(loan);
    }

    /**
     * @notice Get the Temporary Refundable Collateral of a Loan
     * @dev Represents the amount of refundable collateral that has been locked and only has 1 conf, where 6 confs hasn't been received yet
     * @param loan The Id of a Loan
     * @return Amount of temporary refundable collateral backing the loan (in sats)
     */
    function temporaryRefundableCollateral(bytes32 loan) external view returns (uint256) {
        return col.temporaryRefundableCollateral(loan);
    }

    /**
     * @notice Get the Temporary Seizable Collateral of a Loan
     * @dev Represents the amount of seizable collateral that has been locked and only has 1 conf, where 6 confs hasn't been received yet
     * @param loan The Id of a Loan
     * @return Amount of temporary seizable collateral backing the loan (in sats)
     */
    function temporarySeizableCollateral(bytes32 loan) external view returns (uint256) {
        return col.temporarySeizableCollateral(loan);
    }

    /**
     * @notice Get the amount repaid towards a Loan
     * @param loan The Id of a Loan
     * @return Amount of the loan that has been repaid
     */
    function repaid(bytes32 loan) public view returns (uint256) { // Amount paid back for loan
        return repayments[loan];
    }

    /**
     * @notice Get Liquidation Ratio of a Loan (Minimum Collateralization Ratio)
     * @param loan The Id of a Loan
     * @return Liquidation Ratio in RAY (i.e. 140% would be 1.4 * (10 ** 27))
     */
    function liquidationRatio(bytes32 loan) public view returns (uint256) {
        return loans[loan].liquidationRatio;
    }

    /**
     * @notice Get the amount owed to the Lender for a Loan
     * @param loan The Id of a Loan
     * @return Amount owed to the Lender
     */
    function owedToLender(bytes32 loan) public view returns (uint256) { // Amount lent by Lender
        return add(principal(loan), interest(loan));
    }

    /**
     * @notice Get the amount needed to repay a Loan
     * @param loan The Id of a Loan
     * @return Amount needed to repay the Loan
     */
    function owedForLoan(bytes32 loan) public view returns (uint256) { // Amount owed
        return add(owedToLender(loan), fee(loan));
    }

    /**
     * @notice Get the amount that needs to be covered in the case of a liquidation for a Loan
     * @dev owedForLiquidation includes penalty which is paid out to oracles to give incentive for users to continue updating them
     * @param loan The Id of a Loan
     * @return Amount needed to cover a liquidation
     */
    function owedForLiquidation(bytes32 loan) external view returns (uint256) { // Deductible amount from collateral
        return add(owedForLoan(loan), penalty(loan));
    }

    /**
     * @notice Get the amount still owing for a Loan
     * @param loan The Id of a Loan
     * @return Amount owing for a Loan
     */
    function owing(bytes32 loan) external view returns (uint256) {
        return sub(owedForLoan(loan), repaid(loan));
    }

    /**
     * @notice Get the funded status of a Loan
     * @param loan The Id of a Loan
     * @return Bool that indicates whether loan has been funded
     */
    function funded(bytes32 loan) external view returns (bool) {
        return bools[loan].funded;
    }

    /**
     * @notice Get the approved status of a Loan
     * @param loan The Id of a Loan
     * @return Bool that indicates whether loan has been approved
     */
    function approved(bytes32 loan) external view returns (bool) {
        return bools[loan].approved;
    }

    /**
     * @notice Get the withdrawn status of a Loan
     * @param loan The Id of a Loan
     * @return Bool that indicates whether loan has been withdrawn
     */
    function withdrawn(bytes32 loan) external view returns (bool) {
        return bools[loan].withdrawn;
    }

    /**
     * @notice Get the sale status of a Loan
     * @param loan The Id of a Loan
     * @return Bool that indicates whether loan has been liquidated
     */
    function sale(bytes32 loan) public view returns (bool) {
        return bools[loan].sale;
    }

    /**
     * @notice Get the paid status of a Loan
     * @param loan The Id of a Loan
     * @return Bool that indicates whether loan has been repaid
     */
    function paid(bytes32 loan) external view returns (bool) {
        return bools[loan].paid;
    }

    /**
     * @notice Get the off status of a Loan
     * @param loan The Id of a Loan
     * @return Bool that indicates whether loan has been terminated
     */
    function off(bytes32 loan) public view returns (bool) {
        return bools[loan].off;
    }

    /**
     * @notice Decimal multiplication that multiplies the number to 10 ** 18 if stablecoin token decimals are less than 18
     * @param x The number to decimal multiply
     * @return x converted to WAD (10 ** 18) if decimals are less than 18, else x
     */
    function dmul(uint x) public view returns (uint256) {
        return mul(x, (10 ** sub(18, decimals)));
    }

    /**
     * @notice Decimal division that divides the number to 10 ** decimals from 10 ** 18 if stablecoin token decimals are less than 18
     * @param x The number to decimal divide
     * @return x converted to 10 ** decimals if decimals are less than 18, else x
     */
    function ddiv(uint x) public view returns (uint256) {
        return div(x, (10 ** sub(18, decimals)));
    }

    /**
     * @notice Get the number of loans originated by a Borrower
     * @param borrower_ Address of the Borrower
     * @return Number of loans originated by Borrower
     */
    function borrowerLoanCount(address borrower_) external view returns (uint256) {
        return borrowerLoans[borrower_].length;
    }

    /**
     * @notice Get the number of loans originated by a Lender
     * @param lender_ Address of the Lender
     * @return Number of loans originated by Lender
     */
    function lenderLoanCount(address lender_) external view returns (uint256) {
        return lenderLoans[lender_].length;
    }

    /**
     * @notice The minimum seizable collateral required to cover a Loan
     * @param loan The Id of a Loan
     * @return Amount of seizable collateral value (in sats) required to cover a Loan
     */
    function minSeizableCollateral(bytes32 loan) public view returns (uint256) {
        (bytes32 val, bool set) = med.peek();
        require(set, "Loans.minSeizableCollateral: Medianizer must be set");
        uint256 price = uint(val);
        return div(wdiv(dmul(sub(owedForLoan(loan), repaid(loan))), price), div(WAD, COL));
    }

    /**
     * @notice The current collateral value of a Loan
     * @dev Gets the price in USD from the Medianizer and multiplies it by the collateral in sats to get the USD value of collateral
     * @param loan The Id of a Loan
     * @return Value of collateral (USD in WAD)
     */
    function collateralValue(bytes32 loan) public view returns (uint256) {
        (bytes32 val, bool set) = med.peek();
        require(set, "Loans.collateralValue: Medianizer must be set");
        uint256 price = uint(val);
        return cmul(price, collateral(loan));
    }

    /**
     * @notice The minimum collateral value to cover the amount owed for a Loan
     * @dev Gets the amount in the Loan that still needs to be repaid, converts to WAD, and multiplies it by the minimum liquidation ratio
     * @param loan The Id of a Loan
     * @return Value of the minimum collateral required (USD in WAD)
     */
    function minCollateralValue(bytes32 loan) public view returns (uint256) {
        return rmul(dmul(sub(owedForLoan(loan), repaid(loan))), liquidationRatio(loan));
    }

    /**
     * @notice The discount collateral value in which a Liquidator can purchase the collateral for
     * @param loan The Id of a Loan
     * @return Value of the discounted collateral required to Liquidate a Loan (USD in WAD)
     */
    function discountCollateralValue(bytes32 loan) public view returns (uint256) {
        return wmul(collateralValue(loan), LIQUIDATION_DISCOUNT);
    }

    /**
     * @notice Get the safe status of a Loan
     * @param loan The Id of a Loan
     * @return Bool that indicates whether loan is safe from liquidation
     */
    function safe(bytes32 loan) public view returns (bool) {
        return collateralValue(loan) >= minCollateralValue(loan);
    }

    /**
     * @notice Construct a new Loans contract
     * @param funds_ The address of the Funds contract
     * @param med_ The address of the Medianizer contract
     * @param token_ The stablecoin token address
     * @param decimals_ The number of decimals in the stablecoin token
     */
    constructor (FundsInterface funds_, Medianizer med_, ERC20 token_, uint256 decimals_) public {
        require(address(funds_) != address(0), "Funds address must be non-zero");
        require(address(med_) != address(0), "Medianizer address must be non-zero");
        require(address(token_) != address(0), "Token address must be non-zero");

        deployer = msg.sender;
        funds = funds_;
        med = med_;
        token = token_;
        decimals = decimals_;
        require(token.approve(address(funds), MAX_UINT_256), "Token approve failed");
    }

    // NOTE: THE FOLLOWING FUNCTIONS CAN ONLY BE CALLED BY THE DEPLOYER OF THE
    //       CONTRACT ONCE. THIS IS TO ALLOW FOR FUNDS, LOANS, AND SALES
    //       CONTRACTS TO BE DEPLOYED SEPARATELY (DUE TO GAS LIMIT RESTRICTIONS).
    //       IF YOU ARE USING THIS CONTRACT, ENSURE THAT THESE FUNCTIONS HAVE
    //       ALREADY BEEN CALLED BEFORE DEPOSITING FUNDS.
    // ======================================================================

    /**
     * @dev Sets Sales contract
     * @param sales_ Address of Sales contract
     */
    function setSales(SalesInterface sales_) external {
        require(msg.sender == deployer, "Loans.setSales: Only the deployer can perform this");
        require(address(sales) == address(0), "Loans.setSales: The Sales address has already been set");
        require(address(sales_) != address(0), "Loans.setSales: Sales address must be non-zero");
        sales = sales_;
    }

    /**
     * @dev Sets Spv contract
     * @param col_ Address of Collateral contract
     */
    function setCollateral(CollateralInterface col_) external {
        require(msg.sender == deployer, "Loans.setCollateral: Only the deployer can perform this");
        require(address(col) == address(0), "Loans.setCollateral: The Collateral address has already been set");
        require(address(col_) != address(0), "Loans.setCollateral: Collateral address must be non-zero");
        col = col_;
    }
    // ======================================================================

    /**
     * @notice Creates a new loan agreement
     * @param loanExpiration_ The timestamp for the end of the loan
     * @param usrs_ Array of three addresses containing the borrower, lender, and optional arbiter address
     * @param vals_ Array of seven uints containing loan principal, interest, liquidation penalty, optional arbiter fee, collateral amount, liquidation ratio, and request timestamp
     * @param fund The optional Fund ID
     */
    function create(
        uint256             loanExpiration_,
        address[3] calldata usrs_,
        uint256[7] calldata vals_,
        bytes32             fund
    ) external returns (bytes32 loan) {
        if (fund != bytes32(0)) {
            require(funds.lender(fund) == usrs_[1], "Loans.create: Lender of Fund not in args");
        }
        require(!addressToTimestamp[usrs_[0]][vals_[6]], "Loans.create: Duplicate request timestamps are not allowed");
        require(loanExpiration_ > now, "Loans.create: loanExpiration must be greater than `now`");
        require(usrs_[0] != address(0) && usrs_[1] != address(0), "Loans.create: Borrower and Lender address must be non-zero");
        require(vals_[0] != 0 && vals_[4] != 0, "Loans.create: Principal and Collateral must be non-zero");
        require(vals_[5] != 0 && vals_[6] != 0, "Loans.create: Liquidation ratio and Request timestamp must be non-zero");

        loanIndex = add(loanIndex, 1);
        loan = bytes32(loanIndex);
        loans[loan].createdAt = now;
        loans[loan].loanExpiration = loanExpiration_;
        loans[loan].borrower = usrs_[0];
        loans[loan].lender = usrs_[1];
        loans[loan].arbiter = usrs_[2];
        loans[loan].principal = vals_[0];
        loans[loan].interest = vals_[1];
        loans[loan].penalty = vals_[2];
        loans[loan].fee = vals_[3];
        uint256 minSeizableCol = minSeizableCollateral(loan);
        col.setCollateral(loan, sub(vals_[4], minSeizableCol), minSeizableCol);
        loans[loan].liquidationRatio = vals_[5];
        loans[loan].requestTimestamp = vals_[6];
        fundIndex[loan] = fund;
        secretHashes[loan].set = false;
        borrowerLoans[usrs_[0]].push(bytes32(loanIndex));
        lenderLoans[usrs_[1]].push(bytes32(loanIndex));
        addressToTimestamp[usrs_[0]][vals_[6]] = true;

        emit Create(loan);
    }

    /**
     * @notice Set Secret Hashes for loan agreement
     * @param loan The Id of the Loan
     * @param borrowerSecretHashes Borrower secret hashes
     * @param lenderSecretHashes Lender secret hashes
     * @param arbiterSecretHashes Arbiter secret hashes
     * @param borrowerPubKey_ Borrower Bitcoin Public Key
     * @param lenderPubKey_ Lender Bitcoin Public Key
     * @param arbiterPubKey_ Arbiter Bitcoin Public Key
     */
    function setSecretHashes(
        bytes32             loan,
        bytes32[4] calldata borrowerSecretHashes,
        bytes32[4] calldata lenderSecretHashes,
        bytes32[4] calldata arbiterSecretHashes,
        bytes      calldata borrowerPubKey_,
        bytes      calldata lenderPubKey_,
        bytes      calldata arbiterPubKey_
    ) external {
        require(!secretHashes[loan].set, "Loans.setSecretHashes: Secret hashes must not already be set");
        require(
            msg.sender == loans[loan].borrower || msg.sender == loans[loan].lender || msg.sender == address(funds),
            "Loans.setSecretHashes: msg.sender must be Borrower, Lender or Funds Address"
        );
        secretHashes[loan].secretHashA1 = borrowerSecretHashes[0];
        secretHashes[loan].secretHashAs = [ borrowerSecretHashes[1], borrowerSecretHashes[2], borrowerSecretHashes[3] ];
        secretHashes[loan].secretHashB1 = lenderSecretHashes[0];
        secretHashes[loan].secretHashBs = [ lenderSecretHashes[1], lenderSecretHashes[2], lenderSecretHashes[3] ];
        secretHashes[loan].secretHashC1 = arbiterSecretHashes[0];
        secretHashes[loan].secretHashCs = [ arbiterSecretHashes[1], arbiterSecretHashes[2], arbiterSecretHashes[3] ];
        pubKeys[loan].borrowerPubKey = borrowerPubKey_;
        pubKeys[loan].lenderPubKey = lenderPubKey_;
        pubKeys[loan].arbiterPubKey = arbiterPubKey_;
        secretHashes[loan].set = true;
    }

    /**
     * @notice Lender sends tokens to the loan agreement
     * @param loan The Id of the Loan
     */
    function fund(bytes32 loan) external {
        require(secretHashes[loan].set, "Loans.fund: Secret hashes must be set");
        require(bools[loan].funded == false, "Loans.fund: Loan is already funded");
        bools[loan].funded = true;
        require(token.transferFrom(msg.sender, address(this), principal(loan)), "Loans.fund: Failed to transfer tokens");

        emit FundLoan(loan);
    }

    /**
     * @notice Lender approves locking of Bitcoin collateral
     * @param loan The Id of the Loan
     */
    function approve(bytes32 loan) external { // Approve locking of collateral
    	require(bools[loan].funded == true, "Loans.approve: Loan must be funded");
    	require(loans[loan].lender == msg.sender, "Loans.approve: Only the lender can approve the loan");
        require(now <= approveExpiration(loan), "Loans.approve: Loan is past the approve deadline");
    	bools[loan].approved = true;

        emit Approve(loan);
    }

    /**
     * @notice Borrower withdraws loan
     * @param loan The Id of the Loan
     * @param secretA1 Secret A1 provided by the borrower
     */
    function withdraw(bytes32 loan, bytes32 secretA1) external {
        require(!off(loan), "Loans.withdraw: Loan cannot be inactive");
        require(bools[loan].funded == true, "Loans.withdraw: Loan must be funded");
        require(bools[loan].approved == true, "Loans.withdraw: Loan must be approved");
        require(bools[loan].withdrawn == false, "Loans.withdraw: Loan principal has already been withdrawn");
        require(sha256(abi.encodePacked(secretA1)) == secretHashes[loan].secretHashA1, "Loans.withdraw: Secret does not match");
        bools[loan].withdrawn = true;
        require(token.transfer(loans[loan].borrower, principal(loan)), "Loans.withdraw: Failed to transfer tokens");

        secretHashes[loan].withdrawSecret = secretA1;
        if (address(col.onDemandSpv()) != address(0)) {col.requestSpv(loan);}

        emit Withdraw(loan, secretA1);
    }

    /**
     * @notice Lender sends tokens to the loan agreement
     * @param loan The Id of the Loan
     * @param amount The amount of tokens to repay
     *
     *        Note: Anyone can repay the loan
     */
    function repay(bytes32 loan, uint256 amount) external {
        require(!off(loan), "Loans.repay: Loan cannot be inactive");
        require(!sale(loan), "Loans.repay: Loan cannot be undergoing a liquidation");
        require(bools[loan].withdrawn == true, "Loans.repay: Loan principal must be withdrawn");
        require(now <= loans[loan].loanExpiration, "Loans.repay: Loan cannot have expired");
        require(add(amount, repaid(loan)) <= owedForLoan(loan), "Loans.repay: Cannot repay more than the owed amount");
        require(token.transferFrom(msg.sender, address(this), amount), "Loans.repay: Failed to transfer tokens");
        repayments[loan] = add(amount, repayments[loan]);
        if (repaid(loan) == owedForLoan(loan)) {
            bools[loan].paid = true;
            if (address(col.onDemandSpv()) != address(0)) {col.cancelSpv(loan);}
        }

        emit Repay(loan, amount);
    }

    /**
     * @notice Borrower refunds tokens in the case that Lender doesn't accept loan repayment
     * @dev Send tokens back to the Borrower, and close Loan
     * @param loan The Id of the Loan
     *
     *        Note: If Lender does not accept repayment, liquidation cannot occur
     */
    function refund(bytes32 loan) external {
        require(!off(loan), "Loans.refund: Loan cannot be inactive");
        require(!sale(loan), "Loans.refund: Loan cannot be undergoing a liquidation");
        require(now > acceptExpiration(loan), "Loans.refund: Cannot request refund until after acceptExpiration");
        require(bools[loan].paid == true, "Loans.refund: The loan must be repaid");
        require(msg.sender == loans[loan].borrower, "Loans.refund: Only the borrower can request a refund");
        bools[loan].off = true;
        loans[loan].closedTimestamp = now;
        if (funds.custom(fundIndex[loan]) == false) {
            funds.decreaseTotalBorrow(loans[loan].principal);
            funds.calcGlobalInterest();
        }
        require(token.transfer(loans[loan].borrower, owedForLoan(loan)), "Loans.refund: Failed to transfer tokens");

        emit Refund(loan);
    }

    /**
     * @notice Lender cancels loan after Borrower locks collateral
     * @dev Lender cancels loan and principal is sent back to the Lender / Loan Fund
     * @param loan The Id of the Loan
     * @param secret Secret B1 revealed by the Lender
     */
    function cancel(bytes32 loan, bytes32 secret) external {
        accept(loan, secret);

        emit Cancel(loan, secret);
    }

    /**
     * @notice Lender cancels loan after Seizure Expiration in case Lender loses secret
     * @dev Lender cancels loan and principal is sent back to the Lender / Loan Fund
     * @param loan The Id of the Loan
     */
    function cancel(bytes32 loan) external {
        require(!off(loan), "Loans.cancel: Loan must not be inactive");
        require(bools[loan].withdrawn == false, "Loans.cancel: Loan principal must not be withdrawn");
        require(now >= seizureExpiration(loan), "Loans.cancel: Seizure deadline has not been reached");
        require(bools[loan].sale == false, "Loans.cancel: Loan must not be undergoing liquidation");
        close(loan);

        emit Cancel(loan, bytes32(0));
    }

    /**
     * @notice Lender accepts loan repayment
     * @dev Lender accepts loan repayment and principal + interest are sent back to the Lender / Loan Fund
     * @param loan The Id of the Loan
     * @param secret Secret B1 revealed by the Lender
     */
    function accept(bytes32 loan, bytes32 secret) public {
        require(!off(loan), "Loans.accept: Loan must not be inactive");
        require(bools[loan].withdrawn == false || bools[loan].paid == true, "Loans.accept: Loan must be either not withdrawn or repaid");
        require(msg.sender == loans[loan].lender || msg.sender == loans[loan].arbiter, "Loans.accept: msg.sender must be lender or arbiter");
        require(now <= acceptExpiration(loan), "Loans.accept: Acceptance deadline has past");
        require(bools[loan].sale == false, "Loans.accept: Loan must not be going under liquidation");
        require(
            sha256(abi.encodePacked(secret)) == secretHashes[loan].secretHashB1 || sha256(abi.encodePacked(secret)) == secretHashes[loan].secretHashC1,
            "Loans.accept: Invalid secret"
        );
        secretHashes[loan].acceptSecret = secret;
        close(loan);

        emit Accept(loan, secret);
    }

    /**
     * @notice Terminate Loan and transfer funds back to Lender and Arbiter (if there are any fees acrued)
     * @param loan The Id of the Loan
     */
    function close(bytes32 loan) private {
        bools[loan].off = true;
        loans[loan].closedTimestamp = now;
        // If Loan has not been withdraw, simply transfer Principal back to the Lender
        if (bools[loan].withdrawn == false) {
            if (fundIndex[loan] == bytes32(0)) {
                require(token.transfer(loans[loan].lender, loans[loan].principal), "Loans.close: Failed to transfer principal to Lender");
            } else {
                if (funds.custom(fundIndex[loan]) == false) {
                    funds.decreaseTotalBorrow(loans[loan].principal);
                }
                funds.deposit(fundIndex[loan], loans[loan].principal);
            }
        }
        // If Loan has been withdrawn, transfer Principal + Interest to Lender and Fee to Arbiter
        else {
            if (fundIndex[loan] == bytes32(0)) {
                require(token.transfer(loans[loan].lender, owedToLender(loan)), "Loans.close: Failed to transfer owedToLender to Lender");
            } else {
                if (funds.custom(fundIndex[loan]) == false) {
                    funds.decreaseTotalBorrow(loans[loan].principal);
                }
                funds.deposit(fundIndex[loan], owedToLender(loan));
            }
            require(token.transfer(loans[loan].arbiter, fee(loan)), "Loans.close: Failed to transfer fee to Arbiter");
        }
    }

    /**
     * @notice Any third party starts liquidation of the Bitcoin collateral by providing tokens with the intention to buy at a discount
     * @param loan The Id of the Loan
     * @param secretHash The Secret Hash D1 provided by the liquidator
     * @param pubKeyHash The Bitcoin Public Key Hash of the liquidator
     * @return sale_ The Id of the Sale (Liquidation)
     */
    function liquidate(bytes32 loan, bytes32 secretHash, bytes20 pubKeyHash) external returns (bytes32 sale_) {
        require(!off(loan), "Loans.liquidate: Loan must not be inactive");
        require(bools[loan].withdrawn == true, "Loans.liquidate: Loan principal must be withdrawn");
        require(msg.sender != loans[loan].borrower && msg.sender != loans[loan].lender, "Loans.liquidate: Liquidator must be a third-party");
        require(secretHash != bytes32(0) && pubKeyHash != bytes20(0), "Loans.liquidate: secretHash and pubKeyHash must be non-zero");
        // Check if this is the first liquidation (if a liquidation fails because the liquidator didn't claim, up to MAX_NUM_LIQUIDATIONS can occur)
        if (sales.next(loan) == 0) {
            // Check if current time is greater than loan expiration timestamp
            if (now > loans[loan].loanExpiration) {
                require(bools[loan].paid == false, "Loans.liquidate: loan must not have already been repaid");
            } else {
                require(!safe(loan), "Loans.liquidate: collateralization must be below min-collateralization ratio");
            }
            // If Loan is not custom, update global borrow and interest variables in Funds contract
            if (funds.custom(fundIndex[loan]) == false) {
                funds.decreaseTotalBorrow(loans[loan].principal);
                funds.calcGlobalInterest();
            }
        } else {
            // Since there is only 1 + MAX_NUM_LIQUIDATIONS secret hashes per participant, only MAX_NUM_LIQUIDATIONS Liquidation can occur
            require(sales.next(loan) < MAX_NUM_LIQUIDATIONS, "Loans.liquidate: Max number of liquidations reached");
            require(!sales.accepted(sales.saleIndexByLoan(loan, sales.next(loan) - 1)), "Loans.liquidate: Previous liquidation already accepted");
            require(
                now > sales.settlementExpiration(sales.saleIndexByLoan(loan, sales.next(loan) - 1)),
                "Loans.liquidate: Previous liquidation settlement expiration hasn't expired"
            );
        }
        require(token.balanceOf(msg.sender) >= ddiv(discountCollateralValue(loan)), "Loans.liquidate: insufficient balance to liquidate");
        require(token.transferFrom(msg.sender, address(sales), ddiv(discountCollateralValue(loan))), "Loans.liquidate: Token transfer failed");
        SecretHashes storage h = secretHashes[loan];
        uint256 i = sales.next(loan);
        // Create new Sale with secret hashes associated with sale index
        sale_ = sales.create(
            loan, loans[loan].borrower, loans[loan].lender, loans[loan].arbiter, msg.sender,
            h.secretHashAs[i], h.secretHashBs[i], h.secretHashCs[i], secretHash, pubKeyHash
        );
        if (bools[loan].sale == false) {
            bools[loan].sale = true;
            require(token.transfer(address(sales), repaid(loan)), "Loans.liquidate: Token transfer to Sales contract failed");
        }
        // If onDemandSpv is set, cancel spv proofs for this Loan
        if (address(col.onDemandSpv()) != address(0)) {col.cancelSpv(loan);}

        emit Liquidate(loan, secretHash, pubKeyHash);
    }
}
