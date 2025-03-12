// SPDX-License-Identifier: MIT

pragma solidity 0.6.6;

import "./lib/@uniswap/interfaces/IUniswapV2Pair.sol";
import "./interfaces/IAnyStake.sol";
import "./interfaces/IVaultMigrator.sol";
import "./interfaces/IAnyStakeRegulator.sol";
import "./interfaces/IAnyStakeVault.sol";
import "./utils/AnyStakeUtils.sol";

contract AnyStakeVault is IAnyStakeVault, AnyStakeUtils {
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    event AnyStakeUpdated(address indexed user, address anystake);
    event RegulatorUpdated(address indexed user, address regulator);
    event MigratorUpdated(address indexed user, address migrator);
    event DistributionRateUpdated(address indexed user, uint256 distributionRate);
    event Migrate(address indexed user, address migrator);
    event DeFiatBuyback(address indexed token, uint256 tokenAmount, uint256 buybackAmount);
    event PointsBuyback(address indexed token, uint256 tokenAmount, uint256 buybackAmount);
    event RewardsDistributed(address indexed user, uint256 anystakeAmount, uint256 regulatorAmount);
    event RewardsBonded(address indexed user, uint256 bondedAmount, uint256 bondedLengthBlocks);

    address public anystake;
    address public regulator;
    address public migrator;

    uint256 public bondedRewards; // DFT bonded (block-based) rewards
    uint256 public bondedRewardsPerBlock; // Amt of bonded DFT paid out each block
    uint256 public bondedRewardsBlocksRemaining; // Remaining bonding period
    uint256 public distributionRate; // % of rewards which are sent to AnyStake
    uint256 public lastDistributionBlock; // last block that rewards were distributed
    uint256 public totalTokenBuybackAmount; // total DFT bought back
    uint256 public totalPointsBuybackAmount; // total DFTPv2 bought back
    uint256 public totalRewardsDistributed; // total rewards distributed from Vault
    uint256 public pendingRewards; // total rewards pending claim

    modifier onlyAuthorized() {
        require(
            msg.sender == anystake || msg.sender == regulator, 
            "Vault: Only AnyStake and Regulator allowed"
        );
        _;
    }
    
    constructor(
        address _router, 
        address _gov, 
        address _points, 
        address _token, 
        address _anystake, 
        address _regulator
    ) 
        public
        AnyStakeUtils(_router, _gov, _points, _token)
    {
        anystake = _anystake;
        regulator = _regulator;
        distributionRate = 700; // 70%, base 100
    }

    // Rewards - Distribute accumulated rewards during pool update
    function calculateRewards() external override onlyAuthorized {
        if (block.number <= lastDistributionBlock) {
            return;
        }

        uint256 anystakeAmount;
        uint256 regulatorAmount;

        // find the transfer fee amount
        // fees accumulated = balance - pendingRewards - bondedRewards
        uint256 feeAmount = IERC20(DeFiatToken).balanceOf(address(this))
            .sub(pendingRewards)
            .sub(bondedRewards);
        
        // calculate fees accumulated since last update
        if (feeAmount > 0) {
            // find the amounts to distribute to each contract
            uint256 anystakeShare = feeAmount.mul(distributionRate).div(1000);
            anystakeAmount = anystakeAmount.add(anystakeShare);
            regulatorAmount = regulatorAmount.add(feeAmount.sub(anystakeShare));
        }

        // find the bonded reward amount
        if (bondedRewards > 0) {
            // find blocks since last bond payout, dont overflow
            uint256 blockDelta = block.number.sub(lastDistributionBlock);
            if (blockDelta > bondedRewardsBlocksRemaining) {
                blockDelta = bondedRewardsBlocksRemaining;
            }

            // find the bonded amount to payout, dont overflow
            uint256 bondedAmount = bondedRewardsPerBlock.mul(blockDelta);
            if (bondedAmount > bondedRewards) {
                bondedAmount = bondedRewards;
            }

            // find the amounts to distribute to each contract
            uint256 anystakeShare = bondedAmount.mul(distributionRate).div(1000);
            anystakeAmount = anystakeAmount.add(anystakeShare);
            regulatorAmount = regulatorAmount.add(bondedAmount.sub(anystakeShare));

            // update bonded rewards before calc'ing fees
            bondedRewards = bondedRewards.sub(bondedAmount);
            bondedRewardsBlocksRemaining = bondedRewardsBlocksRemaining.sub(blockDelta);
        }

        if (anystakeAmount == 0 && regulatorAmount == 0) {
            return;
        }

        if (anystakeAmount > 0) {
            IAnyStake(anystake).addReward(anystakeAmount);
        }

        if (regulatorAmount > 0) {
            IAnyStakeRegulator(regulator).addReward(regulatorAmount);
        }
        
        lastDistributionBlock = block.number;
        pendingRewards = pendingRewards.add(anystakeAmount).add(regulatorAmount);
        totalRewardsDistributed = totalRewardsDistributed.add(anystakeAmount).add(regulatorAmount);
        emit RewardsDistributed(msg.sender, anystakeAmount, regulatorAmount);
    }

    function distributeRewards(address recipient, uint256 amount) external override onlyAuthorized {
        safeTokenTransfer(recipient, DeFiatToken, amount);
        pendingRewards = pendingRewards.sub(amount);
    }

    // Uniswap - Get token price from Uniswap in ETH
    // return is 1e18. max Solidity is 1e77. 
    function getTokenPrice(address token, address lpToken) public override view returns (uint256) {
        if (token == weth) {
            return 1e18;
        }
        
        // LP Tokens can be priced with address(0) as lpToken argument
        // LP Token pricing is vulerable to flash loan attacks and should not be used in contract calculations
        IUniswapV2Pair pair = lpToken == address(0) ? IUniswapV2Pair(token) : IUniswapV2Pair(lpToken);
        
        uint256 wethReserves;
        uint256 tokenReserves;
        if (pair.token0() == weth) {
            (wethReserves, tokenReserves, ) = pair.getReserves();
        } else {
            (tokenReserves, wethReserves, ) = pair.getReserves();
        }
        
        if (tokenReserves == 0) {
            return 0;
        } else if (lpToken == address(0)) {
            return wethReserves.mul(2e18).div(IERC20(token).totalSupply());
        } else {
            uint256 adjuster = 36 - uint256(IERC20(token).decimals());
            uint256 tokensPerEth = tokenReserves.mul(10**adjuster).div(wethReserves);
            return uint256(1e36).div(tokensPerEth);
        }
    }

    // Uniswap - Buyback DeFiat Tokens (DFT) from Uniswap with ERC20 tokens
    function buyDeFiatWithTokens(address token, uint256 amount) external override onlyAuthorized {
        uint256 buybackAmount = buyTokenWithTokens(DeFiatToken, token, amount);

        if (buybackAmount > 0) {
            totalTokenBuybackAmount = totalTokenBuybackAmount.add(buybackAmount);
            emit DeFiatBuyback(token, amount, buybackAmount);
        }
    }

    // Uniswap - Buyback DeFiat Points (DFTP) from Uniswap with ERC20 tokens
    function buyPointsWithTokens(address token, uint256 amount) external override onlyAuthorized {
        uint256 buybackAmount = buyTokenWithTokens(DeFiatPoints, token, amount);
        
        if (msg.sender == regulator) {
            pendingRewards = pendingRewards.sub(amount);
        }

        if (buybackAmount > 0) {
            totalPointsBuybackAmount = totalPointsBuybackAmount.add(buybackAmount);
            emit PointsBuyback(token, amount, buybackAmount);
        }
    }

    // Uniswap - Internal buyback function. Must have a WETH trading pair on Uniswap
    function buyTokenWithTokens(address tokenOut, address tokenIn, uint256 amount) internal onlyAuthorized returns (uint256) {
        if (amount == 0) {
            return 0;
        }
        
        address[] memory path = new address[](tokenIn == weth ? 2 : 3);
        if (tokenIn == weth) {
            path[0] = weth; // WETH in
            path[1] = tokenOut; // DFT out
        } else {
            path[0] = tokenIn; // ERC20 in
            path[1] = weth; // WETH intermediary
            path[2] = tokenOut; // DFT out
        }
     
        uint256 tokenAmount = IERC20(tokenOut).balanceOf(address(this)); // snapshot
        
        IERC20(tokenIn).safeApprove(router, 0);
        IERC20(tokenIn).safeApprove(router, amount);
        IUniswapV2Router02(router).swapExactTokensForTokensSupportingFeeOnTransferTokens(
            amount, 
            0,
            path,
            address(this),
            block.timestamp + 5 minutes
        );

        uint256 buybackAmount = IERC20(tokenOut).balanceOf(address(this)).sub(tokenAmount);

        return buybackAmount;
    }

    function migrate() external onlyGovernor {
        require(migrator != address(0), "Migrate: No migrator set");

        uint256 balance = IERC20(DeFiatToken).balanceOf(address(this));
        
        // approve and migrate to new vault
        // this function will need to maintain the pendingRewards, bondedRewards, lastDistributionBlock
        // variables from this contract to ensure users can claim at all times
        IERC20(DeFiatToken).safeApprove(migrator, balance);
        IVaultMigrator(migrator).migrateTo();
        emit Migrate(msg.sender, migrator);
    }

    // Governance - Add Bonded Rewards, rewards paid out over fixed timeframe
    // Used for pre-AnyStake accumulated Treasury rewards and promotions
    function addBondedRewards(uint256 _amount, uint256 _blocks) external onlyGovernor {
        require(_amount > 0, "AddBondedRewards: Cannot add zero rewards");
        require(_blocks > 0, "AddBondedRewards: Cannot have zero block bond");

        // Add rewards, add to blocks, re-calculate rewards per block
        bondedRewards = bondedRewards.add(_amount);
        bondedRewardsBlocksRemaining = bondedRewardsBlocksRemaining.add(_blocks);
        bondedRewardsPerBlock = bondedRewards.div(bondedRewardsBlocksRemaining);
        lastDistributionBlock = block.number;

        IERC20(DeFiatToken).transferFrom(msg.sender, address(this), _amount);
        emit RewardsBonded(msg.sender, _amount, _blocks);
    }

    // Governance - Set AnyStake / Regulator DFT Reward Distribution Rate, 10 = 1%
    function setDistributionRate(uint256 _distributionRate) external onlyGovernor {
        require(_distributionRate != distributionRate, "SetRate: No rate change");
        require(_distributionRate <= 1000, "SetRate: Cannot be greater than 100%");

        distributionRate = _distributionRate;
        emit DistributionRateUpdated(msg.sender, distributionRate);
    }

    // Governance - Set Migrator
    function setMigrator(address _migrator) external onlyGovernor {
        require(_migrator != address(0), "SetMigrator: No migrator change");

        migrator = _migrator;
        emit MigratorUpdated(msg.sender, _migrator);
    }

    // Governance - Set AnyStake Address
    function setAnyStake(address _anystake) external onlyGovernor {
        require(_anystake != anystake, "SetAnyStake: No AnyStake change");
        require(_anystake != address(0), "SetAnyStake: Must have AnyStake value");

        anystake = _anystake;
        emit AnyStakeUpdated(msg.sender, anystake);
    }

    // Governance - Set Regulator Address
    function setRegulator(address _regulator) external onlyGovernor {
        require(_regulator != regulator, "SetRegulator: No Regulator change");
        require(_regulator != address(0), "SetRegulator: Must have Regulator value");

        regulator = _regulator;
        emit RegulatorUpdated(msg.sender, regulator);
    }
}
