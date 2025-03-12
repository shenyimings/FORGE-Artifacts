// SPDX-License-Identifier: GPL-3.0-only
pragma solidity ^0.8.17;

import "../../ZivoeLocker.sol";

import "../../../lib/openzeppelin-contracts/contracts/security/ReentrancyGuard.sol";

interface IZivoeGlobals_OCC {
    /// @notice Returns the address of the ZivoeYDL contract.
    function YDL() external view returns (address);

    /// @notice Returns the address of the Zivoe Laboratory.
    function ZVL() external view returns (address);

    /// @notice Returns the net defaults in the system.
    function defaults() external view returns (uint256);

    /// @notice Returns true if an address is whitelisted as a keeper.
    function isKeeper(address) external view returns (bool);

    /// @notice Returns "true" if a locker is whitelisted for DAO interactions and accounting accessibility.
    /// @param  locker  The address of the locker to check for.
    function isLocker(address locker) external view returns (bool);

    /// @notice Handles WEI standardization of a given asset amount (i.e. 6 decimal precision => 18 decimal precision).
    /// @param  amount The amount of a given "asset".
    /// @param  asset The asset (ERC-20) from which to standardize the amount to WEI.
    /// @return standardizedAmount The above amount standardized to 18 decimals.
    function standardize(uint256 amount, address asset) external view returns (uint256 standardizedAmount);

    /// @notice Call when a default is resolved, decreases net defaults system-wide.
    /// @dev    The value "amount" should be standardized to WEI.
    /// @param  amount The default amount that has been resolved.
    function decreaseDefaults(uint256 amount) external;

    /// @notice Call when a default occurs, increases net defaults system-wide.
    /// @dev    The value "amount" should be standardized to WEI.
    /// @param  amount The default amount.
    function increaseDefaults(uint256 amount) external;
}

interface IZivoeYDL_OCC {
    /// @notice Returns the "stablecoin" that will be distributed via YDL.
    /// @return asset The address of the "stablecoin" that will be distributed via YDL.
    function distributedAsset() external view returns (address asset);
}



/// @notice  OCC stands for "On-Chain Credit".
///          A "Bullet" loan is an interest-only loan, with principal repaid in full at the end.
///          An "Amortization" loan is a principal and interest loan, with consistent payments until fully "Repaid".
///          This locker is responsible for handling accounting of loans.
///          This locker is responsible for handling payments and distribution of payments.
///          This locker is responsible for handling defaults and liquidations (if needed).
contract OCC_Modular is ZivoeLocker, ReentrancyGuard {
    
    using SafeERC20 for IERC20;

    // ---------------------
    //    State Variables
    // ---------------------

    /// @dev Tracks payment schedule type of the loan.
    enum LoanSchedule { Bullet, Amortization }

    /// @dev    Tracks state of the loan, enabling or disabling certain actions (function calls).
    /// @param  Null Default state, loan isn't offered yet.
    /// @param  Offered Loan offer has been created, not accepted (it could have passed expiry date).
    /// @param  Active Loan has been accepted, is currently receiving payments.
    /// @param  Repaid Loan was accepted, and has been fully repaid.
    /// @param  Defaulted Loan has defaulted, payments were missed, gracePeriod passed, and markDefault() called.
    /// @param  Cancelled Loan offer was created, then cancelled prior to acceptance.
    /// @param  Resolved Loan was accepted, then there was a default, then the full amount of principal was repaid.
    /// @param  Combined Loan was accepted, then combined with other loans while active.
    enum LoanState { 
        Null,
        Offered,
        Active,
        Repaid,
        Defaulted,
        Cancelled,
        Resolved,
        Combined
    }

    /// @dev Tracks approved combination.
    struct Combine {
        uint256[] loans;                /// @dev The loans approved for combination.
        uint256 term;                   /// @dev The term of the resulting combined loan.
        uint256 paymentInterval;        /// @dev The paymentInterval of the resulting combined loan.
        uint256 gracePeriod;            /// @dev The gracePeriod of the resulting combined loan.
        uint256 expires;                /// @dev The expiration of this combination.
        int8 paymentSchedule;           /// @dev The paymentSchedule of the resulting combined loan.
        bool valid;                     /// @dev The validity of the combination (if it can be executed).
    }

    /// @dev Tracks the loan.
    struct Loan {
        address borrower;               /// @dev The address that receives capital when the loan is accepted.
        uint256 principalOwed;          /// @dev The amount of principal still owed on the loan.
        uint256 APR;                    /// @dev The annualized percentage rate charged on the outstanding principal.
        uint256 APRLateFee;             /// @dev The APR charged on the outstanding principal if payment is late.
        uint256 paymentDueBy;           /// @dev The timestamp (in seconds) for when the next payment is due.
        uint256 paymentsRemaining;      /// @dev The number of payments remaining until the loan is "Repaid".
        uint256 term;                   /// @dev The number of paymentIntervals that will occur (e.g. 12, 24).
        uint256 paymentInterval;        /// @dev The interval of time between payments (in seconds).
        uint256 offerExpiry;            /// @dev The block.timestamp at which the offer for this loan expires.
        uint256 gracePeriod;            /// @dev The number of seconds a borrower has to makePayment() before default.
        int8 paymentSchedule;           /// @dev The payment schedule of the loan (0 = "Bullet" or 1 = "Amortization").
        LoanState state;                /// @dev The state of the loan.
    }

    address public immutable GBL;               /// @dev The ZivoeGlobals contract.
    address public immutable stablecoin;        /// @dev The stablecoin for this OCC contract.
    address public immutable underwriter;       /// @dev The entity that is allowed to underwrite (a.k.a. issue) loans.

    address public OCT_YDL;                     /// @dev Facilitates swaps and forwards distributedAsset() to YDL.
    
    uint256 public combineCounter;              /// @dev Incrementor for "combinations" mapping.
    uint256 public loanCounter;                 /// @dev Incrementor for "loans" mapping.

    uint256 private constant BIPS = 10000;

    /// @dev Mapping of approved loan combinations.
    mapping(uint256 => Combine) public combinations;

    /// @dev Mapping of loans approved for conversion to amortization payment schedule.
    mapping (uint256 => bool) public conversionToAmortization;
    
    /// @dev Mapping of loans approved for conversion to bullet payment schedule.
    mapping (uint256 => bool) public conversionToBullet;

    /// @dev Mapping of loans approved for extension, key is the loan ID, output is paymentIntervals extension.
    mapping (uint256 => uint256) public extensions;

    /// @dev Mapping of loans and their information, key is the ID of the loan, output is the Loan struct information.
    mapping (uint256 => Loan) public loans;

    /// @dev Mapping of loans approved for refinancing, key is the ID of the loan, output is APR it can refinance to.
    mapping(uint256 => uint256) public refinancing;



    // -----------------
    //    Constructor
    // -----------------

    /// @notice Initializes the OCC_Modular contract.
    /// @param  DAO The administrator of this contract (intended to be ZivoeDAO).
    /// @param  _stablecoin The stablecoin for this OCC contract.
    /// @param  _GBL The ZivoeGlobals contract.
    /// @param  _underwriter The entity that is allowed to call createOffer() and markRepaid().
    /// @param  _OCT_YDL The contract that facilitates swaps and forwards distributedAsset() to YDL.
    constructor(address DAO, address _stablecoin, address _GBL, address _underwriter, address _OCT_YDL) {
        transferOwnershipAndLock(DAO);
        stablecoin = _stablecoin;
        GBL = _GBL;
        underwriter = _underwriter;
        OCT_YDL = _OCT_YDL;
    }



    // ------------
    //    Events
    // ------------

    /// @notice Emitted during applyCombine().
    /// @param  borrower The borrower combining their loans.
    /// @param  loanIDs The IDs of the loans that were combined.
    /// @param  term The resulting term of the combined loan.
    /// @param  paymentInterval The resulting paymentInterval of the combined loan.
    /// @param  gracePeriod The resulting gracePeriod of the combined loan.
    /// @param  paymentSchedule The payment schedule of the combined loan (0 = "Bullet" or 1 = "Amortization").
    event CombineApplied(
        address indexed borrower, 
        uint256[] loanIDs, 
        uint256 term,
        uint256 paymentInterval,
        uint256 gracePeriod,
        int8 paymentSchedule
    );

    /// @notice Emitted during approveCombine().
    /// @param  id The ID of the combination approval in "combinations" mapping.
    /// @param  loanIDs The IDs of the loans that can be combined.
    /// @param  paymentInterval The resulting paymentInterval of the combined loan.
    /// @param  term The resulting term of the combined loan that is permitted.
    /// @param  gracePeriod The resulting gracePeriod of the combined loan that is permitted.
    /// @param  expires The The expiration of this combination.
    /// @param  paymentSchedule The payment schedule of the combined loan (0 = "Bullet" or 1 = "Amortization").
    event CombineApproved(
        uint256 id, 
        uint256[] loanIDs,
        uint256 term,
        uint256 paymentInterval, 
        uint256 gracePeriod,
        uint256 expires,
        int8 paymentSchedule
    );

    /// @notice Emitted during applyCombine().
    /// @param  borrower        The address borrowing (that will receive the loan).
    /// @param  id              Identifier for the loan offer created.
    /// @param  borrowAmount    The amount to borrow (in other words, initial principal).
    /// @param  APR             The annualized percentage rate charged on the outstanding principal.
    /// @param  APRLateFee      The APR charged for late payments.
    /// @param  paymentDueBy    The timestamp (in seconds) for when the next payment is due.
    /// @param  term            The term or "duration" of the loan (number of paymentIntervals that will occur).
    /// @param  paymentInterval The interval of time between payments (in seconds).
    /// @param  gracePeriod     The number of seconds a borrower has to makePayment() before loan could default.
    /// @param  paymentSchedule The payment schedule type ("Bullet" or "Amortization").
    event CombineLoanCreated(
        address indexed borrower,
        uint256 indexed id,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 paymentDueBy,
        uint256 term,
        uint256 paymentInterval,
        uint256 gracePeriod,
        int8 indexed paymentSchedule
    );

    /// @notice Emitted during unapproveCombine().
    /// @param  id The ID of the combine to unapprove.
    event CombineUnapproved(uint256 id);

    /// @notice Emitted during applyConversionToAmortization().
    /// @param  id The loan ID converted to amortization payment schedule.
    event ConversionToAmortizationApplied(uint256 indexed id);

    /// @notice Emitted during unapproveConversionToAmortization().
    /// @param  id The loan ID approved for conversion.
    event ConversionToAmortizationApproved(uint256 indexed id);

    /// @notice Emitted during approveConversionToBullet().
    /// @param  id The loan ID unapproved for conversion.
    event ConversionToAmortizationUnapproved(uint256 indexed id);

    /// @notice Emitted during applyConversionToBullet().
    /// @param  id The loan ID converted to bullet payment schedule.
    event ConversionToBulletApplied(uint256 indexed id);

    /// @notice Emitted during approveConversionToBullet().
    /// @param  id The loan ID approved for conversion.
    event ConversionToBulletApproved(uint256 indexed id);

    /// @notice Emitted during unapproveConversionToBullet().
    /// @param  id The loan ID unapproved for conversion.
    event ConversionToBulletUnapproved(uint256 indexed id);

    /// @notice Emitted during markDefault().
    /// @param id Identifier for the loan which is now "defaulted".
    /// @param principalDefaulted The amount defaulted on.
    event DefaultMarked(uint256 indexed id, uint256 principalDefaulted);

    /// @notice Emitted during resolveDefault().
    /// @param id The identifier for the loan in default that is resolved (or partially).
    /// @param amount The amount of principal paid back.
    /// @param payee The address responsible for resolving the default.
    /// @param resolved Denotes if the loan is fully resolved (false if partial).
    event DefaultResolved(uint256 indexed id, uint256 amount, address indexed payee, bool resolved);

    /// @notice Emitted during applyExtension().
    /// @param  id The identifier of the loan extending its payment schedule.
    /// @param  intervals The number of intervals the loan is extended for.
    event ExtensionApplied(uint256 indexed id, uint256 intervals);

    /// @notice Emitted during approveExtension().
    /// @param  id The identifier of the loan receiving approval for extension.
    /// @param  intervals The number of intervals the approved loan may be extended.
    event ExtensionApproved(uint256 indexed id, uint256 intervals);

    /// @notice Emitted during unapproveExtension().
    /// @param  id The identifier of the loan losing approval for extension.
    event ExtensionUnapproved(uint256 indexed id);

    /// @notice Emitted during supplyInterest().
    /// @param id The identifier for the loan that is supplied additional interest.
    /// @param amount The amount of interest supplied.
    /// @param payee The address responsible for supplying additional interest.
    event InterestSupplied(uint256 indexed id, uint256 amount, address indexed payee);

    /// @notice Emitted during callLoan().
    /// @param id Identifier for the loan which is called.
    /// @param amount The total amount of the payment.
    /// @param interest The interest portion of "amount" paid.
    /// @param principal The principal portion of "amount" paid.
    /// @param lateFee The lateFee portion of "amount" paid.
    event LoanCalled(uint256 indexed id, uint256 amount, uint256 principal, uint256 interest, uint256 lateFee);

    /// @notice Emitted during acceptOffer().
    /// @param  id Identifier for the offer accepted.
    /// @param  principal The amount of stablecoin lent out.
    /// @param  paymentDueBy Timestamp (unix seconds) by which next payment is due.
    event OfferAccepted(uint256 indexed id, uint256 principal, address indexed borrower, uint256 paymentDueBy);

    /// @notice Emitted during cancelOffer().
    /// @param  id Identifier for the loan offer cancelled.
    event OfferCancelled(uint256 indexed id);

    /// @notice Emitted during createOffer().
    /// @param  borrower        The address borrowing (that will receive the loan).
    /// @param  id              Identifier for the loan offer created.
    /// @param  borrowAmount    The amount to borrow (in other words, initial principal).
    /// @param  APR             The annualized percentage rate charged on the outstanding principal.
    /// @param  APRLateFee      The APR charged for late payments.
    /// @param  term            The term or "duration" of the loan (number of paymentIntervals that will occur).
    /// @param  paymentInterval The interval of time between payments (in seconds).
    /// @param  offerExpiry     The block.timestamp at which the offer for this loan expires (hardcoded 2 weeks).
    /// @param  gracePeriod     The number of seconds a borrower has to makePayment() before loan could default.
    /// @param  paymentSchedule The payment schedule type ("Bullet" or "Amortization").
    event OfferCreated(
        address indexed borrower,
        uint256 indexed id,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        uint256 offerExpiry,
        uint256 gracePeriod,
        int8 indexed paymentSchedule
    );

    /// @notice Emitted during makePayment() and processPayment().
    /// @param id Identifier for the loan on which payment is made.
    /// @param payee The address which made payment on the loan.
    /// @param amount The total amount of the payment.
    /// @param principal The principal portion of "amount" paid.
    /// @param interest The interest portion of "amount" paid.
    /// @param lateFee The lateFee portion of "amount" paid.
    /// @param nextPaymentDue The timestamp by which next payment is due.
    event PaymentMade(
        uint256 indexed id, 
        address indexed payee, 
        uint256 amount, 
        uint256 principal, 
        uint256 interest, 
        uint256 lateFee, 
        uint256 nextPaymentDue
    );

    /// @notice Emitted during approveRefinance().
    /// @param  id The loan ID approved for refinance.
    /// @param  APR The APR the loan is approved to refinance to.
    event RefinanceApproved(uint256 indexed id, uint256 APR);

    /// @notice Emitted during applyRefinance().
    /// @param  id The loan ID refinancing its APR.
    /// @param  APRNew The new APR of the loan.
    /// @param  APRPrior The prior APR of the loan.
    event RefinanceApplied(uint256 indexed id, uint256 APRNew, uint256 APRPrior);

    /// @notice Emitted during unapproveRefinance().
    /// @param  id The loan ID unapproved for refinance.
    event RefinanceUnapproved(uint256 indexed id);

    /// @notice Emitted during markRepaid().
    /// @param id Identifier for loan which is now "repaid".
    event RepaidMarked(uint256 indexed id);

    /// @notice Emitted during updateOCTYDL().
    /// @param  newOCT The new OCT_YDL contract.
    /// @param  oldOCT The old OCT_YDL contract.
    event UpdatedOCTYDL(address indexed newOCT, address indexed oldOCT);

    

    // ---------------
    //    Modifiers
    // ---------------

    /// @notice This modifier ensures that the caller is the entity that is allowed to issue loans.
    modifier isUnderwriter() {
        require(_msgSender() == underwriter, "OCC_Modular::isUnderwriter() _msgSender() != underwriter");
        _;
    }



    // ---------------
    //    Functions
    // ---------------

    /// @notice Permission for owner to call pushToLocker().
    function canPush() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pullFromLocker().
    function canPull() public override pure returns (bool) { return true; }

    /// @notice Permission for owner to call pushToLockerPartial().
    function canPullPartial() public override pure returns (bool) { return true; }

    /// @notice Returns information for a given loan.
    /// @dev    Refer to documentation on Loan struct for return param information.
    /// @param  id The ID of the loan.
    /// @return borrower The borrower of the loan.
    /// @return paymentSchedule The structure of the payment schedule.
    /// @return info The remaining information for the loan:
    ///                  info[0] = principalOwed
    ///                  info[1] = APR
    ///                  info[2] = APRLateFee
    ///                  info[3] = paymentDueBy
    ///                  info[4] = paymentsRemaining
    ///                  info[5] = term
    ///                  info[6] = paymentInterval
    ///                  info[7] = offerExpiry
    ///                  info[8] = gracePeriod
    ///                  info[9] = loanState
    function loanInfo(uint256 id) external view returns (
        address borrower, int8 paymentSchedule, uint256[10] memory info
    ) {
        borrower = loans[id].borrower;
        paymentSchedule = loans[id].paymentSchedule;
        info[0] = loans[id].principalOwed;
        info[1] = loans[id].APR;
        info[2] = loans[id].APRLateFee;
        info[3] = loans[id].paymentDueBy;
        info[4] = loans[id].paymentsRemaining;
        info[5] = loans[id].term;
        info[6] = loans[id].paymentInterval;
        info[7] = loans[id].offerExpiry;
        info[8] = loans[id].gracePeriod;
        info[9] = uint256(loans[id].state);
    }

    /// @notice Returns information for amount owed on next payment of a particular loan.
    /// @param  id The ID of the loan.
    /// @return principal The amount of principal owed.
    /// @return interest The amount of interest owed.
    /// @return lateFee The amount of late fees owed.
    /// @return total Full amount owed, combining principal plus interest.
    function amountOwed(uint256 id) public view returns (
        uint256 principal, uint256 interest, uint256 lateFee, uint256 total
    ) {
        // 0 == Bullet.
        if (loans[id].paymentSchedule == 0) {
            if (loans[id].paymentsRemaining == 1) { principal = loans[id].principalOwed; }
        }
        // 1 == Amortization (only two options, use else here).
        else { principal = loans[id].principalOwed / loans[id].paymentsRemaining; }

        // Add late fee if past loans[id].paymentDueBy.
        if (block.timestamp > loans[id].paymentDueBy && loans[id].state == LoanState.Active) {
            lateFee = loans[id].principalOwed * (block.timestamp - loans[id].paymentDueBy) *
                loans[id].APRLateFee / (86400 * 365 * BIPS);
        }
        interest = loans[id].principalOwed * loans[id].paymentInterval * loans[id].APR / (86400 * 365 * BIPS);
        total = principal + interest + lateFee;
    }

    /// @notice Funds and initiates a loan.
    /// @param  id The ID of the loan.
    function acceptOffer(uint256 id) external nonReentrant {
        require(
            loans[id].state == LoanState.Offered, 
            "OCC_Modular::acceptOffer() loans[id].state != LoanState.Offered"
        );
        require(
            block.timestamp < loans[id].offerExpiry, 
            "OCC_Modular::acceptOffer() block.timestamp >= loans[id].offerExpiry"
        );
        require(
            _msgSender() == loans[id].borrower, 
            "OCC_Modular::acceptOffer() _msgSender() != loans[id].borrower"
        );

        // "Friday" Payment Standardization, minimum 7-day lead-time
        // block.timestamp - block.timestamp % 7 days + 9 days + paymentInterval
        emit OfferAccepted(
            id, 
            loans[id].principalOwed, 
            loans[id].borrower, 
            block.timestamp - block.timestamp % 7 days + 9 days + loans[id].paymentInterval
        );

        loans[id].state = LoanState.Active;
        loans[id].paymentDueBy = block.timestamp - block.timestamp % 7 days + 9 days + loans[id].paymentInterval;
        IERC20(stablecoin).safeTransfer(loans[id].borrower, loans[id].principalOwed);
    }

    /// @notice Pays off the loan in full, plus additional interest for paymentInterval.
    /// @dev    Only the "borrower" of the loan may elect this option.
    /// @param  id The loan to pay off early.
    function callLoan(uint256 id) external nonReentrant {
        require(
            _msgSender() == loans[id].borrower || IZivoeGlobals_OCC(GBL).isLocker(_msgSender()), 
            "OCC_Modular::callLoan() _msgSender() != loans[id].borrower && !isLocker(_msgSender())"
        );
        require(loans[id].state == LoanState.Active, "OCC_Modular::callLoan() loans[id].state != LoanState.Active");

        uint256 principalOwed = loans[id].principalOwed;
        (, uint256 interestOwed, uint256 lateFee,) = amountOwed(id);

        emit LoanCalled(id, principalOwed + interestOwed + lateFee, principalOwed, interestOwed, lateFee);

        // Transfer interest to YDL if in same format, otherwise keep here for 1INCH forwarding.
        if (stablecoin == IZivoeYDL_OCC(IZivoeGlobals_OCC(GBL).YDL()).distributedAsset()) {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), IZivoeGlobals_OCC(GBL).YDL(), interestOwed + lateFee);
        }
        else {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), OCT_YDL, interestOwed + lateFee);
        }

        IERC20(stablecoin).safeTransferFrom(_msgSender(), owner(), principalOwed);

        loans[id].principalOwed = 0;
        loans[id].paymentDueBy = 0;
        loans[id].paymentsRemaining = 0;
        loans[id].state = LoanState.Repaid;
    }

    /// @notice Cancels a loan offer.
    /// @param id The ID of the loan.
    function cancelOffer(uint256 id) isUnderwriter external {
        require(
            loans[id].state == LoanState.Offered, 
            "OCC_Modular::cancelOffer() loans[id].state != LoanState.Offered"
        );
        emit OfferCancelled(id);
        loans[id].state = LoanState.Cancelled;
    }

    /// @notice                 Create a loan offer.
    /// @param  borrower        The address to borrow (that receives the loan).
    /// @param  borrowAmount    The amount to borrow (in other words, initial principal).
    /// @param  APR             The annualized percentage rate charged on the outstanding principal.
    /// @param  APRLateFee      The APR charged for late payments.
    /// @param  term            The term or "duration" of the loan (number of paymentIntervals that will occur).
    /// @param  paymentInterval The interval of time between payments (in seconds).
    /// @param  gracePeriod     The number of seconds a borrower has to makePayment() before loan could default.
    /// @param  paymentSchedule The payment schedule type ("Bullet" or "Amortization").
    function createOffer(
        address borrower,
        uint256 borrowAmount,
        uint256 APR,
        uint256 APRLateFee,
        uint256 term,
        uint256 paymentInterval,
        uint256 gracePeriod,
        int8 paymentSchedule
    ) isUnderwriter external {
        require(term > 0, "OCC_Modular::createOffer() term == 0");
        require(
            paymentInterval == 86400 * 7 || paymentInterval == 86400 * 14 || paymentInterval == 86400 * 28 || 
            paymentInterval == 86400 * 91 || paymentInterval == 86400 * 364, 
            "OCC_Modular::createOffer() invalid paymentInterval value, try: 86400 * (7 || 14 || 28 || 91 || 364)"
        );
        require(gracePeriod >= 7 days, "OCC_Modular::createOffer() gracePeriod < 7 days");
        require(paymentSchedule <= 1, "OCC_Modular::createOffer() paymentSchedule > 1");

        emit OfferCreated(
            borrower, loanCounter, borrowAmount, APR, APRLateFee, term,
            paymentInterval, block.timestamp + 3 days, gracePeriod, paymentSchedule
        );

        loans[loanCounter] = Loan(
            borrower, borrowAmount, APR, APRLateFee, 0, term, term, paymentInterval, block.timestamp + 3 days,
            gracePeriod, paymentSchedule, LoanState.Offered
        );

        loanCounter += 1;
    }

    /// @notice Make a payment on a loan.
    /// @dev    Anyone is allowed to make a payment on someone's loan.
    /// @param  id The ID of the loan.
    function makePayment(uint256 id) external nonReentrant {
        require(loans[id].state == LoanState.Active, "OCC_Modular::makePayment() loans[id].state != LoanState.Active");

        (uint256 principalOwed, uint256 interestOwed, uint256 lateFee,) = amountOwed(id);

        emit PaymentMade(
            id, _msgSender(), principalOwed + interestOwed + lateFee, principalOwed,
            interestOwed, lateFee, loans[id].paymentDueBy + loans[id].paymentInterval
        );

        // Transfer interest + lateFee to YDL if in same format, otherwise keep here for 1INCH forwarding.
        if (stablecoin == IZivoeYDL_OCC(IZivoeGlobals_OCC(GBL).YDL()).distributedAsset()) {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), IZivoeGlobals_OCC(GBL).YDL(), interestOwed + lateFee);
        }
        else {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), OCT_YDL, interestOwed + lateFee);
        }
        
        IERC20(stablecoin).safeTransferFrom(_msgSender(), owner(), principalOwed);

        if (loans[id].paymentsRemaining == 1) {
            loans[id].state = LoanState.Repaid;
            loans[id].paymentDueBy = 0;
        }
        else { loans[id].paymentDueBy += loans[id].paymentInterval; }

        loans[id].principalOwed -= principalOwed;
        loans[id].paymentsRemaining -= 1;
    }

    /// @notice Mark a loan insolvent if a payment hasn't been made beyond the corresponding grace period.
    /// @param  id The ID of the loan.
    function markDefault(uint256 id) external isUnderwriter {
        require(loans[id].state == LoanState.Active, "OCC_Modular::markDefault() loans[id].state != LoanState.Active");
        require( 
            loans[id].paymentDueBy + loans[id].gracePeriod < block.timestamp, 
            "OCC_Modular::markDefault() loans[id].paymentDueBy + loans[id].gracePeriod >= block.timestamp"
        );
        
        emit DefaultMarked(id, loans[id].principalOwed);
        loans[id].state = LoanState.Defaulted;
        IZivoeGlobals_OCC(GBL).increaseDefaults(
            IZivoeGlobals_OCC(GBL).standardize(loans[id].principalOwed, stablecoin)
        );
    }

    /// @notice Underwriter specifies a loan has been repaid fully via interest deposits in terms of off-chain debt.
    /// @param  id The ID of the loan.
    function markRepaid(uint256 id) external isUnderwriter {
        require(
            loans[id].state == LoanState.Resolved, 
            "OCC_Modular::markRepaid() loans[id].state != LoanState.Resolved"
        );
        emit RepaidMarked(id);
        loans[id].state = LoanState.Repaid;
    }

    /// @notice Process a payment for a loan, on behalf of another borrower.
    /// @dev    Anyone is allowed to process a payment, it will take from "borrower".
    /// @dev    Only allowed to call this if block.timestamp > paymentDueBy.
    /// @param  id The ID of the loan.
    function processPayment(uint256 id) external nonReentrant {
        require(
            _msgSender() == underwriter || IZivoeGlobals_OCC(GBL).isKeeper(_msgSender()),
            "OCC_Modular::processPayment() _msgSender() != underwriter && !IZivoeGlobals_OCC(GBL).isKeeper(_msgSender())"
        );
        require(
            loans[id].state == LoanState.Active, 
            "OCC_Modular::processPayment() loans[id].state != LoanState.Active"
        );
        require(
            block.timestamp > loans[id].paymentDueBy - 12 hours, 
            "OCC_Modular::processPayment() block.timestamp <= loans[id].paymentDueBy - 12 hours"
        );

        (uint256 principalOwed, uint256 interestOwed, uint256 lateFee,) = amountOwed(id);

        emit PaymentMade(
            id, loans[id].borrower, principalOwed + interestOwed + lateFee, principalOwed,
            interestOwed, lateFee, loans[id].paymentDueBy + loans[id].paymentInterval
        );

        // Transfer interest to YDL if in same format, otherwise keep here for 1INCH forwarding.
        if (stablecoin == IZivoeYDL_OCC(IZivoeGlobals_OCC(GBL).YDL()).distributedAsset()) {
            IERC20(stablecoin).safeTransferFrom(
                loans[id].borrower, IZivoeGlobals_OCC(GBL).YDL(), interestOwed + lateFee
            );
        }
        else {
            IERC20(stablecoin).safeTransferFrom(loans[id].borrower, OCT_YDL, interestOwed + lateFee);
        }
        
        IERC20(stablecoin).safeTransferFrom(loans[id].borrower, owner(), principalOwed);

        if (loans[id].paymentsRemaining == 1) {
            loans[id].state = LoanState.Repaid;
            loans[id].paymentDueBy = 0;
        }
        else { loans[id].paymentDueBy += loans[id].paymentInterval; }

        loans[id].principalOwed -= principalOwed;
        loans[id].paymentsRemaining -= 1;
    }

    /// @notice Make a full (or partial) payment to resolve a insolvent loan.
    /// @param  id The ID of the loan.
    /// @param  amount The amount of principal to pay down.
    function resolveDefault(uint256 id, uint256 amount) external {
        require(
            loans[id].state == LoanState.Defaulted, 
            "OCC_Modular::resolveDefaut() loans[id].state != LoanState.Defaulted"
        );

        uint256 paymentAmount;

        if (amount >= loans[id].principalOwed) {
            paymentAmount = loans[id].principalOwed;
            loans[id].principalOwed = 0;
            loans[id].state = LoanState.Resolved;
        }
        else {
            paymentAmount = amount;
            loans[id].principalOwed -= paymentAmount;
        }

        emit DefaultResolved(id, paymentAmount, _msgSender(), loans[id].state == LoanState.Resolved);

        IERC20(stablecoin).safeTransferFrom(_msgSender(), owner(), paymentAmount);
        IZivoeGlobals_OCC(GBL).decreaseDefaults(IZivoeGlobals_OCC(GBL).standardize(paymentAmount, stablecoin));
    }
    
    /// @notice Supply interest to a repaid loan (for arbitrary interest repayment).
    /// @param  id The ID of the loan.
    /// @param  amount The amount of interest to supply.
    function supplyInterest(uint256 id, uint256 amount) external nonReentrant {
        require(
            loans[id].state == LoanState.Resolved, 
            "OCC_Modular::supplyInterest() loans[id].state != LoanState.Resolved"
        );
        
        emit InterestSupplied(id, amount, _msgSender());
        // Transfer interest to YDL if in same format, otherwise keep here for 1INCH forwarding.
        if (stablecoin == IZivoeYDL_OCC(IZivoeGlobals_OCC(GBL).YDL()).distributedAsset()) {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), IZivoeGlobals_OCC(GBL).YDL(), amount);
        } else {
            IERC20(stablecoin).safeTransferFrom(_msgSender(), OCT_YDL, amount);
        }
    }

    /// @notice Update the OCT_YDL endpoint.
    /// @dev    This function MUST only be called by ZVL().
    /// @param  _OCT_YDL The new address for OCT_YDL.
    function updateOCTYDL(address _OCT_YDL) external {
        require(
            _msgSender() == IZivoeGlobals_OCC(GBL).ZVL(), 
            "OCC_Modular::updateOCTYDL() _msgSender() != IZivoeGlobals_OCC(GBL).ZVL()"
        );
        emit UpdatedOCTYDL(_OCT_YDL, OCT_YDL);
        OCT_YDL = _OCT_YDL;
    }



    /// ---------------------------------
    ///    Apply & Approve & Unapprove
    /// ---------------------------------

    /// @notice Combines multiple loans into a single loan.
    /// @param  id The ID to reference from "combinations" mapping.
    function applyCombine(uint256 id) external {
        require(combinations[id].valid, "OCC_Modular::applyCombine() !combinations[id].valid");
        require(
            block.timestamp < combinations[id].expires, 
            "OCC_Modular::applyCombine() block.timestamp >= combinations[id].expires"
        );

        combinations[combineCounter].valid = false;

        emit CombineApplied(
            _msgSender(),
            combinations[id].loans, 
            combinations[id].term,
            combinations[id].paymentInterval, 
            combinations[id].gracePeriod,
            combinations[id].paymentSchedule
        );

        uint256 notional;
        uint256 APR;
        
        for (uint256 i = 0; i < combinations[id].loans.length; i++) {
            uint256 loanID = combinations[id].loans[i];
            require(
                _msgSender() == loans[loanID].borrower, 
                "OCC_Modular::applyCombine() _msgSender() != loans[loanID].borrower"
            );
            require(
                loans[loanID].state == LoanState.Active, 
                "OCC_Modular::applyCombine() loans[loanID].state != LoanState.Active"
            );
            notional += loans[loanID].principalOwed;
            APR += loans[loanID].principalOwed * loans[loanID].APR;
            loans[loanID].principalOwed = 0;
            loans[loanID].paymentDueBy = 0;
            loans[loanID].paymentsRemaining = 0;
            loans[loanID].state = LoanState.Combined;
        }

        APR = APR / notional % 10000;

        uint256 term = combinations[id].term;
        uint256 paymentInterval = combinations[id].paymentInterval;
        uint256 gracePeriod = combinations[id].gracePeriod;
        int8 paymentSchedule = combinations[id].paymentSchedule;
        
        // "Friday" Payment Standardization, minimum 7-day lead-time
        // block.timestamp - block.timestamp % 7 days + 9 days + paymentInterval
        emit CombineLoanCreated(
            _msgSender(),  // borrower
            loanCounter,  // loanID
            notional,  // principalOwed
            APR,  // APR
            APR,  // APRLateFee
            block.timestamp - block.timestamp % 7 days + 9 days + paymentInterval,  // paymentDueBy
            term,  // term
            paymentInterval,  // paymentInterval
            gracePeriod,  // gracePeriod
            paymentSchedule  // paymentSchedule
        );
        loans[loanCounter] = Loan(
            _msgSender(), notional, APR, APR, block.timestamp - block.timestamp % 7 days + 9 days + paymentInterval, 
            term, term, paymentInterval, block.timestamp - 1 days, gracePeriod, paymentSchedule, LoanState.Active
        );
        loanCounter += 1;
    }

    /// @notice Converts a loan to amortization payment schedule.
    /// @param  id The ID for the loan.
    function applyConversionToAmortization(uint256 id) external {
        require(
            _msgSender() == loans[id].borrower, 
            "OCC_Modular::applyConversionToAmortization() _msgSender() != loans[id].borrower"
        );
        require(
            conversionToAmortization[id], 
            "OCC_Modular::applyConversionToAmortization() !conversionToAmortization[id]"
        );
        emit ConversionToAmortizationApplied(id);
        conversionToAmortization[id] = false;
        loans[id].paymentSchedule = int8(1);
    }

    /// @notice Converts a loan to bullet payment schedule.
    /// @param  id The ID for the loan.
    function applyConversionToBullet(uint256 id) external {
        require(
            _msgSender() == loans[id].borrower,
            "OCC_Modular::applyConversionToBullet() _msgSender() != loans[id].borrower"
        );
        require(
            conversionToBullet[id], 
            "OCC_Modular::applyConversionToBullet() !conversionToBullet[id]"
        );
        emit ConversionToBulletApplied(id);
        conversionToBullet[id] = false;
        loans[id].paymentSchedule = int8(0);
    }

    /// @notice Applies an extension to a loan.
    /// @param  id The ID for the loan.
    function applyExtension(uint256 id) external {
        require(
            _msgSender() == loans[id].borrower, 
            "OCC_Modular::applyExtension() _msgSender() != loans[id].borrower"
        );
        require(extensions[id] > 0,  "OCC_Modular::applyExtension() extensions[id] == 0");
        emit ExtensionApplied(id, extensions[id]);
        
        loans[id].paymentsRemaining += extensions[id];
        loans[id].term += extensions[id];
        extensions[id] = 0;
    }

    /// @notice Refinances a loan.
    /// @param  id The ID for the loan.
    function applyRefinance(uint256 id) external {
        require(_msgSender() == loans[id].borrower, "OCC_Modular::applyRefinance() _msgSender() != loans[id].borrower");
        require(refinancing[id] != 0, "OCC_Modular::applyRefinance() refinancing[id] == 0");
        require(
            loans[id].state == LoanState.Active, 
            "OCC_Modular::applyRefinance() loans[id].state != LoanState.Active"
        );
        emit RefinanceApplied(id, refinancing[id], loans[id].APR);
        loans[id].APR = refinancing[id];
        refinancing[id] = 0;
    }

    /// @notice Approves a borrower for combining loans.
    /// @param  loanIDs The IDs of the loans that can be combined.
    /// @param  term The term that loans can be combined into.
    /// @param  paymentInterval The paymentInterval that loans can be combined into.
    /// @param  paymentSchedule The payment schedule of the loan (0 = "Bullet" or 1 = "Amortization").
    function approveCombine(
        uint256[] calldata loanIDs, 
        uint256 term,
        uint256 paymentInterval, 
        uint256 gracePeriod,
        int8 paymentSchedule
    ) external isUnderwriter {
        require(term > 0, "OCC_Modular::approveCombine() term == 0");
        require(
            paymentInterval == 86400 * 7 || paymentInterval == 86400 * 14 || paymentInterval == 86400 * 28 || 
            paymentInterval == 86400 * 91 || paymentInterval == 86400 * 364, 
            "OCC_Modular::approveCombine() invalid paymentInterval value, try: 86400 * (7 || 14 || 28 || 91 || 364)"
        );
        require(
            loanIDs.length > 1 && paymentSchedule <= 1 && gracePeriod >= 7 days, 
            "OCC_Modular::approveCombine() loanIDs.length <= 1 || paymentSchedule > 1 || gracePeriod < 7 days"
        );

        emit CombineApproved(
            combineCounter, loanIDs, term, paymentInterval, gracePeriod, block.timestamp + 72 hours, paymentSchedule
        );
        
        combinations[combineCounter] = Combine(
            loanIDs, term, paymentInterval, gracePeriod, block.timestamp + 72 hours, paymentSchedule, true
        );

        combineCounter += 1;
    }

    /// @notice Approves a loan for conversion to amortization payment schedule.
    /// @param  id The ID for the loan.
    function approveConversionToAmortization(uint256 id) external isUnderwriter {
        emit ConversionToAmortizationApproved(id);
        conversionToAmortization[id] = true;
    }

    /// @notice Approves a loan for conversion to bullet payment schedule.
    /// @param  id The ID for the loan.
    function approveConversionToBullet(uint256 id) external isUnderwriter {
        emit ConversionToBulletApproved(id);
        conversionToBullet[id] = true;
    }

    /// @notice Approves an extension for a loan.
    /// @param  id The ID for the loan.
    /// @param  intervals The amount of intervals to approve for extension.
    function approveExtension(uint256 id, uint256 intervals) external isUnderwriter {
        emit ExtensionApproved(id, intervals);
        extensions[id] = intervals;
    }

    /// @notice Approves a loan for refinancing.
    /// @param  id The ID for the loan.
    /// @param  APR The APR the loan can refinance to.
    function approveRefinance(uint256 id, uint256 APR) external isUnderwriter {
        emit RefinanceApproved(id, APR);
        refinancing[id] = APR;
    }

    /// @notice Unapproves a borrower for combining loans.
    /// @param  id The ID of the combine to unapprove.
    function unapproveCombine(uint256 id) external isUnderwriter {
        emit CombineUnapproved(id);
        combinations[id].valid = false;
    }

    /// @notice Unapproves a loan for conversion to amortization payment schedule.
    /// @param  id The ID for the loan.
    function unapproveConversionToAmortization(uint256 id) external isUnderwriter {
        emit ConversionToAmortizationUnapproved(id);
        conversionToAmortization[id] = false;
    }

    /// @notice Unapproves a loan for conversion to bullet payment schedule.
    /// @param  id The ID for the loan.
    function unapproveConversionToBullet(uint256 id) external isUnderwriter {
        emit ConversionToBulletUnapproved(id);
        conversionToBullet[id] = false;
    }

    /// @notice Unapproves an extension for a loan.
    /// @param  id The ID for the loan.
    function unapproveExtension(uint256 id) external isUnderwriter {
        emit ExtensionUnapproved(id);
        extensions[id] = 0;
    }

    /// @notice Unapproves a loan for refinancing.
    /// @param  id The ID for the loan.
    function unapproveRefinance(uint256 id) external isUnderwriter {
        emit RefinanceUnapproved(id);
        refinancing[id] = 0;
    }

}
