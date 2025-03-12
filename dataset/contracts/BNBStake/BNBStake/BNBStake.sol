// SPDX-License-Identifier: MIT 
 
 /*  BNBStake - investment platform based on Binance Smart Chain. Safe and legit!
 *   The only official platform of original BNBStake team! All other platforms with the same contract code are FAKE!
 *
 * 
 *   ┌───────────────────────────────────────────────────────────────────────┐
 *   │   Website: https://bnbstake.us                                        │
 *   │                                                                       │
 *   │   Telegram Public Group: https://t.me/bnbstakingproject               |
 *   |                                                                       |
 *   └───────────────────────────────────────────────────────────────────────┘
 *
 *   [USAGE INSTRUCTION]
 *
 *   1) Connect browser extension Metamask
 *   2) Choose one of the tariff plans, enter the BNB amount (0.05 BNB minimum) using our website "Stake BNB" button
 *   3) Wait for your earnings
 *   4) Withdraw earnings any time using our website "Withdraw" button
 *
 *   [INVESTMENT CONDITIONS]
 *
 *   - Basic interest rate: +0.5% every 24 hours (~0.02% hourly) - only for new deposits
 *   - Minimal deposit: 0.05 BNB, no maximal limit
 *   - Total income: based on your tariff plan (from 5% to 8% daily!!!) + Basic interest rate !!!
 *   - Earnings every moment, withdraw any time (if you use capitalization of interest you can withdraw only after end of your deposit) 
 *
 *   [AFFILIATE PROGRAM]
 *
 *   - Direct sponsor 1 level @ 12%
 *
 *   [FUNDS DISTRIBUTION]
 *
 *   - 91% Platform main balance, participants payouts
 *   - 1% Luck pool for every day last 3 users
 *   - 5% developer charges
 *   - 3% marketing 
 */

pragma solidity >=0.4.22 <0.9.0;

contract BNBStake {
	using SafeMath for uint256;

	uint256 constant private INVEST_MIN_AMOUNT = 0.05 ether;
	uint256 constant private REFERRAL_PERCENTS = 120;
	uint256 constant private PROJECT_FEE = 80;
	uint256 constant private PERCENT_STEP = 5;
    uint256 constant private LUCK_PERCENTS = 10;
	uint256 constant private PERCENTS_DIVIDER = 1000;
	uint256 constant private TIME_STEP = 1 days;
	uint256 constant private DAY_LUCK_AMOUNT = 3;

	uint256 public totalStaked;
    uint256 public luckPool;
	uint256 public totalUsers;
	uint256 public lastDistribute;

    struct Plan {
        uint256 time;
        uint256 percent;
    }

    Plan[] private plans;

	struct Deposit {
        uint8 plan;
		uint256 percent;
		uint256 amount;
		uint256 profit;
		uint256 start;
		uint256 finish;
	}

	struct User {
		Deposit[] deposits;
		uint256 checkpoint;
		address referrer;
		uint256 invited;
		uint256 bonus;
		uint256 totalBonus;
		uint256 luck;
		uint256 totalLuck;
	}

	mapping(uint256=>address[]) public dayLuckUsers;
    mapping(uint256=>uint256[]) public dayLuckUsersDeposit;

	mapping (address => User) public users;

	uint256 public startTime;
	address payable public commissionWallet;
	address public defaultReferrer;

	event Newbie(address user);
	event NewDeposit(address indexed user, uint8 plan, uint256 percent, uint256 amount, uint256 profit, uint256 start, uint256 finish);
	event Withdrawn(address indexed user, uint256 amount);
	event RefBonus(address indexed referrer, address indexed referral, uint256 amount);
	event FeePayed(address indexed user, uint256 totalAmount);
	event AddExtraBonus(address indexed user);
	event RemoveExtraBonus(address indexed user);
	event ExtraBonus(address indexed referrer, address indexed referral, uint256 indexed level, uint256 amount);

	constructor(address payable _wallet, address _defaultReferrer, uint256 _startTime) {
		commissionWallet = _wallet;
		defaultReferrer = _defaultReferrer;
		startTime = _startTime;
		lastDistribute = _startTime;

        plans.push(Plan(14, 80));
        plans.push(Plan(21, 65));
        plans.push(Plan(28, 50));
        plans.push(Plan(14, 80));
        plans.push(Plan(21, 65));
        plans.push(Plan(28, 50));
	}

	function invest(address referrer, uint8 plan) public payable {
		require(block.timestamp > startTime, "not luanched yet");
		require(msg.value >= INVEST_MIN_AMOUNT, "the min amount is 0.05 BNB");
        require(plan < 6, "Invalid plan");

		uint256 fee = msg.value.mul(PROJECT_FEE).div(PERCENTS_DIVIDER);
		commissionWallet.transfer(fee);
		emit FeePayed(msg.sender, fee);

		User storage user = users[msg.sender];

		if (user.referrer == address(0)) {
			if (users[referrer].deposits.length > 0  && referrer != msg.sender) {
				user.referrer = referrer;
			}else{
				user.referrer = defaultReferrer;
			}

			address upline = user.referrer;
			users[upline].invited = users[upline].invited.add(1);
		}

		if (user.referrer != address(0)) {
			address upline = user.referrer;
			uint256 amount = msg.value.mul(REFERRAL_PERCENTS).div(PERCENTS_DIVIDER);
			users[upline].bonus = users[upline].bonus.add(amount);
			users[upline].totalBonus = users[upline].totalBonus.add(amount);
			emit RefBonus(upline, msg.sender, amount);
		}

		// dis luck
		uint256 dayNow = getCurDay();
		_distributeLuckPool(dayNow);

		// luckpool
		uint256 luck = msg.value.mul(LUCK_PERCENTS).div(PERCENTS_DIVIDER);
        luckPool = luckPool.add(luck);

		if (user.deposits.length == 0) {
			user.checkpoint = block.timestamp;
			totalUsers = totalUsers.add(1);

			dayLuckUsers[dayNow].push(msg.sender);
            dayLuckUsersDeposit[dayNow].push(msg.value);
			emit Newbie(msg.sender);
		}

		(uint256 percent, uint256 profit, uint256 finish) = getResult(plan, msg.value);
		user.deposits.push(Deposit(plan, percent, msg.value, profit, block.timestamp, finish));

		totalStaked = totalStaked.add(msg.value);
		emit NewDeposit(msg.sender, plan, percent, msg.value, profit, block.timestamp, finish);
	}

	function withdraw() public {
		require(block.timestamp > startTime, "not luanched yet");

		// dis luck
		uint256 dayNow = getCurDay();
		_distributeLuckPool(dayNow);

		User storage user = users[msg.sender];

		uint256 totalAmount = getUserDividends(msg.sender);

		uint256 referralBonus = user.bonus;
		if (referralBonus > 0) {
			user.bonus = 0;
			totalAmount = totalAmount.add(referralBonus);
		}

		uint256 luckBonus = user.luck;
		if(luckBonus > 0){
			user.luck = 0;
			totalAmount = totalAmount.add(luckBonus);
		}

		require(totalAmount > 0, "User has no dividends");

		uint256 contractBalance = address(this).balance;
		if (contractBalance < totalAmount) {
			totalAmount = contractBalance;
		}

		user.checkpoint = block.timestamp;

	    payable(msg.sender).transfer(totalAmount);
		emit Withdrawn(msg.sender, totalAmount);
	}

	function getCurDay() public view returns(uint256 dayNow) {
		if(block.timestamp >= startTime){
        	dayNow = (block.timestamp.sub(startTime)).div(TIME_STEP);
		}
    }

	function _distributeLuckPool(uint256 _dayNow) private {
		if(block.timestamp > lastDistribute.add(TIME_STEP)){
			uint256 dayDepositCount = dayLuckUsers[_dayNow - 1].length;
			if(dayDepositCount > 0){
				uint256 checkCount = DAY_LUCK_AMOUNT;
				if(dayDepositCount < DAY_LUCK_AMOUNT){
					checkCount = dayDepositCount;
				}
				uint256 totalDeposit;
				uint256 totalReward;
				for(uint256 i = dayDepositCount; i > dayDepositCount.sub(checkCount); i--){
					totalDeposit = totalDeposit.add(dayLuckUsersDeposit[_dayNow - 1][i - 1]);
				}

				for(uint256 i = dayDepositCount; i > dayDepositCount.sub(checkCount); i--){
					address userAddr = dayLuckUsers[_dayNow - 1][i - 1];
					if(userAddr != address(0)){
						uint256 reward = luckPool.mul(dayLuckUsersDeposit[_dayNow - 1][i - 1]).div(totalDeposit);
						totalReward = totalReward.add(reward);
						users[userAddr].luck = users[userAddr].luck.add(reward);
						users[userAddr].totalLuck = users[userAddr].totalLuck.add(reward);
					}
				}
				if(luckPool > totalReward){
					luckPool = luckPool.sub(totalReward);
				}else{
					luckPool = 0;
				}
			}
			lastDistribute = block.timestamp;
		}
    }

	function getPlanInfo(uint8 plan) public view returns(uint256 time, uint256 percent) {
		time = plans[plan].time;
		percent = plans[plan].percent;
	}

	function getPercent(uint8 plan) public view returns (uint256) {
		if (block.timestamp > startTime) {
			return plans[plan].percent.add(PERCENT_STEP.mul(block.timestamp.sub(startTime)).div(TIME_STEP));
		} else {
			return plans[plan].percent;
		}
    }

	function getResult(uint8 plan, uint256 deposit) public view returns (uint256 percent, uint256 profit, uint256 finish) {
		percent = getPercent(plan);

		if (plan < 3) {
			profit = deposit.mul(percent).div(PERCENTS_DIVIDER).mul(plans[plan].time);
		} else if (plan < 6) {
			for (uint256 i = 0; i < plans[plan].time; i++) {
				profit = profit.add((deposit.add(profit)).mul(percent).div(PERCENTS_DIVIDER));
			}
		}
		finish = block.timestamp.add(plans[plan].time.mul(TIME_STEP));
	}

	function getUserDividends(address userAddress) public view returns (uint256) {
		User storage user = users[userAddress];

		uint256 totalAmount;

		for (uint256 i = 0; i < user.deposits.length; i++) {
			if (user.checkpoint < user.deposits[i].finish) {
				if (user.deposits[i].plan < 3) {
					uint256 share = user.deposits[i].amount.mul(user.deposits[i].percent).div(PERCENTS_DIVIDER);
					uint256 from = user.deposits[i].start > user.checkpoint ? user.deposits[i].start : user.checkpoint;
					uint256 to = user.deposits[i].finish < block.timestamp ? user.deposits[i].finish : block.timestamp;
					if (from < to) {
						totalAmount = totalAmount.add(share.mul(to.sub(from)).div(TIME_STEP));
					}
				} else if (block.timestamp > user.deposits[i].finish) {
					totalAmount = totalAmount.add(user.deposits[i].profit);
				}
			}
		}

		return totalAmount;
	}

	function getLuckLength() external view returns(uint256) {
		uint256 dayNow = getCurDay();
        return dayLuckUsers[dayNow].length;
    }

	function getLuckInfo() public view returns(address[] memory luckUsers, uint256[] memory luckAmounts) {
		uint256 dayNow = getCurDay();
		uint256 dayDepositCount = dayLuckUsers[dayNow].length;
		if(dayDepositCount > 0){
			uint256 checkCount = DAY_LUCK_AMOUNT;
			if(dayDepositCount < DAY_LUCK_AMOUNT){
				checkCount = dayDepositCount;
			}
			
			luckUsers = new address[](checkCount);
			luckAmounts = new uint256[](checkCount);
			uint256 j = 0;
			for(uint256 i = dayDepositCount; i > dayDepositCount.sub(checkCount); i--){
				luckUsers[j] = dayLuckUsers[dayNow][i - 1];
				luckAmounts[j] = dayLuckUsersDeposit[dayNow][i - 1];
				j += 1;
			}
		}
	}

	function getUserAmountOfDeposits(address userAddress) public view returns(uint256) {
		return users[userAddress].deposits.length;
	}

	function getUserTotalDeposits(address userAddress) public view returns(uint256 amount) {
		for (uint256 i = 0; i < users[userAddress].deposits.length; i++) {
			amount = amount.add(users[userAddress].deposits[i].amount);
		}
	}

	function getUserDepositInfo(address userAddress, uint256 index) public view returns(uint8 plan, uint256 percent, uint256 amount, uint256 profit, uint256 start, uint256 finish) {
	    User storage user = users[userAddress];
		plan = user.deposits[index].plan;
		percent = user.deposits[index].percent;
		amount = user.deposits[index].amount;
		profit = user.deposits[index].profit;
		start = user.deposits[index].start;
		finish = user.deposits[index].finish;
	}
}

library SafeMath {

    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");

        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b <= a, "SafeMath: subtraction overflow");
        uint256 c = a - b;

        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }

        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");

        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        require(b > 0, "SafeMath: division by zero");
        uint256 c = a / b;

        return c;
    }
}