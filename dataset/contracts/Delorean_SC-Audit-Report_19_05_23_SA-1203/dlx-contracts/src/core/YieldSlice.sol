// SPDX-License-Identifier: BSL
pragma solidity ^0.8.13;

import { IERC20 } from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { ReentrancyGuard } from "@openzeppelin/contracts/security/ReentrancyGuard.sol";

import { IYieldSource } from "../interfaces/IYieldSource.sol";
import { IDiscounter } from "../interfaces/IDiscounter.sol";
import { YieldData } from "../data/YieldData.sol";
import { NPVToken } from "../tokens/NPVToken.sol";

/// @title Slice and transfer future yield based on net present value.
contract YieldSlice is ReentrancyGuard {
    using SafeERC20 for IERC20;

    struct DebtSlice {
        address owner;
        uint128 blockTimestamp;
        uint128 unlockedBlockTimestamp;
        uint256 shares;  // Share of the vault's locked generators
        uint256 tokens;  // Tokens locked for generation
        uint256 npvDebt;
        bytes memo;
    }

    struct CreditSlice {
        address owner;

        uint128 createdTimestamp;

        // The slice is entitled to `npvCredit` amount of yield, discounted
        // relative to `blockTimestamp`.
        uint128 blockTimestamp;
        uint256 npvCredit;

        // This slice's share of yield, as a fraction of total NPV tokens.
        uint256 npvTokens;

        // `pending` is accumulated but unclaimed yield for this slice,
        // in nominal terms.
        uint256 pending;

        // `claimed` is the amount of yield claimed by this slice, in
        // nominal terms
        uint256 claimed;

        bytes memo;
    }

    uint256 public constant FEE_DENOM = 100_0;

    // Max fees limit what can be set by governance. Actual fee may be lower.

    // -- Debt fee ratio -- //
    // Debt fee ratio is relative to the discount rate of the transaction.
    // For example, a debt fee ratio of 100% means that the the protocol fee
    // is equal to the discount rate. A ratio of 50% means the protocol fee
    // is half the discount rate.
    uint256 public constant MAX_DEBT_FEE_RATIO = 100_0;


    // -- Credit fees -- //
    // Credit fee are are simple percent of the NPV tokens being purchased.
    uint256 public constant MAX_CREDIT_FEE = 20_0;


    // -- Roles --//
    /** @notice Gov role enables governance functions, including setting
        other roles, setting the dust limit, and setting fees. Gov can
        set a new gov.
     */
    address public gov;

    /** @notice Unlocker role enables unlocking a debt slice on behalf of
        its owner. This is for the benefit of the slice owner, to avoid
        excess socialization of refund from long unlock delays.
     */
    address public unlocker;

    /** @notice Treasury role receives fees.
     */
    address public treasury;

    // The unallocated credit slice tracks yield that has been sold using a
    // debt slice, but hasn't been purchased using a credit slice. When a
    // credit slice purchase takes place, the receiver of that purhcase gets
    // a proportional share of the claimable yield from this slice.
    uint256 public constant UNALLOC_ID = 1;

    uint256 public nextId = UNALLOC_ID + 1;
    uint256 public totalShares;
    uint256 public harvestedYield;
    uint256 public dustLimit;
    uint256 public cumulativePaidYield;

    // Track separately from NPV token total supply, because burns
    // happen on credit slice claims, even though debt slice unlocks
    // are what result in yield generation changes.
    uint256 public activeNPV;

    uint256 public debtFee;
    uint256 public creditFee;

    NPVToken public npvToken;
    IERC20 public immutable generatorToken;
    IERC20 public immutable yieldToken;

    IYieldSource public immutable yieldSource;
    IDiscounter public immutable discounter;
    YieldData public immutable debtData;
    YieldData public immutable creditData;

    mapping(uint256 => DebtSlice) public debtSlices;
    mapping(uint256 => CreditSlice) public creditSlices;
    mapping(uint256 => uint256) public pendingClaimable;
    mapping(uint256 => mapping(address => uint256)) public approvedRollover;

    event SliceDebt(address indexed owner,
                    uint256 indexed id,
                    uint256 tokens,
                    uint256 yield,
                    uint256 npv,
                    uint256 fees);

    event SliceCredit(address indexed owner,
                      uint256 indexed id,
                      uint256 npv,
                      uint256 fees);

    event RolloverDebt(address indexed owner,
                       uint256 indexed id,
                       uint256 yield,
                       uint256 npv,
                       uint256 fees);

    event UnlockDebtSlice(address indexed owner,
                          uint256 indexed id);

    event PayDebt(uint256 indexed id, uint256 amount);

    event WithdrawNPV(address indexed recipient,
                     uint256 indexed id,
                     uint256 amount);

    event Claimed(uint256 indexed id, uint256 amount);

    event DustLimit(uint256 dustLimit);
    event DebtFee(uint256 debtFee);
    event CreditFee(uint256 creditFee);
    event Gov(address indexed gov);
    event Unlocker(address indexed unlocker);
    event Treasury(address indexed treasury);
    event Harvest(uint256 total, uint256 delta);
    event RecordDebtData(uint256 totalTokens, uint256 cumulativeYield);
    event RecordCreditData(uint256 totalTokens, uint256 cumulativeYield);
    event MintFromYield(address indexed recipient, uint256 amount);
    event TransferOwnership(uint256 indexed id, address indexed recipient);

    modifier onlyGov() {
        require(msg.sender == gov, "YS: only gov");
        _;
    }

    modifier isSlice(uint256 id) {
        require(id < nextId, "YS: invalid id");
        _;
    }

    modifier isDebtSlice(uint256 id) {
        require(debtSlices[id].owner != address(0), "YS: no such debt slice");
        _;
    }

    modifier isCreditSlice(uint256 id) {
        require(creditSlices[id].owner != address(0), "YS: no such credit slice");
        _;
    }

    modifier debtSliceOwner(uint256 id) {
        require(debtSlices[id].owner == msg.sender, "YS: only owner");
        _;
    }

    modifier debtSliceOwnerOrUnlocker(uint256 id) {
        require(debtSlices[id].owner == msg.sender || unlocker == msg.sender, "YS: only owner or unlocker");
        _;
    }

    modifier creditSliceOwner(uint256 id) {
        require(creditSlices[id].owner == msg.sender, "YS: only owner");
        _;
    }

    modifier noDust(uint256 amount) {
        require(amount > dustLimit, "YS: dust");
        _;
    }

    modifier validAddress(address recipient) {
        require(recipient != address(0), "YS: zero address");
        require(recipient != address(this), "YS: this address");
        _;
    }

    /// @notice Create a YieldSlice.
    /// @param symbol Symbol for the NPV token.
    /// @param yieldSource_ An interface to interact with the underlying source of yield.
    /// @param debtData_ Tracker for yield per token per second on debt side.
    /// @param creditData_ Tracker for yield per token per second on credit side.
    /// @param discounter_ Discount function for the future yield.
    /// @param dustLimit_ Smallest amount of generating tokens that can be locked.
    constructor(string memory symbol,
                address yieldSource_,
                address debtData_,
                address creditData_,
                address discounter_,
                uint256 dustLimit_)

        validAddress(yieldSource_)
        validAddress(debtData_)
        validAddress(creditData_)
        validAddress(discounter_) {

        gov = msg.sender;
        unlocker = msg.sender;
        treasury = msg.sender;

        npvToken = new NPVToken(symbol, symbol);
        yieldSource = IYieldSource(yieldSource_);
        generatorToken = IYieldSource(yieldSource_).generatorToken();
        yieldToken = IYieldSource(yieldSource_).yieldToken();
        discounter = IDiscounter(discounter_);
        dustLimit = dustLimit_;
        debtData = YieldData(debtData_);
        creditData = YieldData(creditData_);

        creditSlices[UNALLOC_ID] = CreditSlice({
            owner: address(this),
            createdTimestamp: uint128(block.timestamp),
            blockTimestamp: uint128(block.timestamp),
            npvCredit: 0,
            npvTokens: 0,
            pending: 0,
            claimed: 0,
            memo: new bytes(0) });
    }

    function _min(uint256 x1, uint256 x2) private pure returns (uint256) {
        return x1 < x2 ? x1 : x2;
    }

    /// @notice Set the governance address.
    /// @param gov_ The new governance address.
    function setGov(address gov_) validAddress(gov_) external onlyGov {
        gov = gov_;

        emit Gov(gov);
    }

    /// @notice Set the unlocker address.
    /// @param unlocker_ The new unlocker address.
    function setUnlocker(address unlocker_) validAddress(unlocker_) external onlyGov {
        unlocker = unlocker_;

        emit Unlocker(unlocker);
    }

    /// @notice Set the treasury address.
    /// @param treasury_ The new treasury address.
    function setTreasury(address treasury_) validAddress(treasury_) external onlyGov {
        treasury = treasury_;

        emit Treasury(treasury);
    }

    /// @notice Set the dust limit.
    /// @param dustLimit_ The new dust limit.
    function setDustLimit(uint256 dustLimit_) external onlyGov {
        dustLimit = dustLimit_;

        emit DustLimit(dustLimit);
    }

    /// @notice Set the fee ratio on the debt side.
    /// @param debtFee_ The new debt fee ratio.
    function setDebtFee(uint256 debtFee_) external onlyGov {
        require(debtFee_ <= MAX_DEBT_FEE_RATIO, "YS: max debt fee");
        debtFee = debtFee_;

        emit DebtFee(debtFee);
    }

    /// @notice Set the fee ratio othe credit side.
    /// @param creditFee_ The new credit fee ratio.
    function setCreditFee(uint256 creditFee_) external onlyGov {
        require(creditFee_ <= MAX_CREDIT_FEE, "YS: max credit fee");
        creditFee = creditFee_;

        emit CreditFee(creditFee);
    }

    /// @notice Total number of yield generating tokens.
    /// @return Total number of yield generating tokens.
    function totalTokens() public view returns (uint256) {
        return yieldSource.amountGenerator();
    }

    /// @notice Amount of yield generated in the contract's lifetime.
    /// @return Cumulative yield on debt side.
    function cumulativeYield() public view returns (uint256) {
        return harvestedYield + yieldSource.amountPending();
    }

    /// @notice Amount of yield generated in the contract's lifetime, including direct payments.
    /// @return Cumulative yield on credit side.
    function cumulativeYieldCredit() public view returns (uint256) {
        return harvestedYield + cumulativePaidYield + yieldSource.amountPending();
    }

    /// @notice Harvest yield from the yield generating tokens.
    function harvest() external nonReentrant {
        _harvest();
    }

    function _harvest() private {
        uint256 pending = yieldSource.amountPending();
        if (pending == 0) return;
        yieldSource.harvest();
        harvestedYield += pending;

        emit Harvest(harvestedYield, pending);
    }

    /// @notice Recrod data for yield generation rates on both debt and credit side.
    function recordData() external nonReentrant {
        _recordData();
    }

    function _recordData() private {
        uint256 debtTT = totalTokens();
        uint256 debtCY = cumulativeYield();
        debtData.record(debtTT, debtCY);

        uint256 creditCY = cumulativeYieldCredit();
        creditData.record(activeNPV, creditCY);

        emit RecordDebtData(debtTT, debtCY);
        emit RecordCreditData(activeNPV, creditCY);
    }

    /// @notice Number of locked tokens associated with a debt slice.
    /// @param id ID of the debt slice.
    function tokens(uint256 id) public view isDebtSlice(id) returns (uint256) {
        if (totalShares == 0) return 0;
        return totalTokens() * debtSlices[id].shares / totalShares;
    }

    function _previewDebtSlice(uint256 tokens_, uint256 yield) internal view returns (uint256, uint256) {
        uint256 npv = discounter.discounted(tokens_, yield);
        uint256 fees = ((yield - npv) * debtFee) / FEE_DENOM;
        return (npv, fees);
    }

    /// @notice Compute the amount of NPV tokens from locking yield into a slice.
    /// @param tokens_ Amount of yield generating tokens to lock.
    /// @param yield Amount of future yield to lock.
    /// @return uint256 Amount of NPV tokens minted to recipient.
    /// @return uint256 Amount of NPV tokens going to fees.
    function previewDebtSlice(uint256 tokens_, uint256 yield) public view returns (uint256, uint256) {
        return _previewDebtSlice(tokens_, yield);
    }

    function _previewRollover(uint256 id, uint256 yield) internal view returns (uint256, uint256, uint256) {
        DebtSlice storage slice = debtSlices[id];
        ( , uint256 npvGen, ) = generatedDebt(id);

        // Block rollovers for paid slices, to avoid refund accounting. User
        // can unlock and lock into a new slice instead.
        if (npvGen >= slice.npvDebt) return (0, 0, 0);

        // Compute preview as if it were a brand new debt slice.
        (uint256 npv, uint256 fees) = _previewDebtSlice(slice.tokens, yield);

        // Compute NPV debt remaining, relative to the current timestamp
        uint256 remainingShifted = discounter.shiftForward(block.timestamp - uint256(slice.blockTimestamp),
                                                           slice.npvDebt - npvGen);

        // If remaining NPV debt burden exceeds what we can mint, then we can't rollover
        if (remainingShifted > npv) return (0, 0, 0);

        uint256 incrementalNPV = npv - remainingShifted;
        uint256 incrementalFees = fees * incrementalNPV / npv;

        return (remainingShifted,
                incrementalNPV,
                incrementalFees);
    }

    /// @notice Compute the result of a debt slice rollover.
    /// @param id Id of the debt slice to rollover.
    /// @param yield Amount of future yield to lock, as if we were locking it relative to today.
    /// @return uint256 Amount of NPV debt, relative to the current timestamp, before the rollover.
    /// @return uint256 Amount of incremental NPV tokens minted to recipient.
    /// @return uint256 Amount of incremental NPV tokens going to fees.
    function previewRollover(uint256 id, uint256 yield) public view returns (uint256, uint256, uint256) {
        return _previewRollover(id, yield);
    }

    function _modifyDebtPosition(uint256 id, uint256 deltaGenerator, uint256 deltaYield)
        internal
        isDebtSlice(id)
        returns (uint256, uint256) {

        DebtSlice storage slice = debtSlices[id];

        // Update generator shares and deposit the tokens
        uint256 newTotalShares;
        uint256 deltaShares;
        uint256 oldTotalTokens = totalTokens();
        if (totalShares == 0 || oldTotalTokens == 0) {
            newTotalShares = deltaGenerator;
            deltaShares = deltaGenerator;
        } else {
            newTotalShares = (oldTotalTokens + deltaGenerator) * totalShares / oldTotalTokens;
            deltaShares = newTotalShares - totalShares;
        }

        generatorToken.safeTransferFrom(msg.sender, address(this), deltaGenerator);
        generatorToken.safeApprove(address(yieldSource), 0);
        generatorToken.safeApprove(address(yieldSource), deltaGenerator);
        yieldSource.deposit(deltaGenerator, false);

        // Update NPV debt for the slice
        (uint256 npv, uint256 fees) = _previewDebtSlice(deltaGenerator, deltaYield);
        slice.npvDebt = npv;
        slice.blockTimestamp = uint128(block.timestamp);
        slice.shares += deltaShares;
        slice.tokens += deltaGenerator;

        totalShares = newTotalShares;

        return (npv, fees);
    }

    /// @notice Lock yield generating tokens into a slice, in exchange for NPV tokens.
    /// @param owner Owner of the resulting debt slice, entitled to transfer the slice and unlock underlying.
    /// @param recipient Recipient of the NPV tokens minted.
    /// @param amountGenerator Amount of yield generating tokens to lock.
    /// @param amountYield Amount of yield to lock.
    /// @param memo Optional memo data to associate with the yield slice.
    /// @return ID of the debt slice.
    function debtSlice(address owner,
                       address recipient,
                       uint256 amountGenerator,
                       uint256 amountYield,
                       bytes calldata memo)
        external
        nonReentrant
        noDust(amountGenerator)
        validAddress(recipient)
        returns (uint256) {

        uint256 id = nextId++;
        debtSlices[id] = DebtSlice({
            owner: owner,
            blockTimestamp: 0,
            unlockedBlockTimestamp: 0,
            shares: 0,
            tokens: 0,
            npvDebt: 0,
            memo: memo });

        (uint256 npv, uint256 fees) = _modifyDebtPosition(id, amountGenerator, amountYield);

        npvToken.mint(recipient, npv - fees);
        npvToken.mint(treasury, fees);
        activeNPV += npv;

        _modifyCreditPosition(UNALLOC_ID, int256(npv));
        _recordData();

        emit SliceDebt(owner, id, amountGenerator, amountYield, npv, fees);
        
        return id;
    }

    /// @notice Allow an address to rollover an owned debt slice.
    /// @param id The debt slice to approve for rollover.
    /// @param who The address to approve for rollover.
    /// @param amountYield The exact amount to approve for rollover.
    function approveRollover(uint256 id, address who, uint256 amountYield)
        external
        nonReentrant
        debtSliceOwner(id) {

        approvedRollover[id][who] = amountYield;
    }

    /// @notice Rollover a debt slice by taking out a new loan, and mint new NPV tokens.
    /// @param id The debt slice to rollover.
    /// @param recipient The recipient of minted NPV tokens.
    /// @param amountYield The amount of yield to be commited into the slice.
    /// @return The amount of new NPV tokens minted.
    function rollover(uint256 id, address recipient, uint256 amountYield)
        external
        nonReentrant
        returns (uint256) {

        require(debtSlices[id].owner == msg.sender ||
                approvedRollover[id][msg.sender] == amountYield,
                "YS: only owner or approved");

        (uint256 remainingNPV,
         uint256 incrementalNPV,
         uint256 incrementalFees) = _previewRollover(id, amountYield);
        require(incrementalNPV > 0, "YS: cannot rollover");

        DebtSlice storage slice = debtSlices[id];

        slice.blockTimestamp = uint128(block.timestamp);
        slice.npvDebt = remainingNPV + incrementalNPV;
        
        npvToken.mint(recipient, incrementalNPV - incrementalFees);
        npvToken.mint(treasury, incrementalFees);
        activeNPV += incrementalNPV;

        _modifyCreditPosition(UNALLOC_ID, int256(incrementalNPV));
        _recordData();
        approvedRollover[id][msg.sender] = 0;

        emit RolloverDebt(slice.owner,
                          id,
                          amountYield,
                          remainingNPV + incrementalNPV,
                          incrementalFees);

        return incrementalNPV;
    }

    /// @notice Mint NPV tokens from yield at 1:1 rate.
    /// @param recipient Recipient of the NPV tokens minted.
    /// @param amount The amount of yield tokens to exchange for NPV tokens.
    function mintFromYield(address recipient, uint256 amount)
        external
        validAddress(recipient) {

        IERC20(yieldToken).safeTransferFrom(msg.sender, address(this), amount);
        npvToken.mint(recipient, amount);
        activeNPV += amount;
        cumulativePaidYield += amount;
        _recordData();

        emit MintFromYield(recipient, amount);
    }

    /// @notice Pay off a debt slice using NPV tokens.
    /// @param id ID of the debt slice to pay.
    /// @param amount Amount of NPV tokens to pay off.
    /// @return Actual amouhnt of NPV tokens used to pay off.
    function payDebt(uint256 id, uint256 amount)
        external
        nonReentrant
        isDebtSlice(id) returns (uint256) {

        DebtSlice storage slice = debtSlices[id];
        require(slice.unlockedBlockTimestamp == 0, "YS: already unlocked");

        ( , uint256 npvGen, ) = generatedDebt(id);
        uint256 left = npvGen > slice.npvDebt ? 0 : slice.npvDebt - npvGen;
        uint256 actual = _min(left, amount);
        IERC20(npvToken).safeTransferFrom(msg.sender, address(this), actual);
        slice.npvDebt -= actual;
        npvToken.burn(address(this), actual);
        activeNPV -= actual;

        emit PayDebt(id, actual);

        return actual;
    }

    /// @notice Transfer ownership of a yield slice.
    /// @param id ID of the slice to transfer.
    /// @param recipient Recipient of the transfer
    function transferOwnership(uint256 id, address recipient)
        external
        nonReentrant
        validAddress(recipient)
        isSlice(id) {

        if (debtSlices[id].owner != address(0)) {
            DebtSlice storage slice = debtSlices[id];
            require(recipient != slice.owner, "YS: transfer owner");
            require(slice.owner == msg.sender, "YS: only debt slice owner");
            slice.owner = recipient;
        } else {
            CreditSlice storage slice = creditSlices[id];
            require(recipient != slice.owner, "YS: transfer owner");
            require(slice.owner == msg.sender, "YS: only credit slice owner");
            _claim(id, 0);
            slice.owner = recipient;
        }

        emit TransferOwnership(id, recipient);
    }

    /// @notice Unlock the underlying tokens for a debt slice, if possible. Excess yield generated will be refunded.
    /// @dev Unlocker role may unlock a debt slice, to prevent excess refund loss for the owner.
    /// @param id ID of the debt slice.
    function unlockDebtSlice(uint256 id) external nonReentrant debtSliceOwnerOrUnlocker(id) {
        DebtSlice storage slice = debtSlices[id];
        require(slice.unlockedBlockTimestamp == 0, "YS: already unlocked");

        ( , uint256 npvGen, uint256 refund) = generatedDebt(id);

        require(npvGen >= slice.npvDebt, "YS: npv debt");

        if (refund > 0) {
            _harvest();
            uint256 balance = IERC20(yieldToken).balanceOf(address(this));
            IERC20(yieldToken).safeTransfer(slice.owner, _min(balance, refund));
        }

        uint256 amount = _min(yieldSource.amountGenerator(), tokens(id));
        yieldSource.withdraw(amount, false, slice.owner);
        activeNPV -= slice.npvDebt;
        totalShares -= slice.shares;

        slice.unlockedBlockTimestamp = uint128(block.timestamp);

        emit UnlockDebtSlice(slice.owner, id);
    }

    function _creditFees(uint256 npv) internal view returns (uint256) {
        return (npv * creditFee) / FEE_DENOM;
    }

    function creditFees(uint256 npv) external view returns (uint256) {
        return _creditFees(npv);
    }

    /// @notice Modify a credit slice's NPV values.
    /// @dev Here be dragons: Pay careful attention to which timestamp the NPV values reference.
    /// @param id The credit slice to modify.
    /// @param deltaNPV Change in NPV tokens, relative to the creation timestamp of the slice.
    function _modifyCreditPosition(uint256 id, int256 deltaNPV) internal isCreditSlice(id) {
        if (deltaNPV == 0) return;
        CreditSlice storage slice = creditSlices[id];

        // The new NPV credited will be the existing NPV's value shifted
        // forward to the current timestamp, subtracting the already generated
        // NPV to this point.
        ( , uint256 npvGen, uint256 claimable) = generatedCredit(id);

        uint256 shiftedNPV = discounter.shiftForward(block.timestamp - uint256(slice.blockTimestamp),
                                                     slice.npvCredit - npvGen);

        // Checkpoint what we can claim as pending, and set claimed to zero
        // as it is now relative to the new timestamp.
        slice.blockTimestamp = uint128(block.timestamp);
        slice.pending = claimable;
        slice.claimed = 0;

        uint256 secondsFromCreation = block.timestamp - uint256(slice.createdTimestamp);

        // Update npvCredit and npvTokens. Carefully track which timestamp they are
        // relative to. The npvCredit field is the slice's entitled NPV relative to
        // slice.blockTimestamp. The npvTokens field is the slice's locked NPV tokens,
        // and can be used to compute their entitled NPV relative to the creation
        // timestamp.
        if (deltaNPV >= 0) {
            slice.npvCredit = shiftedNPV + discounter.shiftForward(secondsFromCreation,
                                                                   uint256(deltaNPV));
            slice.npvTokens += uint256(deltaNPV);
        } else {
            slice.npvCredit = shiftedNPV - discounter.shiftForward(secondsFromCreation,
                                                                   uint256(-deltaNPV));
            slice.npvTokens -= uint256(-deltaNPV);
        }
    }

    /// @notice Exchange NPV tokens for future yield, in the form of a credit slice.
    /// @param npv Amount of NPV tokens to swap.
    /// @param recipient Recipient of the credit slice.
    /// @param memo Optional memo data to associate with the yield slice.
    /// @return ID of the credit slice.
    function creditSlice(uint256 npv, address recipient, bytes calldata memo)
        external
        nonReentrant
        validAddress(recipient)
        returns (uint256) {

        uint256 fees = _creditFees(npv);

        IERC20(npvToken).safeTransferFrom(msg.sender, address(this), npv);
        IERC20(npvToken).safeTransfer(treasury, fees);

        CreditSlice storage unalloc = creditSlices[UNALLOC_ID];

        // Compute the unallocated slice's generated NPV and claimable amounts,
        // relative to the original timestamp. Record this as pending yield, and
        // update the remaining NPV, if any.
        {
            (, uint256 npvGen, uint256 claimable) = generatedCredit(UNALLOC_ID);
            unalloc.npvCredit -= npvGen;
            unalloc.pending = claimable;
        }

        // Shift the unallocated slice's remaining NPV credit such that it becomes
        // relative to the current timestamp.
        unalloc.npvCredit = discounter.shiftForward(block.timestamp - uint256(unalloc.blockTimestamp),
                                                    unalloc.npvCredit);

        // Compute the proportional share of vested, pending yield that will go to
        // the new slice.
        uint256 pendingShare = unalloc.pending * (npv - fees) / unalloc.npvTokens;

        // Compute the proportional share of remaining NPV credit that will go to the
        // new slice.
        uint256 npvCredit = unalloc.npvCredit * (npv - fees) / unalloc.npvTokens;

        // Update the unallocated slice
        unalloc.blockTimestamp = uint128(block.timestamp);
        unalloc.pending -= pendingShare;
        unalloc.npvCredit -= npvCredit;
        unalloc.npvTokens -= npv;

        uint256 id = nextId++;
        CreditSlice memory slice = CreditSlice({
            owner: recipient,
            createdTimestamp: uint128(block.timestamp),
            blockTimestamp: uint128(block.timestamp),
            npvCredit: npvCredit,
            npvTokens: npv - fees,
            pending: pendingShare,
            claimed: 0,
            memo: memo });
        creditSlices[id] = slice;

        emit SliceCredit(recipient, id, npv, fees);

        return id;
    }

    function _claim(uint256 id, uint256 limit) internal returns (uint256) {
        CreditSlice storage slice = creditSlices[id];
        ( , uint256 npvGen, uint256 claimable) = generatedCredit(id);

        if (claimable == 0) return 0;

        _harvest();
        uint256 amount = _min(claimable, yieldToken.balanceOf(address(this)));
        if (limit > 0) {
            amount = _min(limit, amount);
        }
        yieldToken.safeTransfer(slice.owner, amount);
        slice.claimed += amount;

        if (npvGen == slice.npvCredit) {
            npvToken.burn(address(this), slice.npvTokens);
        }

        emit Claimed(id, amount);

        return amount;
    }

    /// @notice Claim yield from a credit slice.
    /// @param id ID of the credit slice.
    /// @param limit Max amount of yield to claim, where 0 is no limit.
    /// @return Amount of yield claimed.
    function claim(uint256 id, uint256 limit)
        external
        nonReentrant
        creditSliceOwner(id) returns (uint256) {

        return _claim(id, limit);
    }

    function withdrawableNPV(uint256 id)
        public
        view
        isCreditSlice(id)
        returns (uint256) {

        CreditSlice storage slice = creditSlices[id];

        // Compute the NPV credit available relative to slice's timestamp,
        // and shift that value backwards such that it is becomes relative
        // to the creation timestamp.
        ( , uint256 npvGen, ) = generatedCredit(id);
        return discounter.shiftBackward(block.timestamp - uint256(slice.createdTimestamp),
                                        slice.npvCredit - npvGen);
    }

    /// @notice Withdraw NPV tokens from a credit slice, if possible.
    /// @param id ID of the credit slice.
    /// @param recipient Recipient of the NPV tokens.
    /// @param amount Amount of NPV to withdraw.
    function withdrawNPV(uint256 id,
                         address recipient,
                         uint256 amount)
        external
        nonReentrant
        validAddress(recipient)
        creditSliceOwner(id) {

        uint256 available = withdrawableNPV(id);

        if (amount == 0) {
            amount = available;
        }

        require(amount <= available, "YS: insufficient NPV");

        npvToken.transfer(recipient, amount);
        _modifyCreditPosition(id, -int256(amount));
        _modifyCreditPosition(UNALLOC_ID, int256(amount));

        emit WithdrawNPV(recipient, id, amount);
    }

    /// @notice Amount of NPV debt remaining for debt slice.
    /// @param id ID of the debt slice.
    /// @return Amount of NPV debt remaining.
    function remaining(uint256 id) external view returns (uint256) {
        ( , uint256 npvGen, ) = generatedDebt(id);
        return debtSlices[id].npvDebt - npvGen;
    }

    /// @notice Yield generated by a debt slice.
    /// @param id ID of the debt slice.
    /// @return Total nominal yield generated.
    /// @return NPV of the yield generated, relative to slice creation.
    /// @return Amount of yield tokens to refund upon unlock.
    function generatedDebt(uint256 id) public view returns (uint256, uint256, uint256) {
        DebtSlice storage slice = debtSlices[id];
        uint256 nominal = 0;
        uint256 npv = 0;
        uint256 refund = 0;
        uint256 last = slice.unlockedBlockTimestamp == 0 ? block.timestamp : slice.unlockedBlockTimestamp;

        for (uint256 i = slice.blockTimestamp;
             i < last;
             i += discounter.discountPeriod()) {

            uint256 end = _min(last - 1, i + discounter.discountPeriod());
            uint256 yts = debtData.yieldPerTokenPerSecond(uint128(i),
                                                          uint128(end),
                                                          totalTokens(),
                                                          cumulativeYield());

            uint256 yield = (yts * (end - i) * slice.tokens) / debtData.PRECISION_FACTOR();
            uint256 pv = discounter.shiftBackward(end - slice.blockTimestamp, yield);

            if (npv == slice.npvDebt) {
                refund += yield;
            } else if (npv + pv > slice.npvDebt) {
                uint256 owed = discounter.shiftForward(end - slice.blockTimestamp,
                                                       slice.npvDebt - npv);
                uint256 leftover = yield - owed;
                nominal += owed;
                refund += leftover;
                npv = slice.npvDebt;
            } else {
                npv += pv;
                nominal += yield;
            }
        }

        return (nominal, npv, refund);
    }

    /// @notice Yield generated by a credit slice.
    /// @param id ID of the credit slice.
    /// @return Total nominal yield generated.
    /// @return NPV of the yield generated, relative to slice creation.
    /// @return Amount of yield tokens claimable for this slice.
    function generatedCredit(uint256 id) public view returns (uint256, uint256, uint256) {
        CreditSlice storage slice = creditSlices[id];
        uint256 nominal = 0;
        uint256 npv = 0;
        uint256 claimable = 0;

        for (uint256 i = slice.blockTimestamp;
             npv < slice.npvCredit && i < block.timestamp;
             i += discounter.discountPeriod()) {

            uint256 end = _min(block.timestamp - 1, i + discounter.discountPeriod());
            uint256 yts = creditData.yieldPerTokenPerSecond(uint128(i),
                                                            uint128(end),
                                                            activeNPV,
                                                            cumulativeYieldCredit());

            uint256 yield = (yts * (end - i) * slice.npvTokens) / creditData.PRECISION_FACTOR();
            uint256 pv = discounter.shiftBackward(end - slice.blockTimestamp, yield);

            if (npv + pv > slice.npvCredit) {
                pv = slice.npvCredit - npv;
                yield = discounter.shiftForward(end - slice.blockTimestamp, pv);
            }

            claimable += yield;
            nominal += yield;
            npv += pv;
        }

        return (slice.pending + nominal,
                npv,
                slice.pending + claimable - slice.claimed);
    }
}
