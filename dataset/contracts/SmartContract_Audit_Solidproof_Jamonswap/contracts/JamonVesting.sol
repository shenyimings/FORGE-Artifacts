// SPDX-License-Identifier: MIT
pragma solidity =0.8.11;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "@openzeppelin/contracts/security/Pausable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";
import "@openzeppelin/contracts/utils/Counters.sol";
import "./interfaces/IERC20MintBurn.sol";
import "./interfaces/IJamonVesting.sol";

interface IJamonShareVault {
    function totalStaked() external returns (uint256);
}

/**
 * @title JamonVesting
 * @notice Lock JamonV2 token rewards for 12 months.
 */
contract JamonVesting is IJamonVesting, Ownable, ReentrancyGuard, Pausable {
    //---------- Libraries ----------//
    using SafeMath for uint256;
    using SafeERC20 for IERC20MintBurn;
    using Counters for Counters.Counter;

    //---------- Contracts ----------//
    IERC20MintBurn private immutable jamonV2; // JamonV2 ERC20 contract
    IJamonShareVault private JamonShareVault; // JamonShare ERC20 contract
    address private bonus; // Address of Bonus contract

    //---------- Variables ----------//
    uint256 private vestingSchedulesTotalAmount; // Total JamonV2 token vested
    uint256 private constant month = 2629743 ; // 1 Month Timestamp.
    Counters.Counter private deposits; // Counter for a control of deposits, max 12 deposits one per month.
    uint256 public lastDeposit; // Last deposit in timestamp

    //---------- Storage -----------//
    struct VestingSchedule {
        bool initialized;
        // beneficiary of tokens after they are released
        address beneficiary;
        // cliff period in seconds
        uint256 cliff;
        // start time of the vesting period
        uint256 start;
        // total amount of tokens to be released at the end of the vesting
        uint256 amountTotal;
        // amount of tokens released
        uint256 released;
    }

    bytes32[] private vestingSchedulesIds;
    mapping(bytes32 => VestingSchedule) private vestingSchedules;
    mapping(address => uint256) private holdersVestingCount;

    //---------- Events -----------//
    event Vested(address indexed beneficiary, uint256 amount);
    event Released(address indexed beneficiary, uint256 amount);

    //---------- Constructor ----------//
    constructor(address jamonv2_) {
        require(jamonv2_ != address(0x0), "Invalid address");
        jamonV2 = IERC20MintBurn(jamonv2_);
        lastDeposit = block.timestamp.add(40 days); 
    }

    function initialize(address bonus_, address jsVault_) external onlyOwner {
        require(bonus == address(0x0), "Already initialized");
        require(
            bonus_ != address(0x0) && jsVault_ != address(0x0),
            "Invalid address"
        );
        bonus = bonus_;
        JamonShareVault = IJamonShareVault(jsVault_);
    }

    //---------- Modifiers ----------//
    /**
     * @dev Reverts if the vesting schedule does not exist.
     */
    modifier onlyIfVestingSchedule(bytes32 vestingScheduleId) {
        require(vestingSchedules[vestingScheduleId].initialized == true, "Invalid Id");
        _;
    }

    /**
     * @dev Reverts if the vesting schedule does not exist.
     */
    modifier onlyBonus() {
        require(_msgSender() == bonus, "Forbidden address");
        _;
    }

    //----------- Internal Functions -----------//
    /**
     * @dev Computes the releasable amount of tokens for a vesting schedule.
     * @return the amount of releasable tokens
     */
    function _computeReleasableAmount(VestingSchedule memory vestingSchedule)
        internal
        view
        returns (uint256)
    {
        uint256 currentTime = getCurrentTime();
        if ((currentTime < vestingSchedule.cliff)) {
            return 0;
        } else if (currentTime >= vestingSchedule.start.add(month.mul(12))) {
            return vestingSchedule.amountTotal.sub(vestingSchedule.released);
        } else {
            uint256 timeFromStart = currentTime.sub(vestingSchedule.start);
            uint256 vestedSlicePeriods = timeFromStart.div(month);
            uint256 vestedSeconds = vestedSlicePeriods.mul(month);
            uint256 vestedAmount = vestingSchedule
                .amountTotal
                .mul(vestedSeconds)
                .div(month.mul(12));
            vestedAmount = vestedAmount.sub(vestingSchedule.released);
            return vestedAmount;
        }
    }

    function getCurrentTime() internal view virtual returns (uint256) {
        return block.timestamp;
    }

    //----------- External Functions -----------//
    /**
     * @dev Returns the number of deposits sended to Jamon Share Vault.
     * @return the number of deposits to JamonShareVault
     */
    function depositsCount() external view override returns (uint256) {
        return deposits.current();
    }

    /**
     * @dev Returns the number of vesting schedules associated to a beneficiary.
     * @return the number of vesting schedules
     */
    function getVestingSchedulesCountByBeneficiary(address _beneficiary)
        external
        view
        returns (uint256)
    {
        return holdersVestingCount[_beneficiary];
    }

    /**
     * @dev Returns the vesting schedule id at the given index.
     * @return the vesting id
     */
    function getVestingIdAtIndex(uint256 index)
        external
        view
        returns (bytes32)
    {
        require(
            index < getVestingSchedulesCount(),
            "JamonVesting: index out of bounds"
        );
        return vestingSchedulesIds[index];
    }

    /**
     * @notice Returns the vesting schedule information for a given holder and index.
     * @return the vesting schedule structure information
     */
    function getVestingScheduleByAddressAndIndex(address holder, uint256 index)
        external
        view
        returns (VestingSchedule memory)
    {
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
    function getToken() external view returns (address) {
        return address(jamonV2);
    }

    /**
     * @notice Creates a new vesting schedule for a beneficiary.
     * @param _beneficiary address of the beneficiary to whom vested tokens are transferred
     * @param _amount total amount of tokens to be released at the end of the vesting
     */
    function createVestingSchedule(address _beneficiary, uint256 _amount)
        public
        override
        whenNotPaused
        onlyBonus
    {
        require(_amount > 0, "JamonVesting: amount must be > 0");
        bytes32 vestingScheduleId = this.computeNextVestingScheduleIdForHolder(
            _beneficiary
        );
        uint256 start = block.timestamp;
        uint256 cliff = start.add(month);
        vestingSchedules[vestingScheduleId] = VestingSchedule(
            true,
            _beneficiary,
            cliff,
            start,
            _amount,
            0
        );
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.add(_amount);
        vestingSchedulesIds.push(vestingScheduleId);
        uint256 currentVestingCount = holdersVestingCount[_beneficiary];
        holdersVestingCount[_beneficiary] = currentVestingCount.add(1);
    }

    /**
     * @notice Release vested amount of tokens.
     * @param vestingScheduleId the vesting schedule identifier
     * @param amount the amount to release
     */
    function release(bytes32 vestingScheduleId, uint256 amount)
        public
        nonReentrant
        whenNotPaused
        onlyIfVestingSchedule(vestingScheduleId)
    {
        VestingSchedule storage v = vestingSchedules[vestingScheduleId];
        bool isBeneficiary = msg.sender == v.beneficiary;
        require(
            isBeneficiary,
            "JamonVesting: only beneficiary and owner can release vested tokens"
        );
        uint256 vestedAmount = _computeReleasableAmount(v);
        require(
            vestedAmount >= amount,
            "JamonVesting: cannot release tokens, not enough vested tokens"
        );
        v.released = v.released.add(amount);
        address payable beneficiaryPayable = payable(v.beneficiary);
        vestingSchedulesTotalAmount = vestingSchedulesTotalAmount.sub(amount);
        if (v.released >= v.amountTotal) {
            delete vestingSchedules[vestingScheduleId];
        }
        jamonV2.mint(beneficiaryPayable, amount);
        emit Released(beneficiaryPayable, amount);
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
    function computeReleasableAmount(bytes32 vestingScheduleId)
        public
        view
        onlyIfVestingSchedule(vestingScheduleId)
        returns (uint256)
    {
        VestingSchedule storage vestingSchedule = vestingSchedules[
            vestingScheduleId
        ];
        return _computeReleasableAmount(vestingSchedule);
    }

    /**
     * @notice Returns the vesting schedule information for a given identifier.
     * @return the vesting schedule structure information
     */
    function getVestingSchedule(bytes32 vestingScheduleId)
        public
        view
        returns (VestingSchedule memory)
    {
        return vestingSchedules[vestingScheduleId];
    }

    /**
     * @dev Computes the next vesting schedule identifier for a given holder address.
     */
    function computeNextVestingScheduleIdForHolder(address holder)
        public
        view
        returns (bytes32)
    {
        return
            computeVestingScheduleIdForAddressAndIndex(
                holder,
                holdersVestingCount[holder]
            );
    }

    /**
     * @dev Returns the last vesting schedule for a given holder address.
     */
    function getLastVestingScheduleForHolder(address holder)
        public
        view
        returns (VestingSchedule memory)
    {
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

    function depositToVault() external nonReentrant whenNotPaused {
        require(lastDeposit.add(month) < block.timestamp, "Is soon");
        require(deposits.current() < 12, "All deposits done");
        lastDeposit = block.timestamp;
        deposits.increment();
        uint256 totalStaked = JamonShareVault.totalStaked();
        uint256 toVault = totalStaked.mul(50);
        jamonV2.mint(address(JamonShareVault), toVault);
    }

    /**
     * @notice Functions for pause and unpause the contract.
     */
    function pause() external onlyOwner {
        _pause();
    }

    function unpause() external onlyOwner {
        _unpause();
    }
}
