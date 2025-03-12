// SPDX-License-Identifier: MIT

pragma solidity 0.6.12;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract NessToken is ERC20Burnable, Ownable {
    using SafeMath for uint256;

    // TOTAL MAX SUPPLY = 800,000,000 NESS
    uint256 public constant LIQUIDITY_MINING_PROGRAM_ALLOCATION = 500000000 ether;
    uint256 public constant SEEDING_FUND_POOL_ALLOCATION = 10000000 ether;

    uint256 public constant MARKETING_FUND_POOL_ALLOCATION = 200000000 ether;
    uint256 public constant ADVISOR_FUND_POOL_ALLOCATION = 90000000 ether;

    uint256 public constant MARKETING_VESTING_DURATION = 1440 days; // 48 months
    uint256 public constant ADVISOR_VESTING_DURATION = 720 days; // 24 months

    uint256 public startTime;
    uint256 public marketingVestingEndTime;
    uint256 public advisorVestingEndTime;

    uint256 public marketingFundRewardRate;
    uint256 public advisorFundRewardRate;

    address public marketingFund;
    address public advisorFund;

    uint256 public marketingLastClaimedTime;
    uint256 public advisorLastClaimedTime;

    bool public liquidityMiningDistributed = false;

    event MarketingFundUpdated(address _marketingFund);
    event AdvisorFundUpdated(address _advisorFund);

    constructor(uint256 _startTime, address _marketingFund, address _advisorFund) public ERC20("Darkness Share", "NESS") {
        _mint(msg.sender, SEEDING_FUND_POOL_ALLOCATION);

        startTime = _startTime;
        marketingVestingEndTime = _startTime.add(MARKETING_VESTING_DURATION);
        advisorVestingEndTime = _startTime.add(ADVISOR_VESTING_DURATION);

        marketingLastClaimedTime = _startTime;
        advisorLastClaimedTime = _startTime;

        marketingFundRewardRate = MARKETING_FUND_POOL_ALLOCATION.div(MARKETING_VESTING_DURATION);
        advisorFundRewardRate = ADVISOR_FUND_POOL_ALLOCATION.div(ADVISOR_VESTING_DURATION);

        require(_marketingFund != address(0), "Address cannot be 0");
        marketingFund = _marketingFund;

        require(_advisorFund != address(0), "Address cannot be 0");
        advisorFund = _advisorFund;
    }

    function setMarketingFund(address _marketingFund) external onlyOwner {
        require(_marketingFund != address(0), "zero");
        marketingFund = _marketingFund;
        emit MarketingFundUpdated(_marketingFund);
    }

    function setAdvisorFund(address _advisorFund) external onlyOwner {
        require(_advisorFund != address(0), "zero");
        advisorFund = _advisorFund;
        emit AdvisorFundUpdated(_advisorFund);
    }

    function unclaimedMarketingFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > marketingVestingEndTime) _now = marketingVestingEndTime;
        if (marketingLastClaimedTime >= _now) return 0;
        _pending = _now.sub(marketingLastClaimedTime).mul(marketingFundRewardRate);
    }

    function unclaimedAdvisorFund() public view returns (uint256 _pending) {
        uint256 _now = block.timestamp;
        if (_now > advisorVestingEndTime) _now = advisorVestingEndTime;
        if (advisorLastClaimedTime >= _now) return 0;
        _pending = _now.sub(advisorLastClaimedTime).mul(advisorFundRewardRate);
    }

    /**
     * @dev Claim pending rewards to advisor and marketing fund
     */
    function claimRewards() external {
        uint256 _pending = unclaimedMarketingFund();
        if (_pending > 0 && marketingFund != address(0)) {
            _mint(marketingFund, _pending);
            marketingLastClaimedTime = block.timestamp;
        }
        _pending = unclaimedAdvisorFund();
        if (_pending > 0 && advisorFund != address(0)) {
            _mint(advisorFund, _pending);
            advisorLastClaimedTime = block.timestamp;
        }
    }

    /**
     * @notice distribute to reward pool (only once)
     */
    function distributeReward(address _farmingIncentiveFund) external onlyOwner {
        require(!liquidityMiningDistributed, "only can distribute once");
        require(_farmingIncentiveFund != address(0), "!_farmingIncentiveFund");
        liquidityMiningDistributed = true;
        _mint(_farmingIncentiveFund, LIQUIDITY_MINING_PROGRAM_ALLOCATION);
    }

    function burn(uint256 amount) public override {
        super.burn(amount);
    }

    function rescueStuckErc20(address _token) external onlyOwner {
        IERC20(_token).transfer(owner(), IERC20(_token).balanceOf(address(this)));
    }
}
