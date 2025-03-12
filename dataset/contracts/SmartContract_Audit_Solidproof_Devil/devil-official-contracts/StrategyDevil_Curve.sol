pragma solidity 0.6.12;

import "./StrategyDevil.sol";

interface IRewardsGauge {
    function balanceOf(address account) external view returns (uint256);
    function claim_rewards(address _addr) external;
    function deposit(uint256 _value) external;
    function withdraw(uint256 _value) external;
}

interface I2PoolLP {
    function add_liquidity(uint256[2] memory amounts, uint256 min_mint_amount) external;
}
interface I3PoolLP {
    function add_liquidity(uint256[3] memory amounts, uint256 min_mint_amount) external;
}
interface I4PoolLP {
    function add_liquidity(uint256[4] memory amounts, uint256 min_mint_amount) external;
}

contract StrategyDevil_Curve is StrategyDevil {
    address public curveLPAddress;
    uint256 public nPools;
    uint256 public iPool;

    address public earnedAddress2;
    address[] public earned2ToEarnedPath;

    constructor(
        address[] memory _addresses,
        address[] memory _tokenAddresses,
        uint256 _pid,
        address[] memory _earnedToNATIVEPath,
        address[] memory _earnedToToken0Path,
        address[] memory _token0ToEarnedPath,
        address[] memory _earned2ToEarnedPath,
        uint256 _depositFeeFactor,
        uint256 _withdrawFeeFactor,
        uint256 _entranceFeeFactor,
        address _curveLPAddress,
        uint256 _nPools,
        uint256 _iPool
    ) public {
        nativeFarmAddress = _addresses[0];
        farmContractAddress = _addresses[1];
        govAddress = _addresses[2];
        uniRouterAddress = _addresses[3];
        buybackRouterAddress = _addresses[4];

        NATIVEAddress = _tokenAddresses[0];
        wftmAddress = _tokenAddresses[1];
        wantAddress = _tokenAddresses[2];
        earnedAddress = _tokenAddresses[3];
        token0Address = _tokenAddresses[4];
        earnedAddress2 = _tokenAddresses[5];

        pid = _pid;
        isSingleVault = false;
        isAutoComp = true;

        earnedToNATIVEPath = _earnedToNATIVEPath;
        earnedToToken0Path = _earnedToToken0Path;
        token0ToEarnedPath = _token0ToEarnedPath;
        earned2ToEarnedPath = _earned2ToEarnedPath;

        depositFeeFactor = _depositFeeFactor;
        withdrawFeeFactor = _withdrawFeeFactor;
        entranceFeeFactor = _entranceFeeFactor;

        curveLPAddress = _curveLPAddress;
        nPools = _nPools;
        iPool = _iPool;
        require(iPool < nPools, "Invalid iPool");

        transferOwnership(nativeFarmAddress);
    }

    function _farm() internal override virtual {
        require(isAutoComp, "!isAutoComp");
        uint256 wantAmt = IERC20(wantAddress).balanceOf(address(this));
        wantLockedTotal = wantLockedTotal.add(wantAmt);
        IERC20(wantAddress).safeIncreaseAllowance(farmContractAddress, wantAmt);

        IRewardsGauge(farmContractAddress).deposit(wantAmt);
    }

    function _unfarm(uint256 _wantAmt) internal override virtual {
        IRewardsGauge(farmContractAddress).withdraw(_wantAmt);
    }

    function _harvest() internal override virtual {
        // Harvest farm tokens
        IRewardsGauge(farmContractAddress).claim_rewards(address(this));

        // convert second earning token to earned
        if (earnedAddress != earnedAddress2) {
            uint256 earned2Amt = IERC20(earnedAddress2).balanceOf(address(this));
            IERC20(earnedAddress2).safeIncreaseAllowance(
                uniRouterAddress,
                earned2Amt
            );
            if (earned2Amt > 0) {
                _safeSwap(
                    uniRouterAddress,
                    earned2Amt,
                    slippageFactor,
                    earned2ToEarnedPath,
                    address(this),
                    now + routerDeadlineDuration
                );
            }
        }
    }

    function earn() public override nonReentrant whenNotPaused {
        require(isAutoComp, "!isAutoComp");

        // Harvest farm tokens
        _harvest();

        // Converts farm tokens into want tokens

        uint256 earnedAmt = IERC20(earnedAddress).balanceOf(address(this));

        earnedAmt = distributeFees(earnedAmt);
        earnedAmt = buyBack(earnedAmt);

        IERC20(earnedAddress).safeApprove(uniRouterAddress, 0);
        IERC20(earnedAddress).safeIncreaseAllowance(
            uniRouterAddress,
            earnedAmt
        );

        _safeSwap(
            uniRouterAddress,
            earnedAmt,
            slippageFactor,
            earnedToToken0Path,
            address(this),
            now + routerDeadlineDuration
        );

        // Get want tokens, ie. get iToken
        uint256 token0Amt = IERC20(token0Address).balanceOf(address(this));

        IERC20(token0Address).safeIncreaseAllowance(curveLPAddress, token0Amt);
        if (nPools == 2) {
            uint256[2] memory uamounts;
            uamounts[iPool] = token0Amt;
            I2PoolLP(curveLPAddress).add_liquidity(uamounts, 0);
        } else if (nPools == 3) {
            uint256[3] memory uamounts;
            uamounts[iPool] = token0Amt;
            I3PoolLP(curveLPAddress).add_liquidity(uamounts, 0);
        } else if (nPools == 4) {
            uint256[4] memory uamounts;
            uamounts[iPool] = token0Amt;
            I4PoolLP(curveLPAddress).add_liquidity(uamounts, 0);
        } else {
            revert("Invalid nPools");
        }

        lastEarnBlock = block.number;
        _farm();
    }
}