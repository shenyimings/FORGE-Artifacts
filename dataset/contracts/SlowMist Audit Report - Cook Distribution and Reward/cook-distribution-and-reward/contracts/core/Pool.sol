pragma solidity ^0.6.2;

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";
import "@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol";
import "../external/UniswapV2Library.sol";
import "./Constants.sol";
import "./PoolSetters.sol";
import "./IPool.sol";
import "../oracle/IWETH.sol";

contract Pool is PoolSetters, IPool {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    constructor(
        address cook,
        address univ2,
        uint256 cook_reward_per_block,
        uint256 totalPoolCapLimit,
        uint256 stakeLimitPerAddress
    ) public {
        require(cook != address(0), "Cook address can not be empty");
        require(univ2 != address(0), "univ2 address can not be empty");
        require(
            cook_reward_per_block != 0,
            "cook_reward_per_block can not be zero"
        );

        _state.provider.cook = IERC20(cook); //COOK
        _state.provider.univ2 = IERC20(univ2); //univ2 pair COOK/WETH
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

    event Stake(address indexed account, uint256 univ2Amount);
    event Unstake(address indexed account, uint256 univ2Amount);
    event Claim(address indexed account, uint256 cookAmount);
    event Harvest(address indexed account, uint256 cookAmount);
    event ZapLP(address indexed account, uint256 newUniv2);
    event UpdateTotalReward(uint256 newTotalAmount);

    fallback() external payable {
        revert();
    }

    function stake(uint256 univ2Amount) external override {
        checkMiningPaused();
        ensureAddrNotBlacklisted(msg.sender);

        checkPoolStakeCapLimit(univ2Amount);
        checkPerAddrStakeLimit(univ2Amount, msg.sender);

        updateStakeStates(univ2Amount, msg.sender);
        univ2().safeTransferFrom(msg.sender, address(this), univ2Amount);
        uniBalanceCheck();

        emit Stake(msg.sender, univ2Amount);
    }

    function updateStakeStates(uint256 univ2Amount, address userAddress)
        internal
    {
        require(univ2Amount > 0, "zero stake amount");

        calculateNewRewardSinceLastRewardBlock();

        uint256 totalRewardedWithPhantom = totalRewarded().add(totalPhantom());
        uint256 newPhantom =
            totalStaked() == 0
                ? totalRewarded() == 0
                    ? Constants.getInitialStakeMultiple().mul(univ2Amount)
                    : 0
                : totalRewardedWithPhantom.mul(univ2Amount).div(totalStaked());

        incrementBalanceOfStaked(userAddress, univ2Amount);
        incrementBalanceOfPhantom(userAddress, newPhantom);
    }

    function zapStake(uint256 univ2Amount, address userAddress)
        external
        override
    {
        checkMiningPaused();
        ensureAddrNotBlacklisted(userAddress);

        checkPoolStakeCapLimit(univ2Amount);
        checkPerAddrStakeLimit(univ2Amount, userAddress);

        updateStakeStates(univ2Amount, userAddress);
        univ2().safeTransferFrom(msg.sender, address(this), univ2Amount);
        uniBalanceCheck();

        emit ZapLP(userAddress, univ2Amount);
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

    function unstake(uint256 univ2Amount) external override {
        require(univ2Amount > 0, "zero unstake amount");

        uint256 stakedBalance = balanceOfStaked(msg.sender);
        uint256 unstakableBalance = balanceOfUnstakable(msg.sender);
        require(
            unstakableBalance >= univ2Amount,
            "insufficient unstakable balance"
        );

        calculateNewRewardSinceLastRewardBlock();

        uint256 newClaimable =
            balanceOfRewarded(msg.sender).mul(univ2Amount).div(stakedBalance);
        uint256 lessPhantom =
            balanceOfPhantom(msg.sender).mul(univ2Amount).div(stakedBalance);

        addToVestingSchdule(msg.sender, newClaimable);
        decrementTotalRewarded(newClaimable, "insufficient rewarded balance");
        decrementBalanceOfStaked(
            msg.sender,
            univ2Amount,
            "insufficient staked balance"
        );
        decrementBalanceOfPhantom(
            msg.sender,
            lessPhantom,
            "insufficient phantom balance"
        );

        univ2().safeTransfer(msg.sender, univ2Amount);
        uniBalanceCheck();

        emit Unstake(msg.sender, univ2Amount);
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

        require(cookAmount > 0, "zero claim amount");

        require(
            balanceOfClaimable(msg.sender) >= cookAmount,
            "insufficient claimable balance"
        );

        cook().safeTransfer(msg.sender, cookAmount);
        incrementBalanceOfClaimed(msg.sender, cookAmount);

        emit Claim(msg.sender, cookAmount);
    }

    function harvestAndClaim(uint256 cookAmount) public {
        harvest(cookAmount);
        claim(cookAmount);
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

    function addLiquidity(uint256 cookAmount)
        internal
        returns (uint256, uint256)
    {
        (uint256 wethAmount, address wethAddress) =
            _calWethAmountToPairCook(cookAmount);
        IUniswapV2Pair lpPair = IUniswapV2Pair(address(univ2()));

        cook().safeTransfer(address(univ2()), cookAmount);
        IERC20(wethAddress).safeTransferFrom(
            msg.sender,
            address(univ2()),
            wethAmount
        );
        return (wethAmount, lpPair.mint(address(this)));
    }

    function _zapLP(uint256 cookAmount, bool isWithEth) internal {
        require(cookAmount > 0, "zero zap amount");

        require(
            balanceOfClaimable(msg.sender) >= cookAmount,
            "insufficient claimable balance"
        );

        require(isWithEth == false, "Only supports WETH");

        checkMiningPaused();
        ensureAddrNotBlacklisted(msg.sender);

        uint256 lessWeth = 0;
        uint256 newUniv2 = 0;

        (lessWeth, newUniv2) = addLiquidity(cookAmount);

        checkPoolStakeCapLimit(newUniv2);
        checkPerAddrStakeLimit(newUniv2, msg.sender);

        incrementBalanceOfClaimed(msg.sender, cookAmount);
        updateStakeStates(newUniv2, msg.sender);
        uniBalanceCheck();

        emit ZapLP(msg.sender, newUniv2);
    }

    function zapLP(uint256 cookAmount) external {
        _zapLP(cookAmount, false);
    }

    function uniBalanceCheck() private view {
        require(
            univ2().balanceOf(address(this)) >= totalStaked(),
            "Inconsistent UNI-V2 balances"
        );
    }

    function cookBalanceCheck() private view {
        require(
            cook().balanceOf(address(this)) >=
                totalVesting().add(totalRewarded()).sub(totalClaimed()),
            "Inconsistent COOK balances"
        );
    }

    // admin emergency to safeTransfer token to owner
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
