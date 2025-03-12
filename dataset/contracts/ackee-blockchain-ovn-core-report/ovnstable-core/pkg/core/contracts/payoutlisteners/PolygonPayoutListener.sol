// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;


import "@openzeppelin/contracts-upgradeable/access/AccessControlUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/UUPSUpgradeable.sol";
import "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@overnight-contracts/connectors/contracts/stuff/Dystopia.sol";

import "../PayoutListener.sol";


contract PolygonPayoutListener is PayoutListener {

    address[] public qsSyncPools;
    address[] public qsSkimPools;
    address[] public qsBribes;
    IERC20 public usdPlus;
    mapping(address => uint256) public skimPoolBalances; // pool address -> USD+ balance
    IERC20 public dyst;
    IERC20 public wmatic;
    IDystopiaRouter public dystRouter;

    IBentoBoxV1 public sushiBentoBox;
    address public sushiWallet;
    address public dystopiaWallet;

    address[] public swapsicleSkimPools;
    address public swapsicleDepositWallet;

    // ---  events

    event SkimReward(address pool, uint256 amount);
    event SushiSkimReward(uint256 amount);
    event SushiBentoBoxUpdated(address sushiBentoBox);
    event SushiWalletUpdated(address sushiWallet);
    event DystopiaWalletUpdated(address dystopiaWallet);
    event SwapsicleSkimPoolsUpdated(address[] pool);
    event SwapsicleDepositWalletUpdated(address wallet);
    event SwapsicleSkimReward(uint256 amount);

    // --- setters


    struct Params{
        address usdPlus;
        address dyst;
        address wmatic;
        address dystRouter;
    }

    function setParams(Params calldata params) external onlyAdmin {
        usdPlus = IERC20(params.usdPlus);
        dyst = IERC20(params.dyst);
        wmatic = IERC20(params.wmatic);
        dystRouter = IDystopiaRouter(params.dystRouter);
    }

    function setSkimPools(address[] calldata _pools, address[] calldata _bribes) external onlyAdmin {
        require(_pools.length == _bribes.length, 'pools.size != bribes.size');
        qsSkimPools = _pools;
        qsBribes = _bribes;
    }

    function setSyncPools(address[] calldata _pools) external onlyAdmin {
        qsSyncPools = _pools;
    }

    function setSushiBentoBox(address _sushiBentoBox) external onlyAdmin {
        require(_sushiBentoBox != address(0), "Zero address not allowed");
        sushiBentoBox = IBentoBoxV1(_sushiBentoBox);
        emit SushiBentoBoxUpdated(_sushiBentoBox);
    }

    function setSushiWallet(address _sushiWallet) external onlyAdmin {
        require(_sushiWallet != address(0), "Zero address not allowed");
        sushiWallet = _sushiWallet;
        emit SushiWalletUpdated(_sushiWallet);
    }

    function setDystopiaWallet(address _dystopiaWallet) external onlyAdmin {
        require(_dystopiaWallet != address(0), "Zero address not allowed");
        dystopiaWallet = _dystopiaWallet;
        emit DystopiaWalletUpdated(_dystopiaWallet);
    }

    function setSwapsicleSkimPools(address[] calldata _swapsicleSkimPools) external onlyAdmin {
        require(_swapsicleSkimPools.length != 0, "Zero pools not allowed");
        swapsicleSkimPools = _swapsicleSkimPools;
        emit SwapsicleSkimPoolsUpdated(_swapsicleSkimPools);
    }

    function setSwapsicleDepositWallet(address _swapsicleDepositWallet) external onlyAdmin {
        require(_swapsicleDepositWallet != address(0), "Zero address not allowed");
        swapsicleDepositWallet = _swapsicleDepositWallet;
        emit SwapsicleDepositWalletUpdated(_swapsicleDepositWallet);
    }

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __PayoutListener_init();
    }

    // ---  logic

    function payoutDone() external override onlyExchanger {
        _sync();
        _skim();
        _sushiSkim();
        _swapsicleSkim();
    }


    function _sync() internal {
        for (uint256 i = 0; i < qsSyncPools.length; i++) {
            Pool(qsSyncPools[i]).sync();
        }
    }


    function swapUsdPlusToDyst() external onlyAdmin {

        for (uint256 i = 0; i < qsSkimPools.length; i++) {
            address pool = qsSkimPools[i];

            uint256 usdPlusAmount = skimPoolBalances[pool];
            uint256 dystAmount;
            if (usdPlusAmount != 0) {
                dystAmount = DystopiaLibrary._swapExactTokensForTokens(
                    dystRouter,
                    address(usdPlus),
                    address (wmatic),
                    address(dyst),
                    false,
                    false,
                    usdPlusAmount,
                    address(this)
                );

                skimPoolBalances[pool] = dystAmount;
            }

        }

    }

    function _skim() internal {

        for (uint256 i = 0; i < qsSkimPools.length; i++) {
            address pool = qsSkimPools[i];

            Pool(pool).skim(address(this));

            uint256 usdPlusSkimmed = usdPlus.balanceOf(address(this));

            // send skim from pool USD+/SPHERE to dystopiaWallet
            if (pool == address(0xb8E91631F348dD1F47Cb46f162df458a556c6f1e)) {
                usdPlus.transfer(dystopiaWallet, usdPlusSkimmed);
                continue;
            }

            uint256 dystAmount = DystopiaLibrary._swapExactTokensForTokens(
                dystRouter,
                address(usdPlus),
                address(wmatic),
                address(dyst),
                false,
                false,
                usdPlusSkimmed,
                address(this)
            );

            // Add previous balance DYST
            dystAmount += skimPoolBalances[pool];

            if(dystAmount > 0) {
                Bribe bribe = Bribe(qsBribes[i]);

                // Amount DYST on Bribe contract
                uint256 bribeAmount = bribe.left(address(dyst));

                // if we do not have enough amount DYST, then we do not charge bribes and save this DYST to next payout
                if(dystAmount > bribeAmount){

                    dyst.approve(address(bribe), dystAmount);
                    bribe.notifyRewardAmount(address(dyst), dystAmount);

                    // reset balance for pool
                    skimPoolBalances[pool] = 0;
                    emit SkimReward(pool, dystAmount);
                }else {
                    // save balance for the next payout
                    skimPoolBalances[pool] = dystAmount;
                }
            }
        }
    }

    function _sushiSkim() internal {
        uint256 usdPlusBalance = usdPlus.balanceOf(address(sushiBentoBox));
        uint256 usdPlusBalanceInPool = uint256(sushiBentoBox.totals(usdPlus).elastic);
        if (usdPlusBalance > usdPlusBalanceInPool) {
            uint256 deltaAmount = usdPlusBalance - usdPlusBalanceInPool;
            sushiBentoBox.deposit(usdPlus, address(sushiBentoBox), sushiWallet, deltaAmount, 0);
            emit SushiSkimReward(deltaAmount);
        }
    }

    function _swapsicleSkim() internal {
        uint256 usdPlusBalanceBefore = usdPlus.balanceOf(address(this));
        for (uint256 i = 0; i < swapsicleSkimPools.length; i++) {
            address pool = swapsicleSkimPools[i];
            uint256 usdPlusBalance = usdPlus.balanceOf(address(this));
            Pool(pool).skim(address(this));
            uint256 delta = usdPlus.balanceOf(address(this)) - usdPlusBalance;
            emit SkimReward(pool, delta);
        }
        uint256 totalDelta = usdPlus.balanceOf(address(this)) - usdPlusBalanceBefore;
        if (totalDelta > 0) {
            usdPlus.transfer(swapsicleDepositWallet, totalDelta);
        }
        emit SwapsicleSkimReward(totalDelta);
    }
}


interface Bribe {
    function notifyRewardAmount(address token, uint256 amount) external;
    function left(address token) external view returns (uint);
}

interface Pool {
    function sync() external;
    function skim(address to) external;
}

interface IBentoBoxV1 {
    struct Rebase {
        uint128 elastic;
        uint128 base;
    }
    function totals(IERC20) external view returns (Rebase calldata);
    function balanceOf(IERC20, address) external view returns (uint256);
    function deposit(IERC20 token_, address from, address to, uint256 amount, uint256 share) external payable returns (uint256 amountOut, uint256 shareOut);
    function harvest(IERC20 token, bool balance, uint256 maxChangeAmount) external;
    function strategyData(IERC20) external view returns (uint64 strategyStartDate, uint64 targetPercentage, uint128 balance);
    function toAmount(IERC20 token, uint256 share, bool roundUp) external view returns (uint256 amount);
    function toShare(IERC20 token, uint256 amount, bool roundUp) external view returns (uint256 share);
    function transfer(IERC20 token, address from, address to, uint256 share) external;
    function transferMultiple(IERC20 token, address from, address[] calldata tos, uint256[] calldata shares) external;
    function withdraw(IERC20 token_, address from, address to, uint256 amount, uint256 share) external returns (uint256 amountOut, uint256 shareOut);
}