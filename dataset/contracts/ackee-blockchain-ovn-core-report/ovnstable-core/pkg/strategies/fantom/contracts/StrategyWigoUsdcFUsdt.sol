// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "./core/Strategy.sol";
import "./exchanges/BeethovenxExchange.sol";
import "./libraries/LowGasSafeMath.sol";
import "./connectors/uniswap/v2/interfaces/IUniswapV2Router02.sol";
import "./connectors/uniswap/v2/interfaces/IUniswapV2Pair.sol";
import "./connectors/wigo/AWigoMasterFarmer.sol";

contract StrategyWigoUsdcFUsdt is Strategy, BeethovenExchange {
    using LowGasSafeMath for uint256;

    IERC20 public fUsdtToken;
    IERC20 public usdcToken;
    IERC20 public wigoToken;

    uint256 public bUsdcTokenDenominator;
    uint256 public bFUsdtTokenDenominator;

    IUniswapV2Router02 public router;
    IUniswapV2Pair public lpToken;
    AWigoMasterFarmer public masterFarmer;
    uint256 public pid;
    bytes32 public poolIdFUsdtUsdc;


    // --- events

    event StrategyUpdatedTokens(
        address fUsdtToken, address usdcToken, address wigoToken, 
        uint256 bUsdcTokenDenominator, uint256 bFUsdtTokenDenominator
    );

    event StrategyUpdatedParams(address router, address lpToken, address masterFarmer, uint256 pid,
        address beethovenxVault, bytes32 poolIdFUsdtUsdc);


    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- setters

    function setTokens(
        address _fUsdtToken,
        address _usdcToken,
        address _wigoToken
    ) external onlyAdmin {

        require(_fUsdtToken != address(0), "Zero address not allowed");
        require(_usdcToken != address(0), "Zero address not allowed");
        require(_wigoToken != address(0), "Zero address not allowed");

        fUsdtToken = IERC20(_fUsdtToken);
        usdcToken = IERC20(_usdcToken);
        wigoToken = IERC20(_wigoToken);

        bUsdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        bFUsdtTokenDenominator = 10 ** IERC20Metadata(_fUsdtToken).decimals();

        emit StrategyUpdatedTokens(_fUsdtToken, _usdcToken, _wigoToken, bUsdcTokenDenominator, bFUsdtTokenDenominator);
    }

    function setParams(
        address _router,
        address _lpToken,
        address _masterFarmer,
        uint256 _pid,
        address _beethovenxVault,
        bytes32 _poolIdFUsdtUsdc
    ) external onlyAdmin {

        require(_router != address(0), "Zero address not allowed");
        require(_lpToken != address(0), "Zero address not allowed");
        require(_masterFarmer != address(0), "Zero address not allowed");
        require(_beethovenxVault != address(0), "Zero address not allowed");
        require(_poolIdFUsdtUsdc != "", "Empty pool id not allowed");

        router = IUniswapV2Router02(_router);
        lpToken = IUniswapV2Pair(_lpToken);
        masterFarmer = AWigoMasterFarmer(_masterFarmer);
        pid = _pid;
        poolIdFUsdtUsdc = _poolIdFUsdtUsdc;

        setBeethovenxVault(_beethovenxVault);

        emit StrategyUpdatedParams(_router, _lpToken, _masterFarmer, _pid, _beethovenxVault, _poolIdFUsdtUsdc);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");
        (uint256 reserveUsdc, uint256 reserveFUsdt,) = lpToken.getReserves();
        require(
            reserveUsdc > bUsdcTokenDenominator / 1000 && reserveFUsdt > bFUsdtTokenDenominator / 1000, 
            'StrategyWigoUsdcFUsdt: Liquidity lpToken reserves too low'
        );

        // swap needed usdс to fUsdt
        uint256 amountUsdcToSwap = _getAmountUsdcToSwap(_amount, reserveUsdc, reserveFUsdt, bFUsdtTokenDenominator / bUsdcTokenDenominator);
        swap(
            poolIdFUsdtUsdc,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(usdcToken)),
            IAsset(address(fUsdtToken)),
            address(this),
            address(this),
            amountUsdcToSwap,
            0
        );

        // add liquidity
        uint256 amountUsdc = usdcToken.balanceOf(address(this));
        uint256 amountFUsdt = fUsdtToken.balanceOf(address(this));

        usdcToken.approve(address(router), amountUsdc);
        fUsdtToken.approve(address(router), amountFUsdt);
        router.addLiquidity(
            address(usdcToken),
            address(fUsdtToken),
            amountUsdc,
            amountFUsdt,
            amountUsdc * 99 / 100,
            amountFUsdt * 99 / 100,
            address(this),
            block.timestamp + 600
        );
        
        // deposit lpTokens
        uint256 lpBalance = lpToken.balanceOf(address(this));
        lpToken.approve(address(masterFarmer), lpBalance);
        masterFarmer.deposit(pid, lpBalance);

        amountFUsdt = fUsdtToken.balanceOf(address(this));
        if (amountFUsdt > 100) {
            swap(
                poolIdFUsdtUsdc,
                IVault.SwapKind.GIVEN_IN,
                IAsset(address(fUsdtToken)),
                IAsset(address(usdcToken)),
                address(this),
                address(this),
                amountFUsdt,
                0
            );
        }
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");
        
        (uint256 lpBalanceUser, ) = masterFarmer.userInfo(pid, address(this));
        if (lpBalanceUser == 0) {
            return 0;
        }

        // withdraw needed amount of lpTokens
        uint256 totalLpBalance = lpToken.totalSupply();
        (uint256 reserveUsdc, uint256 reserveFUsdt,) = lpToken.getReserves();
        uint256 lpBalance = _getAmountLPTokensForWithdraw(_amount, reserveUsdc, reserveFUsdt, totalLpBalance, bFUsdtTokenDenominator / bUsdcTokenDenominator) + 2;
        masterFarmer.withdraw(pid, lpBalance);

        // remove liquidity
        uint256 amountOutUsdcMin = reserveUsdc * lpBalance / totalLpBalance;
        uint256 amountOutFUsdtMin = reserveFUsdt * lpBalance / totalLpBalance;
        lpToken.approve(address(router), lpBalance);
        router.removeLiquidity(
            lpToken.token0(),
            lpToken.token1(),
            lpBalance,
            amountOutUsdcMin * 99 / 100,
            amountOutFUsdtMin * 99 / 100,
            address(this),
            block.timestamp + 600
        );
        
    
        // swap fUsdt to usdc
        uint256 fUsdtBalance = fUsdtToken.balanceOf(address(this));
        swap(
            poolIdFUsdtUsdc,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(fUsdtToken)),
            IAsset(address(usdcToken)),
            address(this),
            address(this),
            fUsdtBalance,
            0
        );

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (uint256 lpBalanceUser, ) = masterFarmer.userInfo(pid, address(this));
        if (lpBalanceUser == 0) {
            return 0;
        }

        // withdraw lpTokens from masterFarmer
        masterFarmer.withdraw(pid, lpBalanceUser);

        // remove liquidity
        uint256 totalLpBalance = lpToken.totalSupply();
        (uint256 reserveUsdc, uint256 reserveFUsdt,) = lpToken.getReserves();
        uint256 amountOutUsdcMin = reserveUsdc * lpBalanceUser / totalLpBalance;
        uint256 amountOutFUsdtMin = reserveFUsdt * lpBalanceUser / totalLpBalance;
        lpToken.approve(address(router), lpBalanceUser);
        router.removeLiquidity(
            lpToken.token0(),
            lpToken.token1(),
            lpBalanceUser,
            amountOutUsdcMin * 99 / 100,
            amountOutFUsdtMin * 99 / 100,
            address(this),
            block.timestamp + 600
        );

        // swap fUsdt to usdc
        uint256 fUsdtBalance = fUsdtToken.balanceOf(address(this));
        swap(
            poolIdFUsdtUsdc,
            IVault.SwapKind.GIVEN_IN,
            IAsset(address(fUsdtToken)),
            IAsset(address(usdcToken)),
            address(this),
            address(this),
            fUsdtBalance,
            0
        );

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        (uint256 lpBalance, ) = masterFarmer.userInfo(pid, address(this));
        if (lpBalance == 0) {
            return 0;
        }
        uint256 totalLpBalance = lpToken.totalSupply();
        (uint256 reserveUsdc, uint256 reserveFUsdt,) = lpToken.getReserves();
        uint256 usdcBalance = reserveUsdc * lpBalance / totalLpBalance + usdcToken.balanceOf(address(this));
        uint256 fUsdtBalance = reserveFUsdt * lpBalance / totalLpBalance + fUsdtToken.balanceOf(address(this));

        uint256 usdcBalanceFromFUsdt = onSwap(
            poolIdFUsdtUsdc,
            IVault.SwapKind.GIVEN_IN,
            fUsdtToken,
            usdcToken,
            fUsdtBalance
        );

        return usdcBalance + usdcBalanceFromFUsdt;
    }

    function _claimRewards(address _to) internal override returns (uint256) {
        // claim rewards
        masterFarmer.withdraw(pid, 0);

        // sell rewards
        uint256 totalUsdc;
        uint256 wigoBalance = wigoToken.balanceOf(address(this));

        if (wigoBalance != 0) {
            uint256 wigoUsdc = _swapWigoToUsdc(wigoBalance);
            totalUsdc += wigoUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));
        return totalUsdc;
    }

    function _swapWigoToUsdc(uint256 wigoBalance) internal returns (uint256) {
        wigoToken.approve(address(router), wigoBalance);

        address[] memory path = new address[](2);
        path[0] = address(wigoToken);
        path[1] = address(usdcToken);

        uint256[] memory amounts = router.swapExactTokensForTokens(
                wigoBalance,
                0,
                path,
                address(this),
                block.timestamp + 600
            );

        return amounts[1];
    }

    function _getAmountUsdcToSwap(
        uint256 amount,
        uint256 reserveUsdc,
        uint256 reserveFUsdt,
        uint256 decimalDelta
    ) internal view returns (uint256) {
        uint256 amountUsdcToSwap = (amount * reserveFUsdt) / (reserveFUsdt + reserveUsdc * decimalDelta);
        for (uint i=0; i<2; i++) {
            uint256 swappedFUsdt = onSwap(
                poolIdFUsdtUsdc,
                IVault.SwapKind.GIVEN_IN,
                usdcToken,
                fUsdtToken,
                amountUsdcToSwap
            );
            amountUsdcToSwap = (amount * reserveFUsdt * amountUsdcToSwap) / (reserveFUsdt * amountUsdcToSwap + reserveUsdc * swappedFUsdt);
        }
        return amountUsdcToSwap;
    }

    function _getAmountLPTokensForWithdraw(
        uint256 amount,
        uint256 reserveUsdc,
        uint256 reserveFUsdt,
        uint256 totalLpBalance,
        uint256 decimalDelta
    ) internal view returns (uint256) {
        uint256 lpBalance;
        uint256 amountFUsdtToSwap = decimalDelta;
        uint256 swappedUsdc = 1;
        for (uint i=0; i<2; i++) {
            lpBalance = (totalLpBalance * amountFUsdtToSwap * amount) / (reserveFUsdt * swappedUsdc + reserveUsdc * amountFUsdtToSwap);
            amountFUsdtToSwap = (reserveFUsdt * lpBalance) / totalLpBalance;
            swappedUsdc = onSwap(
                poolIdFUsdtUsdc,
                IVault.SwapKind.GIVEN_IN,
                fUsdtToken,
                usdcToken,
                amountFUsdtToSwap
            );
        }
        lpBalance = (totalLpBalance * amountFUsdtToSwap * amount) / (reserveFUsdt * swappedUsdc + reserveUsdc * amountFUsdtToSwap);
        return lpBalance;
    }
}