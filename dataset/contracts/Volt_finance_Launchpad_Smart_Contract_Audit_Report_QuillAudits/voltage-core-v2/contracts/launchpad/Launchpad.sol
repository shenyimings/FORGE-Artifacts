// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/utils/math/Math.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/security/ReentrancyGuard.sol";
import "../interfaces/IVeVOLT.sol";
import "../interfaces/ILaunchpadFactory.sol";

contract Launchpad is Ownable, ReentrancyGuard {
    using SafeERC20 for IERC20;

    uint256 constant SECONDS_PER_DAY = 86400;

    struct UserInfo {
        uint256 balance;
        uint256 totalClaimed;
        uint256 daysClaimed;
    }

    /// @dev The address of the launch pad factory contract
    address public immutable launchpadFactory;

    /// @dev The token being offered in the launch event.
    address public immutable projectToken;

    /// @dev The amount of project tokens available for the launch event
    uint256 public immutable projectTokenReserve;

    /// @dev The token used to contribute to the launch event.
    address public immutable saleToken;

    /// @dev The maximum amount of sale tokens a staked user can contibute to the launch event in sale token decimals.
    uint256 public immutable stakedUserMaxBuyAmount;

    /// @dev The maximum amount of sale tokens an unstaked user can contribute to the launch event in sale token decimals.
    uint256 public immutable unstakedUserMaxBuyAmount;

    /// @dev The start time of the auction.
    uint256 public immutable startTime;

    /// @dev The end time of the auction.
    uint256 public immutable endTime;

    /// @dev The snapshot time used to fetch historical user balances.
    uint256 public immutable snapshotTime;

    /// @dev The number of days for vesting.
    uint256 public immutable vestingDays;

    /// @dev The vevolt to project token ratio.
    uint256 public immutable veVoltPerProjectToken;

    /// @dev The minimum amount he projects wants to raise in sale token decimals.
    uint256 public immutable minSaleTokenReserve;

    /// @dev The maximum amount the project wants to raise in sale token decimals.
    uint256 public immutable maxSaleTokenReserve;

    /// @dev The address of the project treasury.
    address public projectTreasury;

    /// @dev The amount currently raised.
    uint256 public saleTokenReserve;

    /// @dev User participation information
    mapping(address => UserInfo) public usersInfo;

    event Bought(address indexed user, uint256 amount);

    event Claimed(address indexed user, uint256 amount);

    event Withdrew(address indexed user, uint256 amount);

    constructor(LaunchpadParams memory _params) {
        require(
            _params.projectToken != address(0),
            "constructor: projectToken invalid address"
        );
        require(
            _params.saleToken != address(0),
            "constructor: saleToken invalid address"
        );
        require(
            _params.projectTreasury != address(0),
            "constructor: projectTreasury invalid address"
        );
        require(
            _params.projectTokenReserve > 0,
            "constructor: _projectTokenReserve > 0"
        );
        require(
            _params.minSaleTokenReserve > 0,
            "constructor: minSaleTokenReserve > 0"
        );
        require(
            _params.maxSaleTokenReserve > 0 &&
                _params.minSaleTokenReserve < _params.maxSaleTokenReserve,
            "constructor: maxSaleTokenReserve > 0"
        );
        require(
            _params.veVoltPerProjectToken > 0,
            "constructor: veVoltPerProjectToken > 0"
        );
        require(
            _params.stakedUserMaxBuyAmount > 0,
            "constructor: stakedUserMaxBuyAmount > 0"
        );
        require(
            _params.unstakedUserMaxBuyAmount > 0,
            "constructor: unstakedUserMaxBuyAmount > 0"
        );
        require(
            _params.endTime > _params.startTime,
            "constructor: endTime should be after startTime"
        );
        require(
            _params.vestingDays < 90,
            "constructor: vesting maximum 90 days"
        );

        launchpadFactory = msg.sender;
        projectTreasury = _params.projectTreasury;

        projectToken = _params.projectToken;
        projectTokenReserve = _params.projectTokenReserve;

        saleToken = _params.saleToken;
        minSaleTokenReserve = _params.minSaleTokenReserve;
        maxSaleTokenReserve = _params.maxSaleTokenReserve;

        veVoltPerProjectToken = _params.veVoltPerProjectToken;

        stakedUserMaxBuyAmount = _params.stakedUserMaxBuyAmount;
        unstakedUserMaxBuyAmount = _params.unstakedUserMaxBuyAmount;

        startTime = _params.startTime;
        endTime = _params.endTime;
        snapshotTime = _params.snapshotTime;

        vestingDays = _params.vestingDays;
    }

    modifier saleActive() {
        require(
            hasStarted() && !hasEnded(),
            "saleActive: launch event is not active"
        );
        _;
    }

    modifier saleEnded() {
        require(hasEnded(), "saleEnded: launch event hasn't ended");
        _;
    }

    /**
     * @dev Returns a boolean indicating whether the launchpad has started
     */
    function hasStarted() public view returns (bool) {
        return block.timestamp >= startTime;
    }

    /**
     * @dev Returns a boolean indicating whether the launchpad has ended
     */
    function hasEnded() public view returns (bool) {
        return block.timestamp > endTime;
    }

    /**
     * @dev Returns the number of project tokens to distribute based on the total amount raised
     */
    function tokensToDistribute() public view returns (uint256) {
        if (minSaleTokenReserve > saleTokenReserve) {
            return
                (projectTokenReserve * saleTokenReserve) / minSaleTokenReserve;
        }
        return projectTokenReserve;
    }

    /**
     * @dev Returns the amount of project tokens allocated to the user
     * @param _user The address of the user
     */
    function getUserAllocation(address _user) public view returns (uint256) {
        UserInfo memory userInfo = usersInfo[_user];
        return tokensToDistribute() * userInfo.balance / saleTokenReserve;
    }

    /**
     * @dev Returns the number of days vested and the claim amount for the user
     * @param _user The address of the user
     */
    function calculateUserClaim(
        address _user
    ) public view returns (uint256, uint256) {
        if (block.timestamp < endTime) {
            return (0, 0);
        }

        uint256 elapsedTime = block.timestamp - endTime;
        uint256 elapsedDays = elapsedTime / SECONDS_PER_DAY;

        UserInfo memory userInfo = usersInfo[_user];
        uint256 allocation = getUserAllocation(_user);

        if (elapsedDays >= vestingDays) {
            uint256 remainingClaim = allocation - userInfo.totalClaimed;
            return (vestingDays, remainingClaim);
        } else {
            uint256 daysVested = elapsedDays - userInfo.daysClaimed;
            uint256 amountVestedPerDay = allocation / vestingDays;
            return (daysVested, daysVested * amountVestedPerDay);
        }
    }

    /**
     * @dev Returns the maximum buy amount for the user
     * @param _user The address of the user
     */
    function getUserBuyAmount(address _user) public view returns (uint256) {
        uint256 veVoltBalance = IVeVolt(
            ILaunchpadFactory(launchpadFactory).veVolt()
        ).balanceOf(_user, snapshotTime);

        uint256 stakedUserAllocation = (((veVoltBalance * 1e18 / veVoltPerProjectToken) * 10**ERC20(saleToken).decimals()) / 1e18);

        uint256 finalStakedUserAllocation = Math.min(
            unstakedUserMaxBuyAmount + stakedUserAllocation,
            stakedUserMaxBuyAmount
        );

        return
            veVoltBalance > 0 ? finalStakedUserAllocation : unstakedUserMaxBuyAmount;
    }

    /**
     * @dev Transfers sale tokens to the project treasury and the fee to the owner
     */
    function withdrawSaleTokens() public saleEnded {
        uint256 fee = (saleTokenReserve *
            ILaunchpadFactory(launchpadFactory).launchpadFee()) /
            ILaunchpadFactory(launchpadFactory).SCALE();
        uint256 amountWithoutFee = saleTokenReserve - fee;

        IERC20(saleToken).safeTransfer(
            ILaunchpadFactory(launchpadFactory).owner(),
            fee
        );
        IERC20(saleToken).safeTransfer(projectTreasury, amountWithoutFee);
    }

    /**
     * @dev Transfers unsold project tokens to the project treasury
     */
    function withdrawUnsoldProjectTokens() public saleEnded {
        uint256 soldTokens = tokensToDistribute();
        uint256 remainingTokens = projectTokenReserve - soldTokens;
        IERC20(projectToken).safeTransfer(projectTreasury, remainingTokens);
    }

    /**
     * @dev Buy an allocation for the launchpad
     * @param _amount The amount of sale tokens
     */
    function buy(uint256 _amount) public saleActive nonReentrant {
        require(_amount > 0, "buy: amount > 0");
        require(
            saleTokenReserve + _amount <= maxSaleTokenReserve,
            "buy: hardcap reached"
        );

        UserInfo storage user = usersInfo[msg.sender];

        uint256 maxBuyAmount = getUserBuyAmount(msg.sender);
        require(
            user.balance + _amount <= maxBuyAmount,
            "buy: user hardcap reached"
        );

        user.balance += _amount;
        saleTokenReserve += _amount;

        IERC20(saleToken).safeTransferFrom(msg.sender, address(this), _amount);

        emit Bought(msg.sender, _amount);
    }

    /**
     * @dev Withdraw sale tokens from the launchpad
     */
    function withdraw(uint256 _amount) public saleActive nonReentrant {
        UserInfo storage user = usersInfo[msg.sender];

        require(
            user.balance >= _amount,
            "withdraw: amount greater than balance"
        );

        user.balance -= _amount;
        saleTokenReserve -= _amount;

        uint256 fee = (_amount *
            ILaunchpadFactory(launchpadFactory).withdrawFee()) /
            ILaunchpadFactory(launchpadFactory).SCALE();
        uint256 amountWithFee = _amount - fee;

        IERC20(saleToken).safeTransfer(msg.sender, amountWithFee);
        IERC20(saleToken).safeTransfer(
            ILaunchpadFactory(launchpadFactory).owner(),
            fee
        );

        emit Withdrew(msg.sender, _amount);
    }

    /**
     * @dev Claim project tokens from the launchpad.
     */
    function claim() public saleEnded nonReentrant {
        UserInfo storage userInfo = usersInfo[msg.sender];

        (uint256 daysVested, uint256 amountVested) = calculateUserClaim(
            msg.sender
        );
        require(amountVested > 0, "claim: amount vested > 0");

        userInfo.daysClaimed += daysVested;
        userInfo.totalClaimed += amountVested;

        IERC20(projectToken).safeTransfer(msg.sender, amountVested);

        emit Claimed(msg.sender, amountVested);
    }
}
