// SPDX-License-Identifier: GPL-3.0-or-later
pragma solidity 0.8.6;

import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/extensions/draft-IERC20Permit.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "./../utils/ERC721EnhancedInitializable.sol";
import "./../utils/GovernableInitializable.sol";
import "./../interfaces/ISOLACE.sol";
import "./../interfaces/staking/IxsLocker.sol";
import "./../interfaces/bonds/IBondDepository.sol";
import "./../interfaces/bonds/IBondTellerFtm.sol";


/**
 * @title BondTellerFtm
 * @author solace.fi
 * @notice A bond teller that accepts **FTM** and **WFTM** as payment.
 *
 * Bond tellers allow users to buy bonds. Payments are made in **FTM** or **WFTM** which is sent to the underwriting pool and used to back risk. Users will receive [**SOLACE**](./../SOLACE) but it must be bonded or staked. If bonded, the [**SOLACE**](./../SOLACE) will be vested linearly and redeemed over time. If staked, the [**SOLACE**](./../SOLACE) only be withdrawable after the lock expires but will give the user extra [**SOLACE**](./../SOLACE) rewards and voting rights.
 *
 * Bonds can be purchased via [`depositFtm()`](#depositftm), [`depositWftm()`](#depositwftm), or [`depositWftmSigned()`](#depositwftmsigned). Bonds are represented as ERC721s, can be viewed with [`bonds()`](#bonds), and redeemed with [`claimRewards()`](#claimrewards). If staked, an [`xsLocker`](./../staking/xsLocker) lock is created instead of a bond.
 */
contract BondTellerFtm is IBondTellerFtm, ReentrancyGuard, ERC721EnhancedInitializable, GovernableInitializable {

    /***************************************
    GLOBAL VARIABLES
    ***************************************/

    // prices
    uint256 public capacity;                   // capacity remaining for all bonds
    uint256 public nextPrice;                  // the price of the next bond before decay
    uint256 public minimumPrice;               // price floor measured in principal per 1 solace
    uint128 public priceAdjNum;                // factor that increases price after purchase
    uint128 public priceAdjDenom;              // factor that increases price after purchase
    uint256 public halfLife;                   // factor for price decay
    uint256 public lastPriceUpdate;            // last timestamp price was updated
    uint256 public maxPayout;                  // max payout in a single bond measured in principal
    uint256 internal constant MAX_BPS = 10000; // 10k basis points (100%)
    uint256 public protocolFeeBps;             // portion of principal that is sent to the dao, the rest to the pool
    bool public termsSet;                      // have terms been set
    bool public capacityIsPayout;              // capacity limit is for payout vs principal
    bool public paused;                        // pauses deposits

    // times
    uint40 public startTime;                   // timestamp bonds start
    uint40 public endTime;                     // timestamp bonds no longer offered
    uint40 public globalVestingTerm;           // duration in seconds (fixed-term)

    // bonds
    uint256 public numBonds;                   // total number of bonds that have been created

    struct Bond {
        uint256 payoutAmount;                  // amount of solace to be paid in total on the bond
        uint256 payoutAlreadyClaimed;          // amount of solace that has already been claimed on the bond
        uint256 principalPaid;                 // amount of principal paid for this bond
        uint40 vestingStart;                   // timestamp at which bond was minted
        uint40 localVestingTerm;               // vesting term for this bond
    }

    mapping (uint256 => Bond) public bonds;    // mapping of bondID to Bond object

    // addresses
    address public solace;                     // solace native token
    address public xsLocker;                   // xsLocker staking contract
    address public principal;                  // token to accept as payment
    bool public isPermittable;                 // true if principal supports EIP2612.
    address public underwritingPool;           // the underwriting pool to back risks
    address public dao;                        // the dao
    address public bondDepo;                   // the bond depository

    /***************************************
    INITIALIZER
    ***************************************/

    /**
     * @notice Initializes the teller.
     * @param name_ The name of the bond token.
     * @param governance_ The address of the [governor](/docs/protocol/governance).
     * @param solace_ The [**SOLACE**](./../SOLACE) token.
     * @param xsLocker_ The [**xsLocker**](./../staking/xsLocker) contract.
     * @param pool_ The underwriting pool.
     * @param dao_ The DAO.
     * @param principal_ The ERC20 token that users deposit.
     * @param isPermittable_ True if `principal` supports `EIP2612`.
     * @param bondDepo_ The bond depository.
     */
    function initialize(
        string memory name_,
        address governance_,
        address solace_,
        address xsLocker_,
        address pool_,
        address dao_,
        address principal_,
        bool isPermittable_,
        address bondDepo_
    ) external override initializer {
        __Governable_init(governance_);
        string memory symbol = "SBT";
        __ERC721Enhanced_init(name_, symbol);
        _setAddresses(solace_, xsLocker_, pool_, dao_, principal_, isPermittable_, bondDepo_);
    }

    /***************************************
    VIEW FUNCTIONS
    ***************************************/

    // BOND PRICE

    /**
     * @notice Calculate the current price of a bond.
     * Assumes 1 [**SOLACE**](./../SOLACE) payout.
     * @return price_ The price of the bond measured in `principal`.
     */
    function bondPrice() public view override returns (uint256 price_) {
        // solhint-disable-next-line not-rely-on-time
        uint256 timeSinceLast = block.timestamp - lastPriceUpdate;
        price_ = exponentialDecay(nextPrice, timeSinceLast);
        if (price_ < minimumPrice) {
            price_ = minimumPrice;
        }
    }

    /**
     * @notice Calculate the amount of [**SOLACE**](./../SOLACE) out for an amount of `principal`.
     * @param amountIn Amount of principal to deposit.
     * @param stake True to stake, false to not stake.
     * @return amountOut Amount of [**SOLACE**](./../SOLACE) out.
     */
    function calculateAmountOut(uint256 amountIn, bool stake) external view override returns (uint256 amountOut) {
        require(termsSet, "not initialized");
        // exchange rate
        uint256 bondPrice_ = bondPrice();
        require(bondPrice_ > 0, "zero price");
        amountOut = 1 ether * amountIn / bondPrice_; // 1 ether => 1 solace
        // ensure there is remaining capacity for bond
        if (capacityIsPayout) {
            // capacity in payout terms
            require(capacity >= amountOut, "bond at capacity");
        } else {
            // capacity in principal terms
            require(capacity >= amountIn, "bond at capacity");
        }
        require(amountOut <= maxPayout, "bond too large");

        return amountOut;
    }

    /**
     * @notice Calculate the amount of `principal` in for an amount of [**SOLACE**](./../SOLACE) out.
     * @param amountOut Amount of [**SOLACE**](./../SOLACE) out.
     * @param stake True to stake, false to not stake.
     * @return amountIn Amount of principal to deposit.
     */
    function calculateAmountIn(uint256 amountOut, bool stake) external view override returns (uint256 amountIn) {
        require(termsSet, "not initialized");
        // exchange rate
        uint256 bondPrice_ = bondPrice();
        require(bondPrice_ > 0, "zero price");
        amountIn = amountOut * bondPrice_ / 1 ether;
        // ensure there is remaining capacity for bond
        if (capacityIsPayout) {
            // capacity in payout terms
            require(capacity >= amountOut, "bond at capacity");
        } else {
            // capacity in principal terms
            require(capacity >= amountIn, "bond at capacity");
        }
        require(amountOut <= maxPayout, "bond too large");
    }

    /***************************************
    BONDER FUNCTIONS
    ***************************************/

    /**
     * @notice Create a bond by depositing **FTM**.
     * Principal will be transferred from `msg.sender` using `allowance`.
     * @param minAmountOut The minimum [**SOLACE**](./../SOLACE) out.
     * @param depositor The bond recipient, default msg.sender.
     * @param stake True to stake, false to not stake.
     * @return payout The amount of [**SOLACE**](./../SOLACE) in the bond.
     * @return tokenID The ID of the newly created bond or lock.
     */
    function depositFtm(
        uint256 minAmountOut,
        address depositor,
        bool stake
    ) public payable override nonReentrant returns (uint256 payout, uint256 tokenID) {
        // accounting
        uint256 protocolFee;
        (payout, tokenID, protocolFee) = _deposit(msg.value, minAmountOut, depositor, stake);
        // route principal - put last as Checks-Effects-Interactions
        if(protocolFee > 0) Address.sendValue(payable(dao), protocolFee);
        Address.sendValue(payable(underwritingPool), msg.value - protocolFee);
    }

    /**
     * @notice Create a bond by depositing `amount` **WFTM**.
     * **WFTM** will be transferred from `msg.sender` using `allowance`.
     * @param amount Amount of **WFTM** to deposit.
     * @param minAmountOut The minimum [**SOLACE**](./../SOLACE) out.
     * @param depositor The bond recipient, default msg.sender.
     * @param stake True to stake, false to not stake.
     * @return payout The amount of [**SOLACE**](./../SOLACE) in the bond.
     * @return tokenID The ID of the newly created bond or lock.
     */
    function depositWftm(
        uint256 amount,
        uint256 minAmountOut,
        address depositor,
        bool stake
    ) external override nonReentrant returns (uint256 payout, uint256 tokenID) {
        // accounting
        uint256 protocolFee;
        (payout, tokenID, protocolFee) = _deposit(amount, minAmountOut, depositor, stake);
        // route principal - put last as Checks-Effects-Interactions
        if(protocolFee > 0) SafeERC20.safeTransferFrom(IERC20(principal), depositor, dao, protocolFee);
        SafeERC20.safeTransferFrom(IERC20(principal), depositor, underwritingPool, amount - protocolFee);
    }

    /**
     * @notice Create a bond by depositing `amount` **WFTM**.
     * **WFTM** will be transferred from `depositor` using `permit`.
     * Note that not all **WFTM**s have a permit function, in which case this function will revert.
     * @param amount Amount of **WFTM** to deposit.
     * @param minAmountOut The minimum [**SOLACE**](./../SOLACE) out.
     * @param depositor The bond recipient, default msg.sender.
     * @param stake True to stake, false to not stake.
     * @param deadline Time the transaction must go through before.
     * @param v secp256k1 signature
     * @param r secp256k1 signature
     * @param s secp256k1 signature
     * @return payout The amount of [**SOLACE**](./../SOLACE) in the bond.
     * @return tokenID The ID of the newly created bond or lock.
     */
    function depositWftmSigned(
        uint256 amount,
        uint256 minAmountOut,
        address depositor,
        bool stake,
        uint256 deadline,
        uint8 v,
        bytes32 r,
        bytes32 s
    ) external override nonReentrant returns (uint256 payout, uint256 tokenID) {
        // permit
        require(isPermittable, "principal does not support permit");
        IERC20Permit(address(principal)).permit(depositor, address(this), amount, deadline, v, r, s);
        // accounting
        uint256 protocolFee;
        (payout, tokenID, protocolFee) = _deposit(amount, minAmountOut, depositor, stake);
        // route principal - put last as Checks-Effects-Interactions
        if(protocolFee > 0) SafeERC20.safeTransferFrom(IERC20(principal), depositor, dao, protocolFee);
        SafeERC20.safeTransferFrom(IERC20(principal), depositor, underwritingPool, amount - protocolFee);
    }

    /***************************************
    BONDER FUNCTIONS
    ***************************************/

    /**
     * @notice Claim payout for a bond that the user holds.
     * User calling `claimPayout()`` must be either the owner or approved for the entered bondID.
     * @param bondID The ID of the bond to redeem.
     */
    function claimPayout(uint256 bondID) external override nonReentrant tokenMustExist(bondID) {
        // checks
        require(_isApprovedOrOwner(msg.sender, bondID), "!bonder");

        // Payout as per vesting terms
        Bond memory bond = bonds[bondID];
        uint256 eligiblePayout = _calculateEligiblePayout(bondID);
        bonds[bondID].payoutAlreadyClaimed += eligiblePayout;

        // Burn bond if vesting completed
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp > bond.vestingStart + bond.localVestingTerm) {
            _burn(bondID);
            delete bonds[bondID];
        }
        emit RedeemBond(bondID, msg.sender, eligiblePayout);

        // Place SafeERC20.safeTransfer last as per Checks-Effects-Interactions
        SafeERC20.safeTransfer(IERC20(solace), msg.sender, eligiblePayout);
    }

    /***************************************
    HELPER FUNCTIONS
    ***************************************/

    /**
     * @notice Create a bond by depositing `amount` of `principal`.
     * @param amount Amount of principal to deposit.
     * @param minAmountOut The minimum [**SOLACE**](./../SOLACE) out.
     * @param depositor The bond recipient, default msg.sender.
     * @param stake True to stake, false to not stake.
     * @return payout The amount of [**SOLACE**](./../SOLACE) in the bond.
     * @return tokenID The ID of the newly created bond or lock.
     * @return protocolFee Amount of principal paid to dao
     */
    function _deposit(
        uint256 amount,
        uint256 minAmountOut,
        address depositor,
        bool stake
    ) internal returns (uint256 payout, uint256 tokenID, uint256 protocolFee) {
        require(depositor != address(0), "invalid address");
        require(!paused, "cannot deposit while paused");

        require(termsSet, "not initialized");
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp >= uint256(startTime), "bond not yet started");
        // solhint-disable-next-line not-rely-on-time
        require(block.timestamp <= uint256(endTime), "bond concluded");

        payout = _calculateTotalPayout(amount);

        // ensure there is remaining capacity for bond
        if (capacityIsPayout) {
            // capacity in payout terms
            uint256 cap = capacity;
            require(cap >= payout, "bond at capacity");
            capacity = cap - payout;
        } else {
            // capacity in principal terms
            uint256 cap = capacity;
            require(cap >= amount, "bond at capacity");
            capacity = cap - amount;
        }
        require(payout <= maxPayout, "bond too large");
        require(minAmountOut <= payout, "slippage protection");

        // route solace
        IBondDepository(bondDepo).pullSolace(payout);
        // optionally stake
        if(stake) {
            // solhint-disable-next-line not-rely-on-time
            tokenID = IxsLocker(xsLocker).createLock(depositor, payout, block.timestamp+globalVestingTerm);
        } else {
          // record bond info
          tokenID = ++numBonds;
          // solhint-disable-next-line not-rely-on-time
          uint40 vestingStart = toUint40(block.timestamp);
          uint40 vestingTerm = globalVestingTerm;
          bonds[tokenID] = Bond({
              payoutAmount: payout,
              payoutAlreadyClaimed: 0,
              principalPaid: amount,
              vestingStart: vestingStart,
              localVestingTerm: vestingTerm
          });
          _mint(depositor, tokenID);
          emit CreateBond(tokenID, amount, payout, vestingStart, vestingTerm);
        }

        protocolFee = amount * protocolFeeBps / MAX_BPS;
        return (payout, tokenID, protocolFee);
    }

    /***************************************
    HELPER FUNCTIONS
    ***************************************/

    /**
     * @notice Calculate the payout in [**SOLACE**](./../SOLACE) and update the current price of a bond.
     * @param depositAmount The amount of `principal` to deposit.
     * @return amountOut The amount of [**SOLACE**](./../SOLACE) out.
     */
    function _calculateTotalPayout(uint256 depositAmount) internal returns (uint256 amountOut) {
        // calculate this price
        // solhint-disable-next-line not-rely-on-time
        uint256 timeSinceLast = block.timestamp - lastPriceUpdate;
        uint256 price_ = exponentialDecay(nextPrice, timeSinceLast);
        if(price_ < minimumPrice) price_ = minimumPrice;
        require(price_ != 0, "invalid price");
        // solhint-disable-next-line not-rely-on-time
        lastPriceUpdate = block.timestamp;
        // calculate amount out
        amountOut = (1 ether * depositAmount) / price_; // 1 ether => 1 solace
        // update next price
        nextPrice = price_ + ( (amountOut * uint256(priceAdjNum)) / uint256(priceAdjDenom));
    }

    /**
     * @notice Calculates current eligible payout on a bond, based on `bond.localVestingTerm` and `bonds[bondID].payoutAlreadyClaimed`.
     * @param bondID The ID of the bond to calculate eligible payout on.
     * @return eligiblePayout Amount of [**SOLACE**](./../SOLACE) that can be currently claimed for the bond.
     */
    function _calculateEligiblePayout(uint256 bondID) internal view returns (uint256 eligiblePayout) {
        Bond memory bond = bonds[bondID];

        // Sanity check
        assert(bond.payoutAlreadyClaimed <= bond.payoutAmount);

        // Calculation if still vesting
        // solhint-disable-next-line not-rely-on-time
        if (block.timestamp <= bond.vestingStart + bond.localVestingTerm) {
            // solhint-disable-next-line not-rely-on-time
            eligiblePayout = ( ( bond.payoutAmount * ( block.timestamp - bond.vestingStart ) ) / bond.localVestingTerm ) - bond.payoutAlreadyClaimed;
        } else {
            // Calculation if vesting completed
            eligiblePayout = bond.payoutAmount - bond.payoutAlreadyClaimed;
        }
    }

    /**
     * @notice Calculates exponential decay.
     * @dev Linear approximation, trades precision for speed.
     * @param initValue The initial value.
     * @param time The time elapsed.
     * @return endValue The value at the end.
     */
    function exponentialDecay(uint256 initValue, uint256 time) internal view returns (uint256 endValue) {
        endValue = initValue >> (time / halfLife);
        endValue -= endValue * (time % halfLife) / halfLife / 2;
    }

    /**
     * @dev Returns the downcasted uint40 from uint256, reverting on
     * overflow (when the input is greater than largest uint40).
     *
     * Counterpart to Solidity's `uint40` operator.
     *
     * Requirements:
     *
     * - input must fit into 40 bits
     */
    function toUint40(uint256 value) internal pure returns (uint40) {
        require(value < 2**40, "SafeCast: value doesn\'t fit in 40 bits");
        return uint40(value);
    }

    /***************************************
    GOVERNANCE FUNCTIONS
    ***************************************/

    /**
     * @notice Pauses deposits.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
    */
    function pause() external override onlyGovernance {
        paused = true;
        emit Paused();
    }

    /**
     * @notice Unpauses deposits.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
    */
    function unpause() external override onlyGovernance {
        paused = false;
        emit Unpaused();
    }

    struct Terms {
        uint256 startPrice;       // The starting price, measured in `principal` for one [**SOLACE**](./../SOLACE).
        uint256 minimumPrice;     // The minimum price of a bond, measured in `principal` for one [**SOLACE**](./../SOLACE).
        uint256 maxPayout;        // The maximum [**SOLACE**](./../SOLACE) that can be sold in a single bond.
        uint128 priceAdjNum;      // Used to calculate price increase after bond purchase.
        uint128 priceAdjDenom;    // Used to calculate price increase after bond purchase.
        uint256 capacity;         // The amount still sellable.
        bool capacityIsPayout;    // True if `capacity_` is measured in [**SOLACE**](./../SOLACE), false if measured in `principal`.
        uint40 startTime;         // The time that purchases start.
        uint40 endTime;           // The time that purchases end.
        uint40 globalVestingTerm; // The duration that users must wait to redeem bonds.
        uint40 halfLife;          // Used to calculate price decay.
    }

    /**
     * @notice Sets the bond terms.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param terms The terms of the bond.
     */
    function setTerms(Terms calldata terms) external onlyGovernance {
        require(terms.startPrice > 0, "invalid price");
        nextPrice = terms.startPrice;
        minimumPrice = terms.minimumPrice;
        maxPayout = terms.maxPayout;
        require(terms.priceAdjDenom != 0, "1/0");
        priceAdjNum = terms.priceAdjNum;
        priceAdjDenom = terms.priceAdjDenom;
        capacity = terms.capacity;
        capacityIsPayout = terms.capacityIsPayout;
        require(terms.startTime <= terms.endTime, "invalid dates");
        startTime = terms.startTime;
        endTime = terms.endTime;
        globalVestingTerm = terms.globalVestingTerm;
        require(terms.halfLife > 0, "invalid halflife");
        halfLife = terms.halfLife;
        termsSet = true;
        // solhint-disable-next-line not-rely-on-time
        lastPriceUpdate = block.timestamp;
        emit TermsSet();
    }

    /**
     * @notice Sets the bond fees.
     * @param protocolFee The fraction of `principal` that will be sent to the dao measured in BPS.
     */
    function setFees(uint256 protocolFee) external onlyGovernance {
        require(protocolFee <= MAX_BPS, "invalid protocol fee");
        protocolFeeBps = protocolFee;
        emit FeesSet();
    }

    /**
     * @notice Sets the addresses to call out.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param solace_ The [**SOLACE**](./../SOLACE) token.
     * @param xsLocker_ The [**xsLocker**](./../staking/xsLocker) contract.
     * @param pool_ The underwriting pool.
     * @param dao_ The DAO.
     * @param principal_ The ERC20 token that users deposit.
     * @param isPermittable_ True if `principal` supports `EIP2612`.
     * @param bondDepo_ The bond depository.
     */
    function setAddresses(
        address solace_,
        address xsLocker_,
        address pool_,
        address dao_,
        address principal_,
        bool isPermittable_,
        address bondDepo_
    ) external override onlyGovernance {
        _setAddresses(solace_, xsLocker_, pool_, dao_, principal_, isPermittable_, bondDepo_);
    }

    /**
     * @notice Sets the addresses to call out.
     * Can only be called by the current [**governor**](/docs/protocol/governance).
     * @param solace_ The [**SOLACE**](./../SOLACE) token.
     * @param xsLocker_ The [**xsLocker**](./../staking/xsLocker) contract.
     * @param pool_ The underwriting pool.
     * @param dao_ The DAO.
     * @param principal_ The ERC20 token that users deposit.
     * @param isPermittable_ True if `principal` supports `EIP2612`.
     * @param bondDepo_ The bond depository.
     */
    function _setAddresses(
        address solace_,
        address xsLocker_,
        address pool_,
        address dao_,
        address principal_,
        bool isPermittable_,
        address bondDepo_
    ) internal {
        require(solace_ != address(0x0), "zero address solace");
        require(xsLocker_ != address(0x0), "zero address xslocker");
        require(pool_ != address(0x0), "zero address pool");
        require(dao_ != address(0x0), "zero address dao");
        require(principal_ != address(0x0), "zero address principal");
        require(bondDepo_ != address(0x0), "zero address bond depo");
        solace = solace_;
        xsLocker = xsLocker_;
        IERC20(solace).approve(xsLocker_, type(uint256).max);
        underwritingPool = pool_;
        dao = dao_;
        principal = principal_;
        isPermittable = isPermittable_;
        bondDepo = bondDepo_;
        emit AddressesSet();
    }

    /***************************************
    FALLBACK FUNCTIONS
    ***************************************/

    /**
     * @notice Fallback function to allow contract to receive **FTM**.
     * Deposits **FTM** and creates bond.
     */
    receive () external payable override {
        depositFtm(0, msg.sender, false);
    }

    /**
     * @notice Fallback function to allow contract to receive **FTM**.
     * Deposits **FTM** and creates bond.
     */
    fallback () external payable override {
        depositFtm(0, msg.sender, false);
    }
}
