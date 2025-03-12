// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import { Initializable } from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import { OwnableUpgradeable } from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";
import { IERC20 } from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import { SafeERC20 } from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import { IERC20Metadata } from "@openzeppelin/contracts/token/ERC20/extensions/IERC20Metadata.sol";

import "../interfaces/IRadiantStaking.sol";
import "../interfaces/IEsRDNTHelper.sol";
import "../interfaces/IRDNTVestManager.sol";
import "../interfaces/radiant/IChefIncentivesController.sol";
import "../interfaces/IMintableERC20.sol";
import "../libraries/ERC20FactoryLib.sol";

/// @title A contract for managing entitled RDNT and vestable RDNT for users
/// Entitled RDNT are the RDNT amount that Radiant Staking claim from Radiant Capital, waiting to vest
/// Vestable RDNT are the RDNT amount that Radiant Staking has started claiming

/// The flow of RDNT vesting flow.
/// 1. RDNTVestManager.nextVestedTime is the RDNT vested time for all Radpie user they start vesting their Entitled RDNT at anytime.  (timestamp: T1 - x, 0 days < x < 10 days)
/// 2. RDNTRewardManager.startVestingAll call to make RadianStaking request vesting all current claimable RDNT on Radiant.            (timestamp: T1)
/// 3. RDNTRewardManager.collectVestedRDNTAll to make RadianStaking claim all vesterd RDNT and trasnfer to RDNTVestManager            (timestamp: T1 + 90)
/// 4. User can claim their vested RDNT from RDNTVestManager                                                                          (after timestamp: T1 + 90 )
/// vesting day of RDNT for Radpie user will be:   90 < RDNT vest time < 90 + x, (0 days < x < 10 days)

/// @author Radpie Team

contract RDNTRewardManager is Initializable, OwnableUpgradeable {
    using SafeERC20 for IERC20Metadata;
    using SafeERC20 for IERC20;

    /* ============ State Variables ============ */

    struct RDNTRewardStats {
        uint256 queuedRewards;
        uint256 entitledPerTokenStored;
    }

    struct UserInfo {
        uint256 userEntitledPerTokenPaid;
        uint256 userEntitled;
    }

    IRadiantStaking public radiantStaking;
    address public rewardDistributor;
    IRDNTVestManager public rdntVestManager;
    IChefIncentivesController public chefIncentivesController;
    address[] public registeredReceipts; // all registerd receipt
    address[] public whitelistedOperators;

    mapping(address => RDNTRewardStats) public rdntRewardStats; // _radpieReceipt to RDNTRewardStats
    mapping(address => mapping(address => UserInfo)) public userInfos; // amount by [_receipt][account],
    mapping(address => bool) public rewardQueuers;
    mapping(address => bool) public isTokenRegistered;

    uint256 public RDNTVestingDays; // The vesting days on RADIAN Capital
    uint256 public RDNTVestingCoolDown; // The time gap before next RadiantStaking request vesting RDNT
    uint256 public nextVestingTime; // The expect time of next RadiantStaking request vesting RDNT, should be currrent timeblock + RDNTVestingCoolDown

    uint256 public constant OFFSET = 10 ** 12;

    address public esRDNT;
    address public RDNT;
    IEsRDNTHelper public EsRDNTHelper;

    /* ============ Events ============ */

    event RDNTEntitled(address indexed _receipt, uint256 _amount);
    event RDNTVestable(uint256 _amount);
    event VestingRDNTSchedule(address indexed _user, uint256 _vestAmount, uint256 _unblockTime);
    event EntitledRDNTUpdated(
        address indexed _account,
        address indexed _receipt,
        uint256 _entitledRDNT,
        uint256 _entitledPerTokenStored
    );
    event RewardQueuerUpdated(address indexed _manager, bool _allowed);
    event RdntVestingDaysUpdated(uint256 updatedRDNTVestingDays, uint256 updatedRDNTCoolDownDays);
    event VestingEsRDNTSchedule(address indexed _user, uint256 _vestAmount, uint256 _unblockTime);
    event esRDNTEarned(address indexed user, uint256 totalEntitled);
    event RDNTEarned(address indexed user, uint256 totalEntitled);
    event swappedRdntToEsRdntStartedVestingEsRDNT(
        uint256 RDNTAmountIn,
        uint256 EsRDNTAmountOut,
        uint256 vestedTime
    );

    /* ============ Errors ============ */

    error OnlyRewardQueuer();
    error NotAllowZeroAddress();
    error OnlyWhiteListedOperator();
    error AlreadyRegistered();
    error InsufficientBalance();
    error esRDNTNotSet();
    error AlreadyCreated();
    error ZeroAmount();
    error RDNTNotSet();
    error EsRDNTHelperNotSet();
    error EsRDNTHelperARBChainNotSet();
    error InvalidVestedRDNTAmount();

    /* ============ Constructor ============ */
    constructor() {
        _disableInitializers();
    }

    function __RDNTRewardManager_init(
        address _radiantStaking,
        address _chefIncentivesController
    ) public initializer {
        __Ownable_init();
        if (_radiantStaking == address(0)) revert NotAllowZeroAddress();
        radiantStaking = IRadiantStaking(_radiantStaking);
        if (_chefIncentivesController == address(0)) revert NotAllowZeroAddress();
        chefIncentivesController = IChefIncentivesController(_chefIncentivesController);
        rewardQueuers[_radiantStaking] = true;
        RDNTVestingDays = 90 days;
        RDNTVestingCoolDown = 10 days;
        nextVestingTime = block.timestamp + RDNTVestingCoolDown;
    }

    /* ============ Modifiers ============ */

    modifier onlyRewardQueuer() {
        if (!rewardQueuers[msg.sender]) revert OnlyRewardQueuer();
        _;
    }

    modifier updateEntitledRDNTs(address _account) {
        uint256 length = registeredReceipts.length;

        for (uint256 i = 0; i < length; i++) {
            address registeredReceipt = registeredReceipts[i];
            _updateForByReceipt(_account, registeredReceipt);
        }
        _;
    }

    modifier _onlyWhitelisted() {
        bool isCallerWhiteListed = false;
        for (uint i; i < whitelistedOperators.length; i++) {
            if (whitelistedOperators[i] == msg.sender) {
                isCallerWhiteListed = true;
                break;
            }
        }
        if (isCallerWhiteListed == true || owner() == msg.sender) {
            _;
        } else {
            revert OnlyWhiteListedOperator();
        }
    }

    /* ============ External Getters ============ */

    /// @dev How Entitled RDNT should be distributed.
    /// RDNT emit for the same underlying asset of rToken and vdToken goes to the same pool on Radpie.
    function entitledRdntGauge()
        external
        view
        returns (uint256 totalWeight, address[] memory assets, uint256[] memory weights)
    {
        uint256 length = radiantStaking.poolLength();
        assets = new address[](length);
        weights = new uint256[](length);

        for (uint256 i = 0; i < length; i++) {
            address asset = radiantStaking.poolTokenList(i);
            assets[i] = asset;

            uint256 weight = calculatePoolWeight(asset);

            // Assign weight directly to the array without a separate variable
            weights[i] = weight;

            totalWeight += weight;
        }
    }

    /// @dev Returns current amount of staked tokens
    function totalStaked(address _receiptToken) public view virtual returns (uint256) {
        return IERC20(_receiptToken).totalSupply();
    }

    /// @dev Returns amount of staked tokens in master Radpie by account
    /// @param _receiptToken The address of the receipt
    /// @param _account The address of the account
    function balanceOf(
        address _account,
        address _receiptToken
    ) public view virtual returns (uint256) {
        return IERC20(_receiptToken).balanceOf(_account);
    }

    /// @dev Returns the entitled RDNT per token for a specific receipt
    /// @param _receipt The address of the receipt
    function entitledPerToken(address _receipt) public view returns (uint256) {
        return rdntRewardStats[_receipt].entitledPerTokenStored;
    }

    /// @dev Returns the total entitled RDNT for a specific account
    /// @param _account The address of the account
    /// @return The total entitled RDNT for the account
    function entitledRDNT(address _account) public view returns (uint256) {
        uint256 length = registeredReceipts.length;
        uint256 userTotalEntitled;

        for (uint256 i = 0; i < length; i++) {
            userTotalEntitled += this.entitledRDNTByReceipt(_account, registeredReceipts[i]);
        }

        return userTotalEntitled;
    }

    /// @dev Returns the entitled RDNT for a specific account and receipt
    /// @param _account The address of the account
    /// @param _receipt The address of the receipt
    /// @return The entitled RDNT for the account and receipt and Balance of ReceiptToken
    function entitledRDNTByReceipt(
        address _account,
        address _receipt
    ) public view returns (uint256) {
        return _entitled(_account, _receipt, balanceOf(_account, _receipt));
    }

    function nextVestedTime() external view returns (uint256) {
        return nextVestingTime + RDNTVestingDays;
    }

    /* ============ External Functions ============ */

    /// @dev Updates the entitled RDNTs for a specific account and receipt
    /// @param _account The address of the account
    /// @param _receipt The address of the receipt
    function updateFor(address _account, address _receipt) external {
        _updateForByReceipt(_account, _receipt);
    }

    /// @dev Start vesting the RDNT tokens for the calling account
    function vestRDNT() external updateEntitledRDNTs(msg.sender) {
        uint256 totalEntitled = processEntitlement(msg.sender);

        if (totalEntitled > 0) {
            uint256 vestedTime = this.nextVestedTime();
            IRDNTVestManager(rdntVestManager).scheduleVesting(
                msg.sender,
                totalEntitled,
                vestedTime
            );
            emit VestingRDNTSchedule(msg.sender, totalEntitled, vestedTime);
        }
    }

    /// @notice Vest a specified amount of esRDNT tokens for the calling account.
    /// @param _amount The amount of esRDNT tokens to vest.
    function vestEsRDNT(uint256 _amount) external {
        if (esRDNT == address(0)) revert esRDNTNotSet();
        uint256 esRDNTBal = IMintableERC20(esRDNT).balanceOf(msg.sender);

        if (_amount > esRDNTBal) revert InsufficientBalance();

        if (_amount > 0) {
            IMintableERC20(esRDNT).burn(msg.sender, _amount);
            uint256 vestedTime = this.nextVestedTime();
            IRDNTVestManager(rdntVestManager).scheduleVesting(msg.sender, _amount, vestedTime);
            emit VestingEsRDNTSchedule(msg.sender, _amount, vestedTime);
        }
    }

    function swapRDNTToEsRDNTStartVestingEsRDNT(
        uint256 RDNTAmountIn,
        uint160 sqrtPriceLimit,
        uint256 amountOutMin
    ) external returns (uint256 EsRDNTAmountOut) {
        if (RDNTAmountIn == 0) revert ZeroAmount();
        if (RDNT == address(0)) revert RDNTNotSet();
        if (address(EsRDNTHelper) == address(0)) revert EsRDNTHelperNotSet();

        IERC20(RDNT).safeTransferFrom(msg.sender, address(this), RDNTAmountIn);
        IERC20(RDNT).safeApprove(address(EsRDNTHelper), RDNTAmountIn);

        (EsRDNTAmountOut) = EsRDNTHelper.swapRDNTToEsRDNT(
            RDNTAmountIn,
            sqrtPriceLimit,
            amountOutMin
        );

        IMintableERC20(esRDNT).burn(address(this), EsRDNTAmountOut);
        uint256 vestedTime = this.nextVestedTime();
        IRDNTVestManager(rdntVestManager).scheduleVesting(msg.sender, EsRDNTAmountOut, vestedTime);

        emit swappedRdntToEsRdntStartedVestingEsRDNT(RDNTAmountIn, EsRDNTAmountOut, vestedTime);
    }

    function withdrawEsRDNTToRDNT(uint256 amountRdntOutMin, uint160 sqrtPriceLimit) external {
        if (esRDNT == address(0)) revert esRDNTNotSet();
        if (address(EsRDNTHelper) == address(0)) revert EsRDNTHelperNotSet();

        uint256 totalEntitled = processEntitlement(msg.sender);

        if (totalEntitled > 0) {
            IMintableERC20(esRDNT).mint(address(this), totalEntitled);
            IERC20(esRDNT).safeApprove(address(EsRDNTHelper), totalEntitled);

            uint256 amountRDNTOut = EsRDNTHelper.swapEsRDNTToRDNTFor(
                totalEntitled,
                amountRdntOutMin,
                sqrtPriceLimit,
                msg.sender
            );

            emit RDNTEarned(msg.sender, amountRDNTOut);
        }
    }

    //  @notice Redeem entitled RDNT tokens to esRDNT Tokens for the calling account.
    function redeemEntitledRDNT() external updateEntitledRDNTs(msg.sender) {
        if (esRDNT == address(0)) revert esRDNTNotSet();

        uint256 totalEntitled = processEntitlement(msg.sender);

        if (totalEntitled > 0) {
            IMintableERC20(esRDNT).mint(msg.sender, totalEntitled);
            emit esRDNTEarned(msg.sender, totalEntitled);
        }
    }

    /* ============ Admin Functions ============ */

    /// @dev Updates the reward queuer status for a manager
    /// @param _rewardManager The address of the reward manager
    /// @param _allowed The status to be set (true or false)
    function updateRewardQueuer(address _rewardManager, bool _allowed) external onlyOwner {
        rewardQueuers[_rewardManager] = _allowed;
        emit RewardQueuerUpdated(_rewardManager, rewardQueuers[_rewardManager]);
    }

    /// @dev Queues the entitled RDNT tokens for a specific receipt
    /// @param _rdntAmount The amount of RDNT tokens to be queued
    /// @param _radpieReceipt The address of the radpie receipt token
    function queueEntitledRDNT(
        address _radpieReceipt,
        uint256 _rdntAmount
    ) external onlyRewardQueuer {
        if (!isTokenRegistered[_radpieReceipt]) {
            isTokenRegistered[_radpieReceipt] = true;
            registeredReceipts.push(_radpieReceipt);
        }

        RDNTRewardStats storage rdntRewardStat = rdntRewardStats[_radpieReceipt];

        emit RDNTEntitled(_radpieReceipt, _rdntAmount);

        uint256 totalStake = totalStaked(_radpieReceipt);
        if (totalStake == 0) {
            rdntRewardStat.queuedRewards += _rdntAmount;
        } else {
            if (rdntRewardStat.queuedRewards > 0) {
                _rdntAmount += rdntRewardStat.queuedRewards;
                rdntRewardStat.queuedRewards = 0;
            }
            rdntRewardStat.entitledPerTokenStored =
                rdntRewardStat.entitledPerTokenStored +
                (_rdntAmount * 10 ** IERC20Metadata(_radpieReceipt).decimals()) /
                totalStake;
        }
    }

    /// @dev Radpie to start vesting currnet all claimmable RDNT on Radiant. This function is expected to be called every other 5 - 10 days
    function startVestingAll(bool _force) external _onlyWhitelisted {
        IRadiantStaking(radiantStaking).vestAllClaimableRDNT(_force);
        nextVestingTime = block.timestamp + RDNTVestingCoolDown; // nextVestingTime has to be updated as block.timestamp + RDNTVestingDays
    }

    /// @dev Radpie to claim all vested RDNT and transfer RDNT to RDNTVest Manager so user can claim
    function collectVestedRDNTAll() external {
        uint256 vestedRDNT = radiantStaking.getSystemVestedRDNT();
        if (vestedRDNT == 0) revert InvalidVestedRDNTAmount();
        radiantStaking.claimVestedRDNT();
    }

    function setRDNTVestManager(address _rdntVestManager) external onlyOwner {
        if (_rdntVestManager == address(0)) revert NotAllowZeroAddress();
        rdntVestManager = IRDNTVestManager(_rdntVestManager);
    }

    function setRewardDistributor(address _rewardDistributor) external onlyOwner {
        if (_rewardDistributor == address(0)) revert NotAllowZeroAddress();
        rewardDistributor = _rewardDistributor;
    }

    function setEsRDNTHelper(address _esRDNTHelper) external onlyOwner {
        if (_esRDNTHelper == address(0)) revert NotAllowZeroAddress();
        EsRDNTHelper = IEsRDNTHelper(_esRDNTHelper);
    }

    function setRDNT(address _rdnt) external onlyOwner {
        if (_rdnt == address(0)) revert NotAllowZeroAddress();
        RDNT = _rdnt;
    }

    function addRegisteredReceipt(address _receiptToken) external onlyRewardQueuer {
        if (isTokenRegistered[_receiptToken]) revert AlreadyRegistered();

        isTokenRegistered[_receiptToken] = true;
        registeredReceipts.push(_receiptToken);
    }

    function addWhitelistedOperator(address _operator) external onlyOwner {
        if (_operator == address(0)) {
            revert NotAllowZeroAddress();
        }
        whitelistedOperators.push(_operator);
    }

    function removeWhitelistedOperator(uint _index) external onlyOwner {
        if (_index >= whitelistedOperators.length) {
            revert NotAllowZeroAddress();
        }
        whitelistedOperators[_index] = whitelistedOperators[whitelistedOperators.length - 1];
        whitelistedOperators.pop();
    }

    function updateVestingTimePeriodData(
        uint256 _radiantVestingCoolDownDays,
        uint256 _radinatVestingDays
    ) external onlyOwner {
        RDNTVestingDays = _radinatVestingDays * 1 days;
        RDNTVestingCoolDown = _radiantVestingCoolDownDays * 1 days;
        emit RdntVestingDaysUpdated(RDNTVestingDays, RDNTVestingCoolDown);
    }

    // Admin function to create the esRDNT token
    function createEsRDNT(string memory name, string memory symbol) external onlyOwner {
        if (esRDNT != address(0)) revert AlreadyCreated();
        esRDNT = ERC20FactoryLib.createERC20(name, symbol);
    }

    /* ============ Internal Functions ============ */

    /// @dev Calculate the weight for a given pool
    function calculatePoolWeight(address asset) internal view returns (uint256) {
        (, address rToken, address vdToken, , , , , , bool isActive) = radiantStaking.pools(asset);

        if (!isActive) return 0;

        uint256 rTokenBal = IERC20(rToken).balanceOf(address(radiantStaking));
        uint256 vdTokenBal = IERC20(vdToken).balanceOf(address(radiantStaking));

        (uint256 rTokenTotalSup, uint256 rAlloc, , , ) = chefIncentivesController.poolInfo(rToken);
        (uint256 vdTokenTotalSup, uint256 vdAlloc, , , ) = chefIncentivesController.poolInfo(
            vdToken
        );

        uint256 rTokenWeight = (OFFSET * rTokenBal * rAlloc) / rTokenTotalSup;
        uint256 vdTokenWeight = (OFFSET * vdTokenBal * vdAlloc) / vdTokenTotalSup;

        return rTokenWeight + vdTokenWeight;
    }

    /// @dev Calculates the entitled RDNT for a specific account and receipt
    function _entitled(
        address _account,
        address _receipt,
        uint256 _userShare
    ) internal view returns (uint256) {
        UserInfo storage userInfo = userInfos[_receipt][_account];
        if (_userShare == 0) return userInfo.userEntitled;

        return
            ((_userShare * (entitledPerToken(_receipt) - userInfo.userEntitledPerTokenPaid)) /
                10 ** IERC20Metadata(_receipt).decimals()) + userInfo.userEntitled;
    }

    /// @dev Updates the entitled RDNTs for a specific account and receipt
    function _updateForByReceipt(address _account, address _receipt) internal {
        UserInfo storage userInfo = userInfos[_receipt][_account];
        RDNTRewardStats storage rewardStat = rdntRewardStats[_receipt];

        if (userInfo.userEntitledPerTokenPaid == rewardStat.entitledPerTokenStored) return;

        userInfo.userEntitled = entitledRDNTByReceipt(_account, _receipt);
        userInfo.userEntitledPerTokenPaid = rewardStat.entitledPerTokenStored;

        emit EntitledRDNTUpdated(
            _account,
            _receipt,
            userInfo.userEntitled,
            userInfo.userEntitledPerTokenPaid
        );
    }

    /// @dev Common function to process entitlement
    function processEntitlement(address _account) internal returns (uint256) {
        uint256 length = registeredReceipts.length;
        uint256 totalEntitled = 0;

        for (uint256 i = 0; i < length; i++) {
            address receipt = registeredReceipts[i];
            if (userInfos[receipt][_account].userEntitled == 0) continue;

            totalEntitled += userInfos[receipt][_account].userEntitled; // updated during updateReward modifier
            userInfos[receipt][_account].userEntitled = 0;
        }

        return totalEntitled;
    }
}
