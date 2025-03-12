// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;
pragma experimental ABIEncoderV2;

import {Math} from '../utils/math/Math.sol';
import {IARTH} from '../Arth/IARTH.sol';
import {Pausable} from './Pausable.sol';
import {IERC20} from '../ERC20/IERC20.sol';
import {SafeMath} from '../utils/math/SafeMath.sol';
import {SafeERC20} from '../ERC20/SafeERC20.sol';
import {IStakingRewards} from './IStakingRewards.sol';
import {ReentrancyGuard} from '../utils/ReentrancyGuard.sol';
import {RewardsDistributionRecipient} from './RewardsDistributionRecipient.sol';
import {
    IStakingRewardsDualForMigrator
} from './IStakingRewardsDualForMigrator.sol';
import {IUniswapV2Pair} from '../Uniswap/Interfaces/IUniswapV2Pair.sol';
import {IUniswapV2Router02} from '../Uniswap/Interfaces/IUniswapV2Router02.sol';

/**
 * @title  UniLPToSushiLPMigrator
 * @author MahaDAO.
 *
 *  Original code written by:
 *  - Travis Moore, Jason Huan, Same Kazemian, Sam Sun.
 */
contract UniLPToSushiLPMigrator is
    IStakingRewards,
    RewardsDistributionRecipient,
    ReentrancyGuard,
    Pausable
{
    using SafeMath for uint256;
    using SafeERC20 for IERC20;

    /**
     * State variables.
     * NOTE: DUPLICATE VARIABLES (NEEDED FOR DELEGATECALL)
     */

    IERC20 public rewardsToken;
    IERC20 public stakingToken;
    IUniswapV2Pair public DestLPPair;
    IUniswapV2Pair public SourceLPPair;
    IStakingRewardsDualForMigrator public DestStakingContract;
    IStakingRewardsDualForMigrator public SourceStakingContract;

    IUniswapV2Router02 internal constant _UniswapRouter =
        IUniswapV2Router02(UNISWAP_ROUTER_ADDRESS);
    IUniswapV2Router02 internal constant _SushiSwapRouter =
        IUniswapV2Router02(SUSHISWAP_ROUTER_ADDRESS);
    IARTH private _ARTH;

    uint256 public periodFinish;
    // Max reward per second
    uint256 public rewardRate;
    uint256 public ADD_LIQUIDITY_SLIPPAGE = 950; // will be .div(1000)

    // This staking pool's percentage of the total ARTHX being distributed by all pools, 6 decimals of precision
    uint256 public poolWeight;
    uint256 public lastUpdateTime;
    // uint256 public rewardsDuration = 86400 hours;
    uint256 public rewardsDuration = 604800; // 7 * 86400  (7 days)
    uint256 public rewardPerTokenStored = 0;

    uint256 public lockedStakeMaxMultiplier = 3000000; // 6 decimals of precision. 1x = 1000000
    uint256 public lockedStakeTimeForMaxMultiplier = 3 * 365 * 86400; // 3 years
    uint256 public lockedStakeMinTime = 604800; // 7 * 86400  (7 days)

    uint256 public cr_boost_max_multiplier = 3000000; // 6 decimals of precision. 1x = 1000000

    uint256 private _stakingTokenSupply = 0;
    uint256 private _stakingTokenBoostedSupply = 0;

    address public destLPPairAddr;
    address public sourceLPPairAddr;
    address public destStakingContractAddr;
    address public sourceStakingContractAddr;
    address payable public constant UNISWAP_ROUTER_ADDRESS =
        payable(0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D);
    address payable public constant SUSHISWAP_ROUTER_ADDRESS =
        payable(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);

    bool public isUnlockedStakes; // Release lock stakes in case of system migration

    address public ownerAddress;
    address public timelockAddress; // Governance timelock address

    mapping(address => bool) public greylist;
    mapping(address => uint256) public rewards;
    mapping(address => uint256) public userRewardPerTokenPaid;

    // Constant for various precisions
    uint256 private constant _PRICE_PRECISION = 1e6;
    uint256 private constant _MULTIPLIER_BASE = 1e6;
    string private _lockedStakeMinTimeStr = '604800'; // 7 days on genesis

    mapping(address => uint256) private _lockedBalances;
    mapping(address => uint256) private _boostedBalances;
    mapping(address => uint256) private _unlockedBalances;

    mapping(address => IStakingRewardsDualForMigrator.ILockedStake[])
        private _lockedStakes;

    /**
     * Modifiers.
     */

    modifier onlyByOwnerOrGovernance() {
        require(
            msg.sender == ownerAddress || msg.sender == timelockAddress,
            'You are not the owner or the governance timelock'
        );
        _;
    }

    /**
     * Events.
     */

    event Recovered(address token, uint256 amount);
    event Migrated(address indexed user, address sourceAddr, address destAddr);

    /**
     * Constructor.
     */

    constructor(
        address _owner,
        address _sourceStakingContractAddr,
        address _destStakingContractAddr
    ) {
        ownerAddress = _owner;
        sourceStakingContractAddr = _sourceStakingContractAddr;
        destStakingContractAddr = _destStakingContractAddr;

        SourceStakingContract = IStakingRewardsDualForMigrator(
            sourceStakingContractAddr
        );
        DestStakingContract = IStakingRewardsDualForMigrator(
            destStakingContractAddr
        );

        sourceLPPairAddr = address(SourceStakingContract.stakingToken());
        destLPPairAddr = address(DestStakingContract.stakingToken());

        SourceLPPair = IUniswapV2Pair(sourceLPPairAddr);
        DestLPPair = IUniswapV2Pair(destLPPairAddr);
    }

    /**
     * External.
     */

    function delegatecallStake() external {
        // (bool success, bytes memory result) = address(SourceStakingContract).delegatecall(
        //     abi.encodeWithSignature("stake(uint256)", 1e18)
        // );

        (bool success, bytes memory result) =
            address(SourceStakingContract).delegatecall(
                abi.encode(
                    bytes4(keccak256('stake(uint256)')),
                    1000000000000000000
                )
            );

        if (!success) {
            if (result.length > 0) {
                revert(string(result));
            } else {
                revert();
            }
        }
        require(success, 'delegatecallStake failed');
    }

    function delegatecallGetReward() external {
        (bool success, bytes memory result) =
            address(SourceStakingContract).delegatecall(
                abi.encodeWithSignature('getReward()')
            );
        if (!success) {
            if (result.length > 0) {
                revert(string(result));
            } else {
                revert();
            }
        }
        require(success, 'delegatecallGetReward failed');
    }

    function normalGetReward() external {
        SourceStakingContract.getReward();
    }

    function migrateUnlocked() external {}

    function migrateOneLocked(bytes32 kekId) external {}

    function migrateAllLocked() external {
        // Unlock the stakes
        SourceStakingContract.unlockStakes();

        // Loop through the locked stakes
        IStakingRewardsDualForMigrator.ILockedStake[] memory lockedStakes =
            SourceStakingContract.lockedStakesOf(msg.sender);

        for (uint256 i = 0; i < lockedStakes.length; i++) {
            // Withdraw the locked Uni LP tokens [delegatecall]
            // ----------------------------------------------------------
            {
                (bool success, bytes memory result) =
                    address(SourceStakingContract).delegatecall(
                        abi.encodeWithSignature(
                            'withdrawLocked(bytes32)',
                            lockedStakes[i].kekId
                        )
                    );
                if (!success) {
                    if (result.length > 0) {
                        revert(string(result));
                    } else {
                        revert();
                    }
                }
                require(success, 'Uni withdrawLocked failed');
            }

            // Approve Uni LP for Uniswap removeLiquidity [delegatecall]
            // ----------------------------------------------------------
            {
                (bool success, ) =
                    address(SourceLPPair).delegatecall(
                        abi.encodeWithSignature(
                            'approve(address,uint256)',
                            UNISWAP_ROUTER_ADDRESS,
                            lockedStakes[i].amount
                        )
                    );
                require(success, 'Approve Uni LP for Uniswap failed');
            }

            // Remove the liquidity from Uni [delegatecall]
            // ----------------------------------------------------------
            uint256 token0_returned;
            uint256 token1_returned;
            {
                (bool success, bytes memory data) =
                    address(_UniswapRouter).delegatecall(
                        abi.encodeWithSignature(
                            'removeLiquidity(address,address,uint,uint,uint,address,uint)',
                            SourceLPPair.token0(),
                            SourceLPPair.token1(),
                            lockedStakes[i].amount,
                            0,
                            0,
                            msg.sender,
                            2105300114
                        )
                    );
                require(success, '_UniswapRouter removeLiquidity failed');
                (token0_returned, token1_returned) = abi.decode(
                    data,
                    (uint256, uint256)
                );
            }

            // Approve token0 for Sushi addLiquidity [delegatecall]
            // ----------------------------------------------------------
            {
                (bool success, ) =
                    address(SourceLPPair.token0()).delegatecall(
                        abi.encodeWithSignature(
                            'approve(address,uint256)',
                            SUSHISWAP_ROUTER_ADDRESS,
                            token0_returned
                        )
                    );
                require(
                    success,
                    'Approve token0 for Sushi addLiquidity failed'
                );
            }

            // Approve token1 for Sushi addLiquidity [delegatecall]
            // ----------------------------------------------------------
            {
                (bool success, ) =
                    address(SourceLPPair.token1()).delegatecall(
                        abi.encodeWithSignature(
                            'approve(address,uint256)',
                            SUSHISWAP_ROUTER_ADDRESS,
                            token1_returned
                        )
                    );
                require(
                    success,
                    'Approve token1 for Sushi addLiquidity failed'
                );
            }

            // Add liquidity to Sushi [delegatecall]
            // ----------------------------------------------------------
            uint256 slp_returned;
            {
                (bool success, bytes memory data) =
                    address(_SushiSwapRouter).delegatecall(
                        abi.encodeWithSignature(
                            'addLiquidity(address,address,uint,uint,uint,uint,address,uint)',
                            SourceLPPair.token0(),
                            SourceLPPair.token1(),
                            token0_returned,
                            token1_returned,
                            token0_returned.mul(ADD_LIQUIDITY_SLIPPAGE).div(
                                1000
                            ),
                            token1_returned.mul(ADD_LIQUIDITY_SLIPPAGE).div(
                                1000
                            ),
                            msg.sender,
                            2105300114 // A long time from now
                        )
                    );
                require(success, '_SushiSwapRouter addLiquidity failed');
                (, , slp_returned) = abi.decode(
                    data,
                    (uint256, uint256, uint256)
                );
            }

            // Add a locked stake [delegatecall]
            // ----------------------------------------------------------
            {
                (
                    bool success, /* bytes memory data */

                ) =
                    address(DestStakingContract).delegatecall(
                        abi.encodeWithSignature(
                            'stakeLocked(uint,uint)',
                            slp_returned,
                            (lockedStakes[i].endingTimestamp).sub(
                                block.timestamp
                            )
                        )
                    );
                require(success, 'Sushi stakeLocked failed');
            }
        }

        // Re-Lock the stakes
        // ----------------------------------------------------------
        SourceStakingContract.unlockStakes();

        emit Migrated(
            msg.sender,
            sourceStakingContractAddr,
            destStakingContractAddr
        );
    }

    // Added to support recovering LP Rewards and other mistaken tokens from other systems to be distributed to holders
    function recoverERC20(address tokenAddress, uint256 tokenAmount)
        external
        onlyByOwnerOrGovernance
    {
        IERC20(tokenAddress).transfer(ownerAddress, tokenAmount);
        emit Recovered(tokenAddress, tokenAmount);
    }

    function setOwnerAndTimelock(address _newOwner, address _newTimelock)
        external
        onlyByOwnerOrGovernance
    {
        ownerAddress = _newOwner;
        timelockAddress = _newTimelock;
    }

    function stake(uint256 amount) external override {}

    function withdraw(uint256 amount) external override {}

    function getReward() external override {}

    function lastTimeRewardApplicable()
        external
        pure
        override
        returns (uint256)
    {
        return 0;
    }

    function stakeLockedFor(
        address who,
        uint256 amount,
        uint256 duration
    ) external override {}

    function stakeFor(address who, uint256 amount) external override {}

    function stakeLocked(uint256 amount, uint256 secs) external override {}

    function withdrawLocked(bytes32 kekId) external override {}

    function rewardPerToken() external pure override returns (uint256) {
        return 0;
    }

    function earned(address account) external pure override returns (uint256) {
        return 0;
    }

    function getRewardForDuration() external pure override returns (uint256) {
        return 0;
    }

    function totalSupply() external pure override returns (uint256) {
        return 0;
    }

    function balanceOf(address account)
        external
        pure
        override
        returns (uint256)
    {
        return 0;
    }
}
