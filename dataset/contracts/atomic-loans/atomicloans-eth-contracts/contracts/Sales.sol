pragma solidity 0.5.10;

import 'openzeppelin-solidity/contracts/token/ERC20/ERC20.sol';
import 'openzeppelin-solidity/contracts/math/SafeMath.sol';

import {BytesLib} from "@summa-tx/bitcoin-spv-sol/contracts/BytesLib.sol";

import './Loans.sol';
import './Medianizer.sol';
import './DSMath.sol';

/**
 * @title Atomic Loans Sales Contract
 * @author Atomic Loans
 */
contract Sales is DSMath {
    FundsInterface funds;
    Loans loans;
    Medianizer med;

    uint256 public constant SWAP_EXP = 2 hours;       // Swap Expiration
    uint256 public constant SETTLEMENT_EXP = 4 hours; // Settlement Expiration
    uint256 public constant MAX_NUM_LIQUIDATIONS = 3; // Maximum number of liquidations that can occur
    uint256 public constant MAX_UINT_256 = 2**256-1;

    address public deployer; // Only the Loans contract can edit data

    mapping (bytes32 => Sale)       public sales;        // Auctions
    mapping (bytes32 => Sig)        public borrowerSigs; // Borrower Signatures
    mapping (bytes32 => Sig)        public lenderSigs;   // Lender Signatures
    mapping (bytes32 => Sig)        public arbiterSigs;  // Arbiter Signatures
    mapping (bytes32 => SecretHash) public secretHashes; // Auction Secret Hashes
    uint256                         public saleIndex;    // Auction Index

    mapping (bytes32 => bytes32[])  public saleIndexByLoan; // Loan Auctions (find by loanIndex)

    mapping(bytes32 => bool) revealed;

    ERC20 public token;

    /**
     * @notice Container for the sale information
     * @member loanIndex The Id of the loan
     * @member discountBuy The amount in tokens that the Bitcoin collateral was bought for at discount
     * @member liquidator The address of the liquidator (party that buys the Bitcoin collateral at a discount)
     * @member borrower The address of the borrower
     * @member lender The address of the lender
     * @member arbiter The address of the arbiter
     * @member createAt The creation timestamp of the sale
     * @member pubKeyHash The Bitcoin Public Key Hash of the liquidator
     * @member set Indicates that the sale at this specific index has been opened
     * @member accepted Indicates that the discountBuy has been accepted
     * @member off Indicates that the Sale is failed
     */
    struct Sale {
        bytes32    loanIndex;
        uint256    discountBuy;
        address    liquidator;
        address    borrower;
        address    lender;
        address    arbiter;
        uint256    createdAt;
        bytes20    pubKeyHash;
        bool       set;
        bool       accepted;
        bool       off;
    }

    /**
     * @notice Container for the Bitcoin refundable and seizable signature information
     * @member refundableSig The Bitcoin refundable signature to move collateral to swap P2WSH
     * @member seizableSig The Bitcoin seizable signature to move collateral to swap P2WSH
     */
    struct Sig {
        bytes refundableSig;
        bytes seizableSig;
    }

    /**
     * @notice Container for the Bitcoin Secret and Secret Hashes information
     */
    struct SecretHash {
        bytes32 secretHashA; // Secret Hash A
        bytes32 secretA;     // Secret A
        bytes32 secretHashB; // Secret Hash B
        bytes32 secretB;     // Secret B
        bytes32 secretHashC; // Secret Hash C
        bytes32 secretC;     // Secret C
        bytes32 secretHashD; // Secret Hash D
        bytes32 secretD;     // Secret D
    }

    event Create(bytes32 sale);

    event ProvideSig(bytes32 sale);

    event ProvideSecret(bytes32 sale, bytes32 secret_);

    event Accept(bytes32 sale);

    event Refund(bytes32 sale);

    /**
     * @notice Get Discount Buy price for a Sale
     * @param sale The Id of a Sale
     * @return Value of the Discount Buy price
     */
    function discountBuy(bytes32 sale) external view returns (uint256) {
        return sales[sale].discountBuy;
    }

    /**
     * @notice Get the Swap Expiration of a Sale
     * @param sale The Id of a Sale
     * @return Swap Expiration Timestamp
     */
    function swapExpiration(bytes32 sale) external view returns (uint256) {
        return sales[sale].createdAt + SWAP_EXP;
    }

    /**
     * @notice Get the Settlement Expiration of a Sale
     * @param sale The Id of a Sale
     * @return Settlement Expiration Timestamp
     */
    function settlementExpiration(bytes32 sale) public view returns (uint256) {
        return sales[sale].createdAt + SETTLEMENT_EXP;
    }

    /**
     * @notice Get the accepted status of a Sale
     * @param sale The Id of a Sale
     * @return Bool that indicates whether Sale has been accepted
     */
    function accepted(bytes32 sale) public view returns (bool) {
        return sales[sale].accepted;
    }

    /**
     * @notice Get the off status of a Sale
     * @param sale The Id of a Sale
     * @return Bool that indicates whether Sale has been terminated
     */
    function off(bytes32 sale) public view returns (bool) {
        return sales[sale].off;
    }

    /**
     * @notice Construct a new Sales contract
     * @param loans_ The address of the Loans contract
     * @param funds_ The address of the Funds contract
     * @param med_ The address of the Medianizer contract
     * @param token_ The stablecoin token address
     */
    constructor (Loans loans_, FundsInterface funds_, Medianizer med_, ERC20 token_) public {
        require(address(loans_) != address(0), "Loans address must be non-zero");
        require(address(funds_) != address(0), "Funds address must be non-zero");
        require(address(med_) != address(0), "Medianizer address must be non-zero");
        require(address(token_) != address(0), "Token address must be non-zero");
    	deployer = address(loans_);
        loans = loans_;
        funds = funds_;
        med = med_;
        token = token_;
        require(token.approve(address(funds), MAX_UINT_256), "Token approve failed");
    }

    /**
     * @notice Get the next Sale for a Loan
     * @param loan The Id of a Loan
     * @return Bool that indicates whether Sale has been terminated
     */
    function next(bytes32 loan) public view returns (uint256) {
    	return saleIndexByLoan[loan].length;
    }

    /**
     * @notice Creates a new sale (called by the Loans contract)
     * @param loanIndex The Id of the Loan
     * @param borrower The address of the borrower
     * @param lender The address of the lender
     * @param arbiter The address of the arbiter
     * @param liquidator The address of the liquidator
     * @param secretHashA The Secret Hash of the Borrower for the current sale number
     * @param secretHashB The Secret Hash of the Lender for the current sale number
     * @param secretHashC The Secret Hash of the Arbiter for the current sale number
     * @param secretHashD the Secret Hash of the Liquidator
     * @param pubKeyHash The Bitcoin Public Key Hash of the Liquidator
     * @return sale The Id of the sale
     */
    function create(
        bytes32 loanIndex,
        address borrower,
        address lender,
        address arbiter,
        address liquidator,
        bytes32 secretHashA,
        bytes32 secretHashB,
        bytes32 secretHashC,
        bytes32 secretHashD,
        bytes20 pubKeyHash
        ) external returns(bytes32 sale) {
        require(msg.sender == address(loans), "Sales.create: Only the Loans contract can create a Sale");
        saleIndex = add(saleIndex, 1);
        sale = bytes32(saleIndex);
        sales[sale].loanIndex = loanIndex;
        sales[sale].borrower = borrower;
        sales[sale].lender = lender;
        sales[sale].arbiter = arbiter;
        sales[sale].liquidator = liquidator;
        sales[sale].createdAt = now;
        sales[sale].pubKeyHash = pubKeyHash;
        sales[sale].discountBuy = loans.ddiv(loans.discountCollateralValue(loanIndex));
        sales[sale].set = true;
        secretHashes[sale].secretHashA = secretHashA;
        secretHashes[sale].secretHashB = secretHashB;
        secretHashes[sale].secretHashC = secretHashC;
        secretHashes[sale].secretHashD = secretHashD;
        saleIndexByLoan[loanIndex].push(sale);

        emit Create(sale);
   }

    /**
     * @notice Provide Bitcoin signatures for moving collateral to collateral swap script
     * @param sale The Id of the sale
     * @param refundableSig The Bitcoin refundable collateral signature
     * @param seizableSig The Bitcoin seizable collateral signature
     *
     *         Note: More info on the collateral swap script can be seen here:
                     https://github.com/AtomicLoans/chainabstractionlayer-loans
    */
    function provideSig(
        bytes32        sale,
        bytes calldata refundableSig,
        bytes calldata seizableSig
    ) external {
        require(sales[sale].set, "Sales.provideSig: Sale must be set");
        require(now < settlementExpiration(sale), "Sales.provideSig: Cannot provide signature after settlement expiration");
        require(BytesLib.toBytes32(refundableSig) != bytes32(0), "Sales.provideSig: refundableSig must be non-zero");
        require(BytesLib.toBytes32(seizableSig) != bytes32(0), "Sales.provideSig: seizableSig must be non-zero");
        if (msg.sender == sales[sale].borrower) {
            borrowerSigs[sale].refundableSig = refundableSig;
            borrowerSigs[sale].seizableSig = seizableSig;
        } else if (msg.sender == sales[sale].lender) {
            lenderSigs[sale].refundableSig = refundableSig;
            lenderSigs[sale].seizableSig = seizableSig;
        } else if (msg.sender == sales[sale].arbiter) {
            arbiterSigs[sale].refundableSig = refundableSig;
            arbiterSigs[sale].seizableSig = seizableSig;
        } else {
            revert("Loans.provideSig: Must be called by Borrower, Lender or Arbiter");
        }

        emit ProvideSig(sale);
    }

    /**
     * @notice Provide secret to enable liquidator to claim collateral
     * @param secret_ The secret provided by the borrower, lender, arbiter, or liquidator
     */
    function provideSecret(bytes32 sale, bytes32 secret_) public {
        require(sales[sale].set, "Sales.provideSecret: Sale must be set");
        bytes32 secretHash = sha256(abi.encodePacked(secret_));
        revealed[secretHash] = true;
        if (secretHash == secretHashes[sale].secretHashA) {secretHashes[sale].secretA = secret_;}
        if (secretHash == secretHashes[sale].secretHashB) {secretHashes[sale].secretB = secret_;}
        if (secretHash == secretHashes[sale].secretHashC) {secretHashes[sale].secretC = secret_;}
        if (secretHash == secretHashes[sale].secretHashD) {secretHashes[sale].secretD = secret_;}

        emit ProvideSecret(sale, secret_);
    }

    /**
     * @notice Indicates that two of Secret A, Secret B, Secret C have been submitted
     * @param sale The Id of the sale
     */
    function hasSecrets(bytes32 sale) public view returns (bool) {
        uint8 numCorrectSecrets = 0;
        if (revealed[secretHashes[sale].secretHashA]) {numCorrectSecrets += 1;}
        if (revealed[secretHashes[sale].secretHashB]) {numCorrectSecrets += 1;}
        if (revealed[secretHashes[sale].secretHashC]) {numCorrectSecrets += 1;}
        return (numCorrectSecrets >= 2);
    }

    /**
     * @notice Accept discount buy by liquidator and disperse funds to rightful parties
     * @param sale The Id of the sale
     */
    function accept(bytes32 sale) public {
        require(!accepted(sale), "Sales.accept: Sale must not already be accepted");
        require(!off(sale), "Sales.accept: Sale must not already be off");
        require(hasSecrets(sale), "Sales.accept: Secrets need to have already been revealed");
        require(revealed[secretHashes[sale].secretHashD], "Sales.accept: Secret D must have already been revealed");
        sales[sale].accepted = true;

        // First calculate available funds that can be dispursed
        uint256 available = add(sales[sale].discountBuy, loans.repaid(sales[sale].loanIndex));

        // Use available funds to pay Arbiter fee
        if (sales[sale].arbiter != address(0) && available >= loans.fee(sales[sale].loanIndex)) {
            require(token.transfer(sales[sale].arbiter, loans.fee(sales[sale].loanIndex)), "Sales.accept: Token transfer of fee to Arbiter failed");
            available = sub(available, loans.fee(sales[sale].loanIndex));
        }

        // Determine amount remaining after removing owedToLender from available
        uint256 amount = min(available, loans.owedToLender(sales[sale].loanIndex));

        // Transfer amount owedToLender to Lender or Deposit into their Fund if they have one
        if (loans.fundIndex(sales[sale].loanIndex) == bytes32(0)) {
            require(token.transfer(sales[sale].lender, amount), "Sales.accept: Token transfer of amount left to Lender failed");
        } else {
            funds.deposit(loans.fundIndex(sales[sale].loanIndex), amount);
        }

        // Calculate available Funds after subtracting amount owed to Lender
        available = sub(available, amount);

        // Send penalty amount to oracles if there is enough available, else transfer remaining funds to oracles
        if (available >= loans.penalty(sales[sale].loanIndex)) {
            require(token.approve(address(med), loans.penalty(sales[sale].loanIndex)), "Sales.accept: Token transfer of penalty to Medianizer failed");
            med.fund(loans.penalty(sales[sale].loanIndex), token);
            available = sub(available, loans.penalty(sales[sale].loanIndex));
        } else if (available > 0) {
            require(token.approve(address(med), available), "Sales.accept: Token transfer of tokens available to Medianizer failed");
            med.fund(available, token);
            available = 0;
        }

        // If there are still funds available after repaying all other parties, send the remaining funds to the Borrower
        if (available > 0) {
            require(token.transfer(sales[sale].borrower, available), "Sales.accept: Token transfer of tokens available to Borrower failed");
        }

        emit Accept(sale);
    }

     /**
     * @notice Provide secrets to enable liquidator to claim collateral then accept discount buy to disperse funds to rightful parties
     * @param sale The Id of the sale
     * @param secrets_ The secrets provided by the borrower, lender, arbiter, or liquidator
     */
    function provideSecretsAndAccept(bytes32 sale, bytes32[3] calldata secrets_) external {
        provideSecret(sale, secrets_[0]);
        provideSecret(sale, secrets_[1]);
        provideSecret(sale, secrets_[2]);
        accept(sale);
    }

    /**
     * @notice Refund discount buy to liquidator
     * @param sale The Id of the sale
     */
    function refund(bytes32 sale) external {
        require(!accepted(sale), "Sales.refund: Sale must not be accepted");
        require(!off(sale), "Sales.refund: Sale must not be off");
        require(now > settlementExpiration(sale), "Sales.refund: Can only refund after settlement expiration");
        require(sales[sale].discountBuy > 0, "Sales.refund: Discount Buy amount must be non-zero");
        sales[sale].off = true;
        require(token.transfer(sales[sale].liquidator, sales[sale].discountBuy), "Sales.refund: Token transfer to Liquidator failed");
        if (next(sales[sale].loanIndex) == MAX_NUM_LIQUIDATIONS) {
            require(token.transfer(sales[sale].borrower, loans.repaid(sales[sale].loanIndex)), "Sales.refund: Token transfer to Borrower failed");
        }

        emit Refund(sale);
    }
}
