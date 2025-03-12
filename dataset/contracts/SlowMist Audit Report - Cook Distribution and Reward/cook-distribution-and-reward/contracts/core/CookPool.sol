pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../external/UniswapV2Library.sol";
import "./Constants.sol";
import "./PoolSetters.sol";
import "./IPool.sol";
import "../oracle/IWETH.sol";

contract CookPool is PoolSetters, IPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor(
        address cook,
        uint256 cook_reward_per_block,
        uint256 totalPoolCapLimit,
        uint256 stakeLimitPerAddress
    ) public {
        require(cook != address(0), "Cook address can not be empty");
        require(
            cook_reward_per_block != 0,
            "cook_reward_per_block can not be zero"
        );

        _state.provider.cook = IERC20(cook); //COOK
        _state.pauseMinig = false;
        // 2e18 is 2 cook token perblock
        _state.REWARD_PER_BLOCK = cook_reward_per_block;
        _state.totalPoolCapLimit = totalPoolCapLimit;
        _state.stakeLimitPerAddress = stakeLimitPerAddress;

        // Make the deployer defaul admin role and manager role
        _setupRole(MANAGER_ROLE, msg.sender);
        _setupRole(ADMIN_ROLE, msg.sender);
        _setRoleAdmin(MANAGER_ROLE, ADMIN_ROLE);
    }

    event Stake(address indexed account, uint256 cookAmount);
    event Unstake(address indexed account, uint256 cookAmount);
    event Claim(address indexed account, uint256 cookAmount);
    event Harvest(address indexed account, uint256 cookAmount);
    event ZapCook(address indexed account, uint256 cookAmount);
    event UpdateTotalReward(uint256 newTotalAmount);

    function stake(uint256 cookAmount) external override {
        checkMiningPaused();
        ensureAddrNotBlacklisted(msg.sender);

        checkPoolStakeCapLimit(cookAmount);
        checkPerAddrStakeLimit(cookAmount, msg.sender);

        updateStakeStates(cookAmount, msg.sender);
        cook().safeTransferFrom(msg.sender, address(this), cookAmount);
        cookBalanceCheck();

        emit Stake(msg.sender, cookAmount);
    }

    function updateStakeStates(uint256 cookAmount, address userAddress)
        internal
    {
        require(cookAmount > 0, "zero stake cook amount");

        calculateNewRewardSinceLastRewardBlock();

        uint256 totalRewardedWithPhantom = totalRewarded().add(totalPhantom());
        uint256 newPhantom =
            totalStaked() == 0
                ? totalRewarded() == 0
                    ? Constants.getInitialStakeMultiple().mul(cookAmount)
                    : 0
                : totalRewardedWithPhantom.mul(cookAmount).div(totalStaked());

        incrementBalanceOfStaked(userAddress, cookAmount);
        incrementBalanceOfPhantom(userAddress, newPhantom);
    }

    function zapStake(uint256 cookAmount, address userAddress)
        external
        override
    {
        checkMiningPaused();
        ensureAddrNotBlacklisted(userAddress);

        checkPoolStakeCapLimit(cookAmount);
        checkPerAddrStakeLimit(cookAmount, userAddress);

        updateStakeStates(cookAmount, userAddress);
        cook().safeTransferFrom(msg.sender, address(this), cookAmount);
        cookBalanceCheck();

        emit ZapCook(userAddress, cookAmount);
    }

    function calculateNewRewardSinceLastRewardBlock() public virtual {
        uint256 lastRewardBlock = lastRewardBlock();
        uint256 blockNumber = blockNumber();
        if (blockNumber > lastRewardBlock) {
            if (totalStaked() != 0) {
                uint256 currentBlock = blockNumber;
                uint256 numOfBlocks = currentBlock.sub(lastRewardBlock);
                uint256 rewardAmount = numOfBlocks.mul(getRewardPerBlock());
                incrementTotalRewarded(rewardAmount);
            }
            updateLastRewardBlock(blockNumber);
        }
        cookBalanceCheck();

        emit UpdateTotalReward(totalRewarded());
    }

    function unstake(uint256 cookAmount) external override {
        require(cookAmount > 0, "zero unstake cook amount");

        uint256 stakedBalance = balanceOfStaked(msg.sender);
        uint256 unstakableBalance = balanceOfUnstakable(msg.sender);
        require(
            unstakableBalance >= cookAmount,
            "insufficient unstakable balance"
        );

        calculateNewRewardSinceLastRewardBlock();

        uint256 newClaimable =
            balanceOfRewarded(msg.sender).mul(cookAmount).div(stakedBalance);
        uint256 lessPhantom =
            balanceOfPhantom(msg.sender).mul(cookAmount).div(stakedBalance);

        addToVestingSchdule(msg.sender, newClaimable);
        decrementTotalRewarded(newClaimable, "insufficient rewarded balance");
        decrementBalanceOfStaked(
            msg.sender,
            cookAmount,
            "insufficient staked balance"
        );
        decrementBalanceOfPhantom(
            msg.sender,
            lessPhantom,
            "insufficient phantom balance"
        );

        cook().transfer(msg.sender, cookAmount);
        cookBalanceCheck();

        emit Unstake(msg.sender, cookAmount);
    }

    function harvest(uint256 cookAmount) public override {
        ensureAddrNotBlacklisted(msg.sender);

        require(cookAmount > 0, "zero harvest amount");

        require(totalRewarded() > 0, "insufficient total rewarded");

        require(
            balanceOfRewarded(msg.sender) >= cookAmount,
            "insufficient rewarded balance"
        );

        addToVestingSchdule(msg.sender, cookAmount);
        decrementTotalRewarded(cookAmount, "insufficient rewarded balance");
        incrementBalanceOfPhantom(msg.sender, cookAmount);

        cookBalanceCheck();

        emit Harvest(msg.sender, cookAmount);
    }

    function claim(uint256 cookAmount) public override {
        ensureAddrNotBlacklisted(msg.sender);

        require(cookAmount > 0, "zero claim cook amount");

        require(
            balanceOfClaimable(msg.sender) >= cookAmount,
            "insufficient claimable cook balance"
        );

        cook().safeTransfer(msg.sender, cookAmount);
        incrementBalanceOfClaimed(msg.sender, cookAmount);

        emit Claim(msg.sender, cookAmount);
    }

    function _calWethAmountToPairCook(uint256 cookAmount)
        internal
        returns (uint256, address)
    {
        IUniswapV2Pair lpPair = IUniswapV2Pair(address(univ2()));

        uint256 reserve0;
        uint256 reserve1;
        address weth;
        if (lpPair.token0() == address(cook())) {
            (reserve0, reserve1, ) = lpPair.getReserves();
            weth = lpPair.token1();
        } else {
            (reserve1, reserve0, ) = lpPair.getReserves();
            weth = lpPair.token0();
        }

        uint256 wethAmount =
            (reserve0 == 0 && reserve1 == 0)
                ? cookAmount
                : UniswapV2Library.quote(cookAmount, reserve0, reserve1);

        return (wethAmount, weth);
    }

    function zapCook(uint256 cookAmount) external {
        require(cookAmount > 0, "zero zap amount");

        require(
            balanceOfClaimable(msg.sender) >= cookAmount,
            "insufficient claimable balance"
        );

        checkMiningPaused();
        ensureAddrNotBlacklisted(msg.sender);

        checkPoolStakeCapLimit(cookAmount);
        checkPerAddrStakeLimit(cookAmount, msg.sender);

        incrementBalanceOfClaimed(msg.sender, cookAmount);
        updateStakeStates(cookAmount, msg.sender);
        cookBalanceCheck();

        emit ZapCook(msg.sender, cookAmount);
    }

    function cookBalanceCheck() private view {
        require(
            cook().balanceOf(address(this)) >=
                totalVesting().add(totalRewarded()).sub(totalClaimed()),
            "Inconsistent COOK balances"
        );
    }

    // admin emergency to transfer token to owner
    function emergencyWithdraw(uint256 amount) public onlyOwner {
        cook().safeTransfer(msg.sender, amount);
    }

    // set cook token reward per block
    function setRewardPerBlock(uint256 rewardPerBlock) public {
        require(hasRole(MANAGER_ROLE, msg.sender), "only manager");
        calculateNewRewardSinceLastRewardBlock();
        _state.REWARD_PER_BLOCK = rewardPerBlock;
    }
}
