// SPDX-License-Identifier: MIT
pragma solidity 0.8.17;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "../utils/Ownable.sol";

/// PRESTAKING BOX
/// @notice Staking contract for investors. At deployment we send all the tokens for each investor to this contract with a plus amount of rewards
contract LitlabPreStakingBox is Ownable {
    using SafeERC20 for IERC20;

    enum InvestorType {
        ANGEL,
        SEED,
        STRATEGIC
    }

    struct UserStake {
        uint256 amount;
        uint256 withdrawn;
        uint256 rewardsWithdrawn;
        uint256 lastRewardsWithdrawn;
        uint256 lastUserWithdrawn;
        InvestorType investorType;
        bool claimedInitial;
        bool withdrawnFirst;
    }

    address immutable public token;
    uint256 immutable public stakeStartDate;
    uint256 immutable public stakeEndDate;
    uint256 public totalRewards;
    uint256 public totalStakedAmount;

    uint8 constant public INITIAL_WITHDRAW_PERCENTAGE = 15;

    mapping(address => UserStake) private balances;

    event InitialStaked();
    event InitialWithdrawn(address indexed _user, uint256 _amount);
    event RewardsWithdrawn(address indexed _user, uint256 _rewards);
    event Withdrawn(address indexed _user, uint256 _amount);
    event EmergencyWithdrawn();

    /// @notice Constructor
    /// @param _token Address of the litlab token
    /// @param _stakeStartDate Start date of staking
    /// @param _stakeEndDate End date of staking
    /// @param _totalRewards Rewards for the staking   
    constructor(address _token, uint256 _stakeStartDate, uint256 _stakeEndDate, uint256 _totalRewards) {
        require(_token != address(0), "ZeroAddress");

        token = _token;
        stakeStartDate = _stakeStartDate;
        stakeEndDate = _stakeEndDate;
        totalRewards = _totalRewards;
    }

    /// @notice Stake function. Call at the deployment by the owner only one time to fill the investors amounts
    /// @notice This function doesn't take the tokens from any wallets. Litlabgames will send all the investor's tokens and the rewards
    /// @notice to this SmartContract after deployed. So, we assume right tokens amount will be in the contract after stake function is called
    /// @param _users Array with all the address of the investors
    /// @param _amounts Array with the investment amounts
    /// @param _investorTypes Array with the investor types (to calculate the vesting period)
    function stake(
        address[] memory _users, 
        uint256[] memory _amounts, 
        uint8[] memory _investorTypes
    ) external onlyOwner {
        require(_users.length == _amounts.length, "BadLengths");
        require(_investorTypes.length == _amounts.length, "BadLengths");
        require(stakeStartDate >= block.timestamp, "Started");
        require(totalStakedAmount == 0, "Initialized");
        
        uint256 total = 0;
        for (uint256 i=0; i<_users.length; ) {
            InvestorType investorType = InvestorType(_investorTypes[i]);
            require(_users[i] != address(0), "ZeroAddress");
            require(_amounts[i] != 0, "BadAmount");

            balances[_users[i]] = UserStake({
                amount: _amounts[i],
                withdrawn: 0,
                rewardsWithdrawn: 0,
                lastRewardsWithdrawn: 0,
                lastUserWithdrawn: 0,
                investorType: investorType,
                claimedInitial: false,
                withdrawnFirst: false
            });

            total += _amounts[i];

            unchecked {
                ++i;
            }
        }

        totalStakedAmount = total;

        emit InitialStaked();
    }

    /// @notice At TGE users can withdraw the 15% of their investment. Only one time
    function withdrawInitial() external {
        require(block.timestamp >= stakeStartDate, "NotTGE");
        require(balances[msg.sender].amount != 0, "NoStaked");
        require(!balances[msg.sender].claimedInitial, "Claimed");

        uint256 amount = balances[msg.sender].amount * INITIAL_WITHDRAW_PERCENTAGE / 100;
        balances[msg.sender].withdrawn += amount;
        balances[msg.sender].claimedInitial = true;

        IERC20(token).safeTransfer(msg.sender, amount);

        emit InitialWithdrawn(msg.sender, amount);
    }

    /// @notice Users can withdraw rewards whenever they want with no penalty only if they don't withdraw previously
    function withdrawRewards() external {
        require(balances[msg.sender].amount != 0, "NoStaked");
        require(!balances[msg.sender].withdrawnFirst, "Withdrawn");
        require(block.timestamp >= stakeStartDate, "NotYet");

        uint256 pendingRewards = _getPendingRewards(msg.sender);
        require(pendingRewards > 0, "NoRewardsToClaim");

        balances[msg.sender].rewardsWithdrawn += pendingRewards;
        balances[msg.sender].lastRewardsWithdrawn = block.timestamp;
        IERC20(token).safeTransfer(msg.sender, pendingRewards);

        emit RewardsWithdrawn(msg.sender, pendingRewards);
    }

    /// @notice Users withdraws all the balance according their vesting, but they couldn't withdraw rewards any more with the withdrawRewards function
    function withdraw() external {
        require(balances[msg.sender].claimedInitial, "ClaimWithdrawInitialFirst");
        require(balances[msg.sender].amount > 0, "NoStaked");
        require(balances[msg.sender].withdrawn < balances[msg.sender].amount, "CantWithdrawMore");

        uint256 userAmount = balances[msg.sender].amount;
        uint256 tokensToSend = 0;
        if (!balances[msg.sender].withdrawnFirst) {
            uint256 pendingRewards = _getPendingRewards(msg.sender);
            uint256 tokens = _calculateVestingTokens(msg.sender);

            balances[msg.sender].lastUserWithdrawn = block.timestamp;
            balances[msg.sender].rewardsWithdrawn += pendingRewards;
            balances[msg.sender].withdrawn += tokens;
            balances[msg.sender].withdrawnFirst = true;

            // This is the last time this user can get rewards, and the rest of the rewards are split for the other users.
            totalStakedAmount -= userAmount;
            totalRewards -= balances[msg.sender].rewardsWithdrawn; 

            tokensToSend = tokens + pendingRewards;
        } else {
            tokensToSend = _calculateVestingTokens(msg.sender);
            balances[msg.sender].lastUserWithdrawn = block.timestamp;
            balances[msg.sender].withdrawn += tokensToSend;
        }

        IERC20(token).safeTransfer(msg.sender, tokensToSend);

        emit Withdrawn(msg.sender, tokensToSend);
    }

    /// @notice Get the data for each user (to show in the frontend dapp)
    function getData(address _user) external view returns (
        uint256 userAmount, 
        uint256 withdrawn, 
        uint256 rewardsTokensPerSec, 
        uint256 lastRewardsWithdrawn, 
        uint256 lastUserWithdrawn, 
        uint256 pendingRewards
    ) {
        return _getData(_user);
    }

    /// @notice Quick way to know how many tokens are pending in the contract
    function getTokensInContract() external view returns (uint256 tokens) {
        tokens = IERC20(token).balanceOf(address(this));
    }

    /// @notice If there's any problem, contract owner can withdraw all funds (this is not a public and open stake, it's only for authorized investors)
    function emergencyWithdraw() external onlyOwner {
        require(token != address(0), "ZeroAddress");
        uint256 balance = IERC20(token).balanceOf(address(this));
        IERC20(token).safeTransfer(msg.sender, balance);

        emit EmergencyWithdrawn();
    }

    /// @notice Calculate the token vesting according the investor type
    function _calculateVestingTokens(address _user) internal view returns (uint256) {
        InvestorType investorType = balances[_user].investorType;
        uint256 vestingDays;
        if (investorType == InvestorType.ANGEL) vestingDays = 36 * 30 days;
        else if (investorType == InvestorType.SEED) vestingDays = 30 * 30 days;
        else if (investorType == InvestorType.STRATEGIC) vestingDays = 24 * 30 days;

        uint256 amountMinusFirstWithdraw = balances[_user].amount - balances[_user].amount * INITIAL_WITHDRAW_PERCENTAGE / 100;
        uint256 tokensPerSec = amountMinusFirstWithdraw / vestingDays;

        uint256 tokens;
        if (block.timestamp < stakeStartDate + vestingDays) {
            uint256 from = balances[_user].lastUserWithdrawn == 0 
                            ? stakeStartDate 
                            : balances[_user].lastUserWithdrawn;
            uint256 to = block.timestamp;
            uint256 diffTime = to - from;
            tokens = diffTime * tokensPerSec;
        } else {
            tokens = balances[_user].amount - balances[_user].withdrawn;
        }

        return tokens;
    }

    /// Return contract data needed in the frontend
    function _getData(address _user) internal view returns (
        uint256 userAmount, 
        uint256 withdrawn, 
        uint256 rewardsTokensPerSec, 
        uint256 lastRewardsWithdraw, 
        uint256 lastUserWithdrawn, 
        uint256 pendingRewards
    ) {
        userAmount = balances[_user].amount;
        withdrawn = balances[_user].withdrawn;
        lastRewardsWithdraw = balances[_user].lastRewardsWithdrawn;
        lastUserWithdrawn = balances[_user].lastUserWithdrawn;

        uint256 from = lastRewardsWithdraw == 0 ? stakeStartDate : lastRewardsWithdraw;
        uint256 to = block.timestamp > stakeEndDate ? stakeEndDate : block.timestamp;

        if ((totalStakedAmount != 0) && (to >= from)) {
            rewardsTokensPerSec = (totalRewards * (balances[_user].amount)) 
                / ((stakeEndDate - stakeStartDate) * totalStakedAmount);
            pendingRewards = !balances[_user].withdrawnFirst ? (to - from) * rewardsTokensPerSec : 0;
        }
    }

    function _getPendingRewards(address _user) internal view returns (uint256 pendingRewards) {
        uint256 from = balances[_user].lastRewardsWithdrawn == 0 
                            ? stakeStartDate 
                            : balances[_user].lastRewardsWithdrawn;
        uint256 to = block.timestamp > stakeEndDate ? stakeEndDate : block.timestamp;

        if ((totalStakedAmount != 0) && (to >= from)) {
            uint256 rewardsTokensPerSec = (totalRewards * (balances[_user].amount)) 
                / ((stakeEndDate - stakeStartDate) * totalStakedAmount);
            pendingRewards = !balances[_user].withdrawnFirst ? (to - from) * rewardsTokensPerSec : 0;
        }
    }
}