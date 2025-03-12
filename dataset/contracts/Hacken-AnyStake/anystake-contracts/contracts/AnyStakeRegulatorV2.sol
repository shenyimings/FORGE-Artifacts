// SPDX-License-Identifier: MIT

pragma solidity 0.6.6;

import "./lib/@defiat-crypto/interfaces/IDeFiatPoints.sol";
import "./interfaces/IAnyStakeMigrator.sol";
import "./interfaces/IAnyStakeRegulator.sol";
import "./interfaces/IAnyStakeVault.sol";
import "./utils/AnyStakeUtils.sol";

contract AnyStakeRegulatorV2 is IAnyStakeMigrator, IAnyStakeRegulator, AnyStakeUtils {
    using SafeMath for uint256;

    event Initialized(address indexed user, address vault);
    event Claim(address indexed user, uint256 amount);
    event Deposit(address indexed user, uint256 amount);
    event Withdraw(address indexed user, uint256 amount);
    event Migrate(address indexed user, uint256 amount);
    event EmergencyWithdraw(address indexed user, uint256 amount);
    event StakingFeeUpdated(address indexed user, uint256 stakingFee);
    event BuybackRateUpdated(address indexed user, uint256 buybackRate);
    event PriceMultiplierUpdated(address indexed user, uint256 amount);
    event MigratorUpdated(address indexed user, address migrator);
    event VaultUpdated(address indexed user, address vault);
    event RegulatorActive(address indexed user, bool active);

    struct UserInfo {
        uint256 amount;
        uint256 rewardDebt;
        uint256 lastRewardBlock;
    }

    mapping (address => UserInfo) public userInfo;
    
    address public regulator; // address of the Regulator V1
    address public migrator; // address of the contract we may migrate to
    address public vault; // address of the vault

    bool public active; // staking is active
    bool public initialized; // contract has been initialized
    uint256 public stakingFee; // fee taken on withdrawals
    uint256 public priceMultiplier; // price peg control, DFT_PRICE = (DFTP_PRICE * priceMultiplier) / 1000
    uint256 public lastRewardBlock; // last block that rewards were received
    uint256 public pointsBuybackBalance; // total pending DFTPv2 awaiting stabilization
    uint256 public buybackBalance; // total pending DFT awaiting stabilization
    uint256 public buybackRate; // rate of rewards stockpiled for stabilization
    uint256 public rewardsPerShare; // DFT rewards per DFTP, times 1e18 to prevent underflow
    uint256 public pendingRewards; // total pending DFT rewards
    uint256 public totalShares; // total staked shares

    modifier NoReentrant(address user) {
        require(
            block.number > userInfo[user].lastRewardBlock,
            "Regulator: Must wait 1 block"
        );
        _;
    }

    modifier onlyRegulator {
        require(msg.sender == regulator, "Regulator: Only previous Regulator allowed");
        _;
    }

    modifier onlyVault() {
        require(msg.sender == vault, "AnyStake: Only Vault allowed");
        _;
    }

    modifier activated() {
        require(initialized, "Regulator: Not initialized yet");
        _;
    }

    constructor(address _regulator, address _router, address _gov, address _points, address _token) 
        public 
        AnyStakeUtils(_router, _gov, _points, _token)
    {
        regulator = _regulator;
        priceMultiplier = 10000; // 10000 / 1000 = 10:1
        stakingFee = 100; // 10%
        buybackRate = 300; // 30%
    }

    function initialize(address _vault) external onlyGovernor {
        require(_vault != address(0), "Initialize: Must pass in Vault");
        require(!initialized, "Initialize: Regulator already initialized");

        vault = _vault;
        active = true;
        initialized = true;
        emit Initialized(msg.sender, vault);
    }

    function stabilize(uint256 amount) internal {
        if (amount == 0) {
            return;
        }

        if (isAbovePeg()) {
            // Above Peg: sell DFTP, buy DFT, add to rewards

            // add incoming DFTPv2 to pointsBuyback
            uint256 totalPointsBuybackBalance = pointsBuybackBalance.add(amount);
            // transfer DFTPv2 to Vault to buyback
            IERC20(DeFiatPoints).transfer(vault, totalPointsBuybackBalance);
            // buyback DFT with DFTPv2 on Vault, rewards automatically added on next update
            IAnyStakeVault(vault).buyDeFiatWithTokens(DeFiatPoints, amount);
            // reset points buyback
            pointsBuybackBalance = 0;
        } else {
            // Below Peg: accrue DFTPv2 fee, sell DFT, buy DFTP on Vault, burn Vault proceeds (deflationary)

            // accrue DFTPv2
            pointsBuybackBalance = pointsBuybackBalance.add(amount);
            // buyback DFTPv2 with DFT on Vault
            IAnyStakeVault(vault).buyPointsWithTokens(DeFiatToken, buybackBalance);
            // burn all DFTPv2 proceeds on Vault
            IDeFiatPoints(DeFiatPoints).overrideLoyaltyPoints(vault, 0);
            // reset token buyback
            buybackBalance = 0;
        }
    }

    // Pool - Add rewards
    function addReward(uint256 amount) external override onlyVault {
        if (amount == 0) {
            return;
        }

        uint256 buybackAmount = amount.mul(buybackRate).div(1000);
        uint256 rewardAmount = amount.sub(buybackAmount);

        if (buybackAmount > 0) {
            buybackBalance = buybackBalance.add(buybackAmount);
        }

        if (rewardAmount > 0) {
            rewardsPerShare = rewardsPerShare.add(rewardAmount.mul(1e18).div(totalShares));
        }
    }

    // Pool - Update pool rewards, pull from Vault
    function updatePool() external override {
        _updatePool();
    }

    // Pool - Update pool internal
    function _updatePool() internal {
        if (totalShares == 0 || block.number <= lastRewardBlock || !active) {
            return;
        }

        // calculate rewards, calls addReward()
        IAnyStakeVault(vault).calculateRewards();

        // update reward block            
        lastRewardBlock = block.number;
    }

    function claim() external override activated NoReentrant(msg.sender) {
        UserInfo storage user = userInfo[msg.sender];

        _updatePool();
        _claim(msg.sender);

        // update pool / user metrics
        user.rewardDebt = user.amount.mul(rewardsPerShare).div(1e18);
        user.lastRewardBlock = block.number;
    }

    // Pool - Claim internal
    function _claim(address _user) internal {
        // get pending rewards
        uint256 rewards = pending(_user);
        // transfer DFT rewards from Vault
        if (rewards == 0) {
            return;
        }
        
        IAnyStakeVault(vault).distributeRewards(_user, rewards);
        emit Claim(_user, rewards);
    }

    // Pool - Deposit DeFiat Points (DFTP) to earn DFT and stablize token prices
    function deposit(uint256 amount) external override activated NoReentrant(msg.sender) {
        _deposit(msg.sender, amount);
    }

    // Pool - deposit internal, perform the stablization
    function _deposit(address _user, uint256 _amount) internal {
        UserInfo storage user = userInfo[_user];
        require(_amount > 0, "Deposit: Cannot deposit zero tokens");

        _updatePool();
        _claim(_user);

        // update pool / user metrics
        totalShares = totalShares.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(rewardsPerShare).div(1e18);
        user.lastRewardBlock = block.number;

        IERC20(DeFiatPoints).transferFrom(_user, address(this), _amount);
        emit Deposit(_user, _amount);
    }

    // Pool - Withdraw function, currently unused
    function withdraw(uint256 amount) external override NoReentrant(msg.sender) {
        _withdraw(msg.sender, amount); // internal, unused
    }

    // Pool - Withdraw internal, unused
    function _withdraw(address _user, uint256 _amount) internal {
        UserInfo storage user = userInfo[_user];
        require(_amount <= user.amount, "Withdraw: Not enough staked");

        _updatePool();
        _claim(_user);

        uint256 feeAmount = _amount.mul(stakingFee).div(1000);
        uint256 remainingUserAmount = _amount.sub(feeAmount);

        stabilize(feeAmount);

        totalShares = totalShares.sub(_amount);
        user.amount = user.amount.sub(_amount);
        user.rewardDebt = user.amount.mul(rewardsPerShare).div(1e18);
        user.lastRewardBlock = block.number;

        IERC20(DeFiatPoints).transfer(_user, remainingUserAmount);
        emit Withdraw(_user, remainingUserAmount);
    }

    function migrate() external override NoReentrant(msg.sender) {
        _migrate(msg.sender);
    }

    function _migrate(address _user) internal {
        UserInfo storage user = userInfo[_user];
        uint256 balance = user.amount;

        require(migrator != address(0), "Migrate: No migrator set");
        require(balance > 0, "Migrate: No tokens to migrate");
        require(!active, "Migrate: Pool is still active");

        _claim(_user);

        totalShares = totalShares.sub(balance);
        user.amount = 0;
        user.rewardDebt = 0;
        user.lastRewardBlock = block.number;

        IERC20(DeFiatPoints).approve(migrator, balance);
        IAnyStakeMigrator(migrator).migrateTo(_user, DeFiatPoints, balance);
        emit Migrate(_user, balance);
    }

    function migrateTo(address _user, address _token, uint256 _amount) 
        external
        override
        onlyRegulator
    {
        UserInfo storage user = userInfo[_user];

        _claim(_user);

        IERC20(_token).transferFrom(regulator, address(this), _amount);

        totalShares = totalShares.add(_amount);
        user.amount = user.amount.add(_amount);
        user.rewardDebt = user.amount.mul(rewardsPerShare).div(1e18);
        user.lastRewardBlock = block.number;
    }

    // Emergency withdraw all basis, add staking fee to points buyback balance
    function emergencyWithdraw() external NoReentrant(msg.sender) {
        UserInfo storage user = userInfo[msg.sender];
        require(user.amount > 0, "EmergencyWithdraw: user amount insufficient");

        // find the fee amount and remaining user amount
        uint256 feeAmount = user.amount.mul(stakingFee).div(1000);
        uint256 remainingUserAmount = user.amount.sub(feeAmount);

        // update pool / user metrics
        totalShares = totalShares.sub(user.amount);
        user.amount = 0;
        user.rewardDebt = 0;
        user.lastRewardBlock = block.number;

        // add to points buyback and send user their share
        pointsBuybackBalance = pointsBuybackBalance.add(feeAmount);
        safeTokenTransfer(msg.sender, DeFiatPoints, remainingUserAmount);
        emit EmergencyWithdraw(msg.sender, remainingUserAmount);
    }

    function isAbovePeg() public view returns (bool) {
        uint256 tokenPrice = IAnyStakeVault(vault).getTokenPrice(DeFiatToken, DeFiatTokenLp);
        uint256 pointsPrice = IAnyStakeVault(vault).getTokenPrice(DeFiatPoints, DeFiatPointsLp);
        
        return pointsPrice.mul(priceMultiplier).div(1000) > tokenPrice;
    }

    // View - Pending DFT Rewards for user in pool
    function pending(address _user)
        public
        view
        returns (uint256)
    {
        UserInfo storage user = userInfo[_user];
        return user.amount.mul(rewardsPerShare).div(1e18).sub(user.rewardDebt);
    }


    // Governance - Set Staking Fee
    function setStakingFee(uint256 _stakingFee) external onlyGovernor {
        require(_stakingFee != stakingFee, "SetFee: No fee change");
        require(_stakingFee <= 1000, "SetFee: Fee cannot exceed 100%");

        stakingFee = _stakingFee;
        emit StakingFeeUpdated(msg.sender, stakingFee);
    }

    // Governance - Set Buyback Rate
    function setBuybackRate(uint256 _buybackRate) external onlyGovernor {
        require(_buybackRate != buybackRate, "SetBuybackRate: No rate change");
        require(_buybackRate <= 1000, "SetBuybackRate: Cannot exceed 100%");

        buybackRate = _buybackRate;
        emit BuybackRateUpdated(msg.sender, buybackRate);
    }

    // Governance - Set DeFiat Points price multiplier
    function setPriceMultiplier(uint256 _priceMultiplier) external onlyGovernor {
        require(_priceMultiplier != priceMultiplier, "SetMultiplier: No multiplier change");
        require(_priceMultiplier > 0, "SetMultiplier: Must be greater than zero");

        priceMultiplier = _priceMultiplier;
        emit PriceMultiplierUpdated(msg.sender, priceMultiplier);
    }

    // Governance - Set Migrator
    function setMigrator(address _migrator) external onlyGovernor {
        require(_migrator != address(0), "SetMigrator: No migrator change");

        migrator = _migrator;
        emit MigratorUpdated(msg.sender, _migrator);
    }
    
    // Governance - Set Vault
    function setVault(address _vault) external onlyGovernor {
        require(_vault != address(0), "SetVault: No migrator change");

        vault = _vault;
        emit VaultUpdated(msg.sender, vault);
    }

    // Governance - Set Pool Deposits active
    function setActive(bool _active) external onlyGovernor {
        require(_active != active, "SetActive: No active change");
        
        active = _active;
        emit RegulatorActive(msg.sender, active);
    }
}