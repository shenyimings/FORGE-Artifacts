// SPDX-License-Identifier: MIT
pragma solidity ^0.8.19;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Strings.sol";

/**
 * @title RowaVesting
 * @author guraygrkn@protonmail.com
 * @notice Vesting contract for ROWA Token (ROWA) for Value Generation Pool, LP & Staking Rewards, Public Sale, Private Sale, Seed Sale, Initial Liquidity, Reserve, Team, Advisors, Partnerships & Marketing.
 */
contract RowaVesting is Ownable, ReentrancyGuard {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    uint8 public constant DECIMALS = 5;
    uint16 public constant PERCENTAGE_MULTIPLIER = 10_000;

    // Vesting Information
    string public constant VGP_VESTING_NAME = "VALUE_GENERATION_POOL";
    uint256 public constant TOTAL_VGP_VESTED =
        360_000_000 * 10 ** uint256(DECIMALS); // Vesting Grant Program
    uint256 public totalVGPVested;
    uint256 public constant VGP_VESTING_DURATION = 50 * 30 days; // 50 months
    uint256 public constant VGP_VESTING_PERIOD = 1 * 30 days; // 1 month
    uint256 public VGP_INITIAL_VESTING_PERCENTAGE = 200; // 2% initial unlock
    address private _VGP_FUND;

    string public constant LP_VESTING_NAME = "LP_AND_STAKING_REWARDS";
    uint256 public constant TOTAL_LP_VESTED =
        130_000_000 * 10 ** uint256(DECIMALS); // LP & Staking Rewards
    uint256 public totalLPVested;
    uint256 public constant LP_VESTING_DURATION = 36 * 30 days; // 36 months
    uint256 public constant LP_VESTING_PERIOD = 1 * 30 days; // 1 month
    uint256 public LP_INITIAL_VESTING_PERCENTAGE = 277; // 2% initial unlock
    address private _LP_FUND;

    string public constant PS_VESTING_NAME = "PUBLIC_SALE";
    uint256 public constant TOTAL_PS_VESTED =
        70_000_000 * 10 ** uint256(DECIMALS); // Public Sale
    uint256 public totalPSVested;
    uint256 public constant PS_VESTING_DURATION = 4 * 30 days; // 4 months
    uint256 public constant PS_VESTING_PERIOD = 1 * 30 days; // 1 month
    uint256 public PS_INITIAL_VESTING_PERCENTAGE = 2500; // 25% initial unlock

    string public constant PRIVS_VESTING_NAME = "PRIVATE_SALE";
    uint256 public constant TOTAL_PRIVS_VESTED =
        40_000_000 * 10 ** uint256(DECIMALS); // Private Sale
    uint256 public totalPRIVSVested;
    uint256 public constant PRIVS_CLIFF_DURATION = 4 * 30 days; // 4 months
    uint256 public constant PRIVS_VESTING_DURATION = 12 * 30 days; // 12 months
    uint256 public constant PRIVS_VESTING_PERIOD = 1 * 30 days; // 1 month
    uint256 public PRIVS_INITIAL_VESTING_PERCENTAGE = 500; // 5% initial unlock

    string public constant SEEDS_VESTING_NAME = "SEED_SALE";
    uint256 public constant TOTAL_SEEDS_VESTED =
        30_000_000 * 10 ** uint256(DECIMALS); // Seed Sale
    uint256 public totalSEEDSVested;
    uint256 public constant SEEDS_CLIFF_DURATION = 4 * 30 days; // 4 months
    uint256 public constant SEEDS_VESTING_DURATION = 12 * 30 days; // 12 months
    uint256 public constant SEEDS_VESTING_PERIOD = 1 * 30 days; // 1 month
    uint256 public SEEDS_INITIAL_VESTING_PERCENTAGE = 500; // 5% initial unlock

    string public constant LIQ_VESTING_NAME = "INITIAL_LIQUIDITY";
    uint256 public constant TOTAL_LIQ_VESTED =
        30_000_000 * 10 ** uint256(DECIMALS); // Initial Liquidity
    uint256 public totalLIQVested;
    uint256 public constant LIQ_INITIAL_VESTING_AMOUNT = TOTAL_LIQ_VESTED; // 100% initial unlock
    uint256 public constant LIQ_INITIAL_VESTING_PERCENTAGE = 10_000; // 100% unlock
    address private _LIQ_FUND;

    string public constant RESERVE_VESTING_NAME = "RESERVE";
    uint256 public constant TOTAL_RESERVE_VESTED =
        50_000_000 * 10 ** uint256(DECIMALS); // Reserve
    uint256 public totalRESERVEVested;
    uint256 public constant RESERVE_VESTING_DURATION = 5 * 30 days; // 5 months
    uint256 public constant RESERVE_VESTING_PERIOD = 1 * 30 days; // 1 month
    uint256 public RESERVE_INITIAL_VESTING_PERCENTAGE = 2_000; // 20% initial unlock
    address private _RESERVE_FUND;

    string public constant TEAM_VESTING_NAME = "TEAM";
    uint256 public constant TOTAL_TEAM_VESTED =
        150_000_000 * 10 ** uint256(DECIMALS); // Team
    uint256 public totalTEAMVested;
    uint256 public constant TEAM_CLIFF_DURATION = 12 * 30 days; // 12 months
    uint256 public constant TEAM_VESTING_DURATION = 36 * 30 days; // 36 months
    uint256 public constant TEAM_VESTING_PERIOD = 1 * 30 days; // 1 month
    uint256 public TEAM_INITIAL_VESTING_PERCENTAGE = 0; // 0% initial unlock

    string public constant ADVISORS_VESTING_NAME = "ADVISORS";
    uint256 public constant TOTAL_ADVISORS_VESTED =
        40_000_000 * 10 ** uint256(DECIMALS); // Advisors
    uint256 public totalADVISORSVested;
    uint256 public constant ADVISORS_VESTING_CLIFF = 12 * 30 days; // 12 months
    uint256 public constant ADVISORS_VESTING_DURATION = 16 * 30 days; // 16 months
    uint256 public constant ADVISORS_VESTING_PERIOD = 1 * 30 days; // 1 month
    uint256 public ADVISORS_VESTING_AMOUNT = TOTAL_ADVISORS_VESTED.div(16); // 1 month vesting
    uint256 public ADVISORS_INITIAL_VESTING_PERCENTAGE = 0; // 0% initial unlock

    string public constant PARTNERSHIPS_VESTING_NAME =
        "PARTNERSHIPS_AND_MARKETING";
    uint256 public constant TOTAL_PARTNERSHIPS_VESTED =
        100_000_000 * 10 ** uint256(DECIMALS); // Partnerships & Marketing
    uint256 public totalPARTNERSHIPSVested;
    uint256 public constant PARTNERSHIPS_VESTING_DURATION = 5 * 30 days; // 5 months
    uint256 public constant PARTNERSHIPS_VESTING_PERIOD = 1 * 30 days; // 1 month
    uint256 public PARTNERSHIPS_INITIAL_VESTING_PERCENTAGE = 2_000; // 20% unlock

    /**
     * @dev Struct for the vesting schedule of a token holder. A vesting schedule is a sequence of slices of tokens that are released to the beneficiary progressively over time.
     * The amount of tokens released at each slice is calculated from the vesting schedule parameters.
     * The vesting schedule parameters are immutable once the vesting schedule is created.
     */
    struct VestingSchedule {
        // whether or not the vesting has been initialized
        bool initialized;
        // name of the vesting schedule
        string name;
        // beneficiary of tokens after they are released
        address beneficiary;
        // cliff period in seconds
        uint256 cliff;
        // start time of the vesting period
        uint256 start;
        // duration of the vesting period in seconds
        uint256 duration;
        // period in seconds between slices
        uint256 period;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        // amount of tokens released until now
        uint256 amountReleased;
        // amount of tokens to be released at the start of the vesting
        uint256 amountInitial;
        // whether or not the vesting has been revoked
        bool revoked;
        // revokable flag
        bool revokable;
    }

    // address of the ERC20 token
    IERC20 private immutable _token;

    bytes32[] private vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    uint256 private vestingSchedulesTotalAmount;
    mapping(address => uint256) private holdersVestingCount;

    event Released(uint256 amount);
    event Revoked();

    /**
     * @dev Reverts if no vesting schedule matches the passed identifier.
     * @param vestingScheduleId Identifier of the vesting schedule.
     */
    modifier onlyInitialized(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        _;
    }

    /**
     * @dev Reverts if the vesting schedule does not exist or has been revoked.
     * @param vestingScheduleId Identifier of the vesting schedule.
     */
    modifier onlyActive(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true);
        require(vestingSchedules[vestingScheduleId].revoked == false);
        _;
    }

    /**
     * @dev Creates a vesting contract.
     * @param token_ address of the ERC20 token contract
     */
    constructor(
        address token_,
        address VGP_FUND_,
        address LP_FUND_,
        address LIQ_FUND_,
        address RESERVE_FUND_
    ) {
        require(token_ != address(0x0));
        require(VGP_FUND_ != address(0x0));
        require(LP_FUND_ != address(0x0));
        require(LIQ_FUND_ != address(0x0));
        require(RESERVE_FUND_ != address(0x0));
        _token = IERC20(token_);
        _VGP_FUND = VGP_FUND_;
        _LP_FUND = LP_FUND_;
        _LIQ_FUND = LIQ_FUND_;
        _RESERVE_FUND = RESERVE_FUND_;
    }

    receive() external payable {}

    fallback() external payable {}

    /**
     * @dev Returns the number of vesting schedules associated to a beneficiary.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCountByBeneficiary(
        address _beneficiary
    ) external view returns (uint256) {
        return holdersVestingCount[_beneficiary];
    }

    /**
     * @dev Returns the vesting schedule id at the given index.
     * @return the vesting id
     */
    function getVestingIdAtIndex(
        uint256 index
    ) external view returns (bytes32) {
        require(
            index < getVestingSchedulesCount(),
            "TokenVesting: index out of bounds"
        );
        return vestingSchedulesIds[index];
    }

    /**
     * @notice Returns the vesting schedule information for a given holder and index.
     * @return the vesting schedule structure information
     */
    function getVestingScheduleByAddressAndIndex(
        address holder,
        uint256 index
    ) external view returns (VestingSchedule memory) {
        return
            getVestingSchedule(
                computeVestingScheduleIdForAddressAndIndex(holder, index)
            );
    }

    /**
     * @notice Returns the total amount of vesting schedules.
     * @return the total amount of vesting schedules
     */
    function getVestingSchedulesTotalAmount() external view returns (uint256) {
        return vestingSchedulesTotalAmount;
    }

    /**
     * @dev Returns the address of the ERC20 token managed by the vesting contract.
     */
    function getTokenAddress() external view returns (address) {
        return address(_token);
    }

    /**
     * @dev create a vesting schedule for a beneficiary. It is meant to be called by the owner and internally.
     * @param beneficiary_ address of the beneficiary to whom vested tokens are transferred
     * @param name_ name of the vesting schedule
     * @param start_ the time (as Unix time) at which point vesting starts
     * @param cliff_ duration in seconds of the cliff in which tokens will begin to vest
     * @param duration_ duration in seconds of the period in which the tokens will vest
     * @param slicePeriodSeconds_ period in seconds between slices
     * @param amount_ total amount of tokens to be vested
     * @param amountInitial_ amount of tokens to be released at the start of the vesting
     * @param revokable_ whether the vesting is revokable or not
     * @return the vesting schedule structure information
     */
    function _createVestingSchedule(
        address beneficiary_,
        string memory name_,
        uint256 start_,
        uint256 cliff_,
        uint256 duration_,
        uint256 slicePeriodSeconds_,
        uint256 amount_,
        uint256 amountInitial_,
        bool revokable_
    ) private returns (bytes32) {
        require(
            this.getWithdrawableAmount() >= amount_,
            "TokenVesting: cannot create vesting schedule because not sufficient tokens"
        );
        bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(
            beneficiary_
        );

        vestingSchedules[vestingScheduleId] = VestingSchedule(
            true,
            name_,
            beneficiary_,
            cliff_,
            start_,
            duration_,
            slicePeriodSeconds_,
            amount_,
            0,
            amountInitial_,
            false,
            revokable_
        );

        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(amount_);
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[beneficiary_];
        holdersVestingCount[beneficiary_] = currentVestingCount.add(1);

        return vestingScheduleId;
    }

    /**
     * @notice Revokes the vesting schedule for given identifier.
     * @param vestingScheduleId the vesting schedule identifier
     */
    function revoke(
        bytes32 vestingScheduleId
    ) public onlyOwner onlyActive(vestingScheduleId) {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        require(
            vestingSchedule.revokable == true,
            "TokenVesting: vesting is not revocable"
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        if (vestedAmount > 0) {
            release(vestingScheduleId, vestedAmount);
        }
        uint256 unreleased = vestingSchedule.amountTotal.sub(
            vestingSchedule.amountReleased
        );

        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(
            unreleased
        );

        if (equal(vestingSchedule.name, PS_VESTING_NAME)) {
            totalPSVested = totalPSVested.sub(unreleased);
        } else if (equal(vestingSchedule.name, PRIVS_VESTING_NAME)) {
            totalPRIVSVested = totalPRIVSVested.sub(unreleased);
        } else if (equal(vestingSchedule.name, SEEDS_VESTING_NAME)) {
            totalSEEDSVested = totalSEEDSVested.sub(unreleased);
        } else if (equal(vestingSchedule.name, TEAM_VESTING_NAME)) {
            totalTEAMVested = totalTEAMVested.sub(unreleased);
        } else if (equal(vestingSchedule.name, ADVISORS_VESTING_NAME)) {
            totalADVISORSVested = totalADVISORSVested.sub(unreleased);
        } else if (equal(vestingSchedule.name, PARTNERSHIPS_VESTING_NAME)) {
            totalPARTNERSHIPSVested = totalPARTNERSHIPSVested.sub(unreleased);
        }

        vestingSchedule.revoked = true;
    }

    /**
     * @notice Withdraw the specified amount if possible.
     * @param amount the amount to withdraw
     */
    function withdraw(uint256 amount) public nonReentrant onlyOwner {
        require(
            getWithdrawableAmount() >= amount,
            "TokenVesting: not enough withdrawable funds"
        );
        _token.safeTransfer(owner(), amount);
    }

    /**
     * @notice Release vested amount of tokens.
     * @param vestingScheduleId the vesting schedule identifier
     * @param amount the amount to release
     */
    function release(
        bytes32 vestingScheduleId,
        uint256 amount
    ) public nonReentrant onlyActive(vestingScheduleId) {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        bool isBeneficiary = msg.sender == vestingSchedule.beneficiary;
        bool isOwner = msg.sender == owner();
        require(
            isBeneficiary || isOwner,
            "TokenVesting: only beneficiary and owner can release vested tokens"
        );
        uint256 vestedAmount = _computeReleasableAmount(vestingSchedule);
        require(
            vestedAmount >= amount,
            "TokenVesting: cannot release tokens, not enough vested tokens"
        );
        vestingSchedule.amountReleased = vestingSchedule.amountReleased.add(
            amount
        );
        address payable beneficiaryPayable = payable(
            vestingSchedule.beneficiary
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(amount);
        _token.safeTransfer(beneficiaryPayable, amount);
    }

    /**
     * @dev Returns the number of vesting schedules managed by this contract.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCount() public view returns (uint256) {
        return vestingSchedulesIds.length;
    }

    /**
     * @notice Computes the vested amount of tokens for the given vesting schedule identifier.
     * @return the vested amount
     */
    function computeReleasableAmount(
        bytes32 vestingScheduleId
    ) public view onlyActive(vestingScheduleId) returns (uint256) {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(
        bytes32 vestingScheduleId
    ) public view returns (VestingSchedule memory) {
        return vestingSchedules[vestingScheduleId];
    }

    /**
     * @dev Returns the amount of tokens that can be withdrawn by the owner.
     * @return the amount of tokens
     */
    function getWithdrawableAmount() public view returns (uint256) {
        return _token.balanceOf(address(this)).sub(vestingSchedulesTotalAmount);
    }

    /**
     * @dev Computes the next vesting schedule identifier for a given holder address.
     */
    function computeNextVestingScheduleIdForHolder(
        address holder
    ) public view returns (bytes32) {
        return
            computeVestingScheduleIdForAddressAndIndex(
                holder,
                holdersVestingCount[holder]
            );
    }

    /**
     * @dev Returns the last vesting schedule for a given holder address.
     */
    function getLastVestingScheduleForHolder(
        address holder
    ) public view returns (VestingSchedule memory) {
        return
            vestingSchedules[
                computeVestingScheduleIdForAddressAndIndex(
                    holder,
                    holdersVestingCount[holder] - 1
                )
            ];
    }

    /**
     * @dev Computes the vesting schedule identifier for an address and an index.
     */
    function computeVestingScheduleIdForAddressAndIndex(
        address holder,
        uint256 index
    ) public pure returns (bytes32) {
        return keccak256(abi.encodePacked(holder, index));
    }

    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @return the amount of releasable tokens
     */
    function _computeReleasableAmount(
        VestingSchedule memory vestingSchedule
    ) internal view returns (uint256) {
        uint256 currentTime = getCurrentTime();
        if (vestingSchedule.amountReleased < vestingSchedule.amountInitial) {
            return
                vestingSchedule.amountInitial.sub(
                    vestingSchedule.amountReleased
                );
        }

        if (
            (currentTime < vestingSchedule.start) ||
            vestingSchedule.revoked == true
        ) {
            return 0;
        }

        if (
            currentTime >= vestingSchedule.start.add(vestingSchedule.duration)
        ) {
            return
                vestingSchedule.amountTotal.sub(vestingSchedule.amountReleased);
        }

        if (vestingSchedule.amountReleased >= vestingSchedule.amountTotal) {
            return 0;
        }

        uint256 timeFromStart = currentTime.sub(vestingSchedule.start);
        uint secondsPerSlice = vestingSchedule.period;
        uint256 vestedSlicePeriods = timeFromStart.div(secondsPerSlice);
        uint256 vestedSeconds = vestedSlicePeriods.mul(secondsPerSlice);
        uint256 vestedAmount = vestingSchedule
            .amountTotal
            .mul(vestedSeconds)
            .div(vestingSchedule.duration);
        vestedAmount = vestedAmount.sub(vestingSchedule.amountReleased);

        return vestedAmount;
    }

    /**
     * @dev Starts vgp token vesting for a given beneficiary.
     */
    function startVGPVesting() public onlyOwner {
        require(totalVGPVested == 0, "VGP vesting already started");

        uint256 currentTime = getCurrentTime();

        _createVestingSchedule(
            _VGP_FUND,
            VGP_VESTING_NAME,
            currentTime,
            0,
            VGP_VESTING_DURATION,
            VGP_VESTING_PERIOD,
            TOTAL_VGP_VESTED,
            getInitialVestingAmount(
                TOTAL_VGP_VESTED,
                VGP_INITIAL_VESTING_PERCENTAGE
            ),
            false
        );

        totalVGPVested = totalVGPVested.add(TOTAL_VGP_VESTED);
    }

    /**
     * @dev Starts lp token vesting for a given beneficiary.
     */
    function startLPVesting() public onlyOwner {
        require(totalLPVested == 0, "LP vesting already started");

        uint256 currentTime = getCurrentTime();

        _createVestingSchedule(
            _LP_FUND,
            LP_VESTING_NAME,
            currentTime,
            0,
            LP_VESTING_DURATION,
            LP_VESTING_PERIOD,
            TOTAL_LP_VESTED,
            getInitialVestingAmount(
                TOTAL_LP_VESTED,
                LP_INITIAL_VESTING_PERCENTAGE
            ),
            false
        );

        totalLPVested = totalLPVested.add(TOTAL_LP_VESTED);
    }

    /**
     * @dev Starts liq token vesting for a given beneficiary.
     */
    function startLiqVesting() public onlyOwner {
        require(totalLIQVested == 0, "Liq vesting already started");

        uint256 currentTime = getCurrentTime();

        _createVestingSchedule(
            _LIQ_FUND,
            LIQ_VESTING_NAME,
            currentTime,
            0,
            0,
            0,
            TOTAL_LIQ_VESTED,
            getInitialVestingAmount(
                TOTAL_LIQ_VESTED,
                LIQ_INITIAL_VESTING_PERCENTAGE
            ),
            false
        );

        totalLIQVested = totalLIQVested.add(TOTAL_LIQ_VESTED);
    }

    /**
     * @dev Starts reserve vesting for a given beneficiary.
     */
    function startReserveVesting() public onlyOwner {
        require(totalRESERVEVested == 0, "Reserve vesting already started");

        uint256 currentTime = getCurrentTime();

        _createVestingSchedule(
            _RESERVE_FUND,
            RESERVE_VESTING_NAME,
            currentTime,
            0,
            RESERVE_VESTING_DURATION,
            RESERVE_VESTING_PERIOD,
            TOTAL_RESERVE_VESTED,
            getInitialVestingAmount(
                TOTAL_RESERVE_VESTED,
                RESERVE_INITIAL_VESTING_PERCENTAGE
            ),
            false
        );

        totalRESERVEVested = totalRESERVEVested.add(TOTAL_RESERVE_VESTED);
    }

    /**
     * @dev Starts Public sale vesting for a given beneficiary.
     * @param beneficiary_ the beneficiary of the tokens
     * @param amount_ the amount of tokens to be vested
     * @notice revokable is set to false for public sale vesting as it is not possible to revoke tokens that have already been sold
     */
    function createPublicSaleVesting(
        address beneficiary_,
        uint256 amount_
    ) external onlyOwner {
        require(
            totalPSVested.add(amount_) <= TOTAL_PS_VESTED,
            "Public sale vesting amount exceeds total amount"
        );

        uint256 currentTime = getCurrentTime();

        _createVestingSchedule(
            beneficiary_,
            PS_VESTING_NAME,
            currentTime,
            0,
            PS_VESTING_DURATION,
            PS_VESTING_PERIOD,
            amount_,
            getInitialVestingAmount(amount_, PS_INITIAL_VESTING_PERCENTAGE),
            false
        );

        totalPSVested = totalPSVested.add(amount_);
    }

    /**
     * @dev Starts private sale token vesting for a given beneficiary.
     * @param beneficiary_ the beneficiary of the tokens
     * @param amount_ the amount of tokens to be vested
     * @notice revokable is set to false for private sale vesting as it is not possible to revoke tokens that have already been sold
     */
    function createPrivateSaleVesting(
        address beneficiary_,
        uint256 amount_
    ) external onlyOwner {
        require(
            totalPRIVSVested.add(amount_) <= TOTAL_PRIVS_VESTED,
            "Private sale vesting amount exceeds total amount"
        );

        uint256 currentTime = getCurrentTime();
        currentTime = currentTime.add(PRIVS_CLIFF_DURATION);

        _createVestingSchedule(
            beneficiary_,
            PRIVS_VESTING_NAME,
            currentTime,
            PRIVS_CLIFF_DURATION,
            PRIVS_VESTING_DURATION,
            PRIVS_VESTING_PERIOD,
            amount_,
            getInitialVestingAmount(amount_, PRIVS_INITIAL_VESTING_PERCENTAGE),
            false
        );

        totalPRIVSVested = totalPRIVSVested.add(amount_);
    }

    /**
     * @dev Starts seed sale token vesting for a given beneficiary.
     * @param beneficiary_ the beneficiary of the tokens
     * @param amount_ the amount of tokens to be vested
     * @param revokable_ whether the vesting is revocable or not
     */
    function createSeedSaleVesting(
        address beneficiary_,
        uint256 amount_,
        bool revokable_
    ) external onlyOwner {
        require(
            totalSEEDSVested.add(amount_) <= TOTAL_SEEDS_VESTED,
            "Seed sale vesting amount exceeds total amount"
        );

        uint256 currentTime = getCurrentTime();
        currentTime = currentTime.add(SEEDS_CLIFF_DURATION);

        _createVestingSchedule(
            beneficiary_,
            SEEDS_VESTING_NAME,
            currentTime,
            SEEDS_CLIFF_DURATION,
            SEEDS_VESTING_DURATION,
            SEEDS_VESTING_PERIOD,
            amount_,
            getInitialVestingAmount(amount_, SEEDS_INITIAL_VESTING_PERCENTAGE),
            revokable_
        );

        totalSEEDSVested = totalSEEDSVested.add(amount_);
    }

    /**
     * @dev Starts team vesting for a given beneficiary.
     * @param beneficiary_ the beneficiary of the tokens
     * @param amount_ the amount of tokens to be vested
     * @param revokable_ whether the vesting is revocable or not
     */
    function createTeamVesting(
        address beneficiary_,
        uint256 amount_,
        bool revokable_
    ) external onlyOwner {
        require(
            totalTEAMVested.add(amount_) <= TOTAL_TEAM_VESTED,
            "Team vesting amount exceeds total amount"
        );

        uint256 currentTime = getCurrentTime();
        currentTime = currentTime.add(TEAM_CLIFF_DURATION);

        _createVestingSchedule(
            beneficiary_,
            TEAM_VESTING_NAME,
            currentTime,
            TEAM_CLIFF_DURATION,
            TEAM_VESTING_DURATION,
            TEAM_VESTING_PERIOD,
            amount_,
            getInitialVestingAmount(amount_, TEAM_INITIAL_VESTING_PERCENTAGE),
            revokable_
        );

        totalTEAMVested = totalTEAMVested.add(amount_);
    }

    /**
     * @dev Starts advisor vesting for a given beneficiary.
     * @param beneficiary_ the beneficiary of the tokens
     * @param amount_ the amount of tokens to be vested
     * @param revokable_ whether the vesting is revocable or not
     */
    function createAdvisorVesting(
        address beneficiary_,
        uint256 amount_,
        bool revokable_
    ) external onlyOwner {
        require(
            totalADVISORSVested.add(amount_) <= TOTAL_ADVISORS_VESTED,
            "Advisor vesting amount exceeds total amount"
        );

        uint256 currentTime = getCurrentTime();
        currentTime = currentTime.add(ADVISORS_VESTING_CLIFF);

        _createVestingSchedule(
            beneficiary_,
            ADVISORS_VESTING_NAME,
            currentTime,
            ADVISORS_VESTING_CLIFF,
            ADVISORS_VESTING_DURATION,
            ADVISORS_VESTING_PERIOD,
            amount_,
            getInitialVestingAmount(
                amount_,
                ADVISORS_INITIAL_VESTING_PERCENTAGE
            ),
            revokable_
        );

        totalADVISORSVested = totalADVISORSVested.add(amount_);
    }

    /**
     * @dev Starts partnerships vesting for a given beneficiary.
     * @param beneficiary_ the beneficiary of the tokens
     * @param amount_ the amount of tokens to be vested
     * @param revokable_ whether the vesting is revocable or not
     */
    function createPartnershipsVesting(
        address beneficiary_,
        uint256 amount_,
        bool revokable_
    ) external onlyOwner {
        require(
            totalPARTNERSHIPSVested.add(amount_) <= TOTAL_PARTNERSHIPS_VESTED,
            "Partnerships vesting amount exceeds total amount"
        );

        uint256 currentTime = getCurrentTime();

        _createVestingSchedule(
            beneficiary_,
            PARTNERSHIPS_VESTING_NAME,
            currentTime,
            0,
            PARTNERSHIPS_VESTING_DURATION,
            PARTNERSHIPS_VESTING_PERIOD,
            amount_,
            getInitialVestingAmount(
                amount_,
                PARTNERSHIPS_INITIAL_VESTING_PERCENTAGE
            ),
            revokable_
        );

        totalPARTNERSHIPSVested = totalPARTNERSHIPSVested.add(amount_);
    }

    /**
     * @dev Returns the current time.
     */
    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    /**
     * @dev Returns initial vesting amount.
     */
    function getInitialVestingAmount(
        uint256 totalVested,
        uint256 initialVestingPercentage
    ) internal pure returns (uint256) {
        return
            totalVested.mul(initialVestingPercentage).div(
                PERCENTAGE_MULTIPLIER
            );
    }

    /**
     * @dev Returns true if the two strings are equal.
     */
    function equal(
        string memory a,
        string memory b
    ) internal pure returns (bool) {
        return keccak256(bytes(a)) == keccak256(bytes(b));
    }
}
