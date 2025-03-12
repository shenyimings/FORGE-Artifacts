// SPDX-License-Identifier: AGPL-3.0
// Feel free to change the license, but this is what we use

// Feel free to change this version of Solidity. We support >=0.6.0 <0.7.0;
pragma solidity 0.6.12;
pragma experimental ABIEncoderV2;

// These are the core Yearn libraries
import {
    BaseStrategy
} from "@yearnvaults/contracts/BaseStrategy.sol";
import {
    SafeERC20,
    SafeMath,
    IERC20,
    Address
} from "@openzeppelin/contracts/token/ERC20/SafeERC20.sol";

interface Swap {
    function swapExactTokensForTokens(
        uint256,
        uint256,
        address[] calldata,
        address,
        uint256
    ) external;
    function getAmountsOut(uint amountIn, address[] memory path) external view returns (uint[] memory amounts);
}

interface Pair {
    function getReserves() external view returns (
        uint112,
        uint112,
        uint32
    );
}



interface ICurveFi {
    function calc_withdraw_one_coin(uint256, int128) external view returns(uint256);
    function remove_liquidity_one_coin(uint256, int128, uint256) external;
}

interface IVoterProxy {
    function lock() external;
}

interface IyveCRV {
    function claimable(address) external view returns(uint256);
    function supplyIndex(address) external view returns(uint256);
    function balanceOf(address) external view returns(uint256);
    function index() external view returns(uint256);
    function claim() external;
    function depositAll() external;
}

library UniswapV2Library {
    using SafeMath for uint;
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        uint amountInWithFee = amountIn.mul(997);
        uint numerator = amountInWithFee.mul(reserveOut);
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        amountOut = numerator / denominator;
    }
}

contract Strategy is BaseStrategy {
    using SafeERC20 for IERC20;
    using Address for address;
    using SafeMath for uint256;

    address public constant proxy          = address(0x9a165622a744C20E3B2CB443AeD98110a33a231b);
    address public constant crv            = address(0xD533a949740bb3306d119CC777fa900bA034cd52);
    address public constant yveCrv         = address(0xc5bDdf9843308380375a611c18B50Fb9341f502A);
    address public constant usdc           = address(0xA0b86991c6218b36c1d19D4a2e9Eb0cE3606eB48);
    address public constant crv3           = address(0x6c3F90f043a72FA612cbac8115EE7e52BDe6E490);
    address public constant crv3Pool       = address(0xbEbc44782C7dB0a1A60Cb6fe97d0b483032FF1C7);
    address public constant weth           = address(0xC02aaA39b223FE8D0A0e5C4F27eAD9083C756Cc2);
    address public constant sushiswap      = address(0xd9e1cE17f2641f24aE83637ab66a2cca9C378B9F);
    address public constant ethCrvPair     = address(0x58Dc5a51fE44589BEb22E8CE67720B5BC5378009); // Sushi
    address public constant ethYveCrvPair  = address(0x10B47177E92Ef9D5C6059055d92DdF6290848991); // Sushi
    address public constant ethUsdcPair    = address(0x397FF1542f962076d0BFE58eA045FfA2d347ACa0);

    uint256 public constant DENOMINATOR = 1000;
    // Configurable preference for locking CRV in vault vs market-buying yveCRV. Buy only when yveCRV price becomes > 3% price of CRV
    uint256 public vaultBuffer          = 30;

    constructor(address _vault) public BaseStrategy(_vault) {
        // You can set these parameters on deployment to whatever you want
        // maxReportDelay = 6300;
        // profitFactor = 100;
        // debtThreshold = 0;
        IERC20(crv).safeApprove(address(want), type(uint256).max);
        IERC20(usdc).safeApprove(sushiswap, type(uint256).max);
    }

    function name() external view override returns (string memory) {
        return "StrategyYearnVECRV";
    }

    function estimatedTotalAssets() public view override returns (uint256) {
        uint256 _totalAssets = want.balanceOf(address(this));
        uint256 claimable = getClaimable3Crv();
        if(claimable > 0){
            uint256 stable = quoteWithdrawFromCrv(claimable); // Calculate withdrawal amount
            if(stable > 0){ // Quote will revert if amount is < 1
                uint256 estveCrv = quote(usdc, address(want), stable);
                _totalAssets = _totalAssets.add(estveCrv);
            }
        }
        return _totalAssets;
    }

    function prepareReturn(uint256 _debtOutstanding)
        internal
        override
        returns (
            uint256 _profit,
            uint256 _loss,
            uint256 _debtPayment
        )
    {
        if (_debtOutstanding > 0) {
            (_debtPayment, _loss) = liquidatePosition(_debtOutstanding);
        }

        // Figure out how much want we have
        uint256 claimable = getClaimable3Crv();
        claimable = claimable > 0 ? claimable : IERC20(crv3).balanceOf(address(this)); // We do this to make testing harvest easier
        if (claimable > 0) {
            IyveCRV(address(want)).claim();
            withdrawFromCrv(); // Convert 3crv to USDC
            uint256 usdcBalance = IERC20(usdc).balanceOf(address(this));
            if(usdcBalance > 0){
                // Aquire yveCRV either via mint or market-buy
                if(shouldMint(usdcBalance)){
                    swap(usdc, crv, usdcBalance);
                    deposityveCRV();
                }
                else{
                    swap(usdc, yveCrv, usdcBalance);
                }
            }
        }
    }

    // Here we lock curve in the voter contract
    function adjustPosition(uint256 _debtOutstanding) internal override {
        IVoterProxy(proxy).lock();
    }

    function liquidatePosition(uint256 _amountNeeded)
        internal
        override
        returns (uint256 _liquidatedAmount, uint256 _loss)
    {
        uint256 totalAssets = want.balanceOf(address(this));
        if (_amountNeeded > totalAssets) {
            _liquidatedAmount = totalAssets;
            _loss = _amountNeeded.sub(totalAssets);
        } else {
            _liquidatedAmount = _amountNeeded;
        }
    }

    // NOTE: Can override `tendTrigger` and `harvestTrigger` if necessary

    function prepareMigration(address _newStrategy) internal override {
        uint256 balance3crv = IERC20(crv3).balanceOf(address(this));
        uint256 balanceYveCrv = IERC20(yveCrv).balanceOf(address(this));
        if(balance3crv > 0){
            IERC20(crv3).safeTransfer(_newStrategy, balance3crv);
        }
        if(balanceYveCrv > 0){
            IERC20(yveCrv).safeTransfer(_newStrategy, balanceYveCrv);
        }
        return;
    }

    // Here we determine if better to market-buy yveCRV or mint it with the vault
    function shouldMint(uint256 _amountIn) internal view returns (bool) {
        // Using reserve ratios of swap pairs will allow us to compare CRV vs yveCRV price
        // Get reserves for all 3 pairs to be used. This should be a cheaper operation than multiple getAmountsOut calls
        Pair pair = Pair(ethUsdcPair);
        (uint256 reserveUsdc, uint256 wethU, ) = pair.getReserves();
        pair = Pair(ethCrvPair);
        (uint256 wethC, uint256 reserveCrv, ) = pair.getReserves();
        pair = Pair(ethYveCrvPair);
        (uint256 wethY, uint256 reserveYveCrv, ) = pair.getReserves();

        uint256 projectedWeth = UniswapV2Library.getAmountOut(_amountIn, reserveUsdc, wethU);
        uint256 projectedCrv = UniswapV2Library.getAmountOut(projectedWeth, wethC, reserveCrv);
        uint256 projectedYveCrv = UniswapV2Library.getAmountOut(projectedWeth, wethY, reserveYveCrv);

        // Return true if CRV output plus buffer is better than yveCRV
        return projectedCrv.mul(DENOMINATOR.add(vaultBuffer)).div(DENOMINATOR) > projectedYveCrv;
    }

    function withdrawFromCrv() internal {
        uint256 amount = IERC20(crv3).balanceOf(address(this));
        ICurveFi(crv3Pool).remove_liquidity_one_coin(amount, 1, 0);
    }

    function quoteWithdrawFromCrv(uint256 _amount) internal view returns(uint256) {
        return ICurveFi(crv3Pool).calc_withdraw_one_coin(_amount, 1);
    }

    function quote(address token_in, address token_out, uint256 amount_in) internal view returns (uint256) {
        bool is_weth = token_in == weth || token_out == weth;
        address[] memory path = new address[](is_weth ? 2 : 3);
        path[0] = token_in;
        if (is_weth) {
            path[1] = token_out;
        } else {
            path[1] = weth;
            path[2] = token_out;
        }
        uint256[] memory amounts = Swap(sushiswap).getAmountsOut(amount_in, path);
        return amounts[amounts.length - 1];
    }

    function getClaimable3Crv() public view returns (uint256) {
        IyveCRV YveCrv = IyveCRV(address(want));
        uint256 claimable = YveCrv.claimable(address(this));
        // REVIEW: Can YveCrv.supplyIndex(address(this))) be larger than YveCrv.index()
        // Shouldn't we use safeMath?
        uint256 claimableToAdd = (YveCrv.index().sub(YveCrv.supplyIndex(address(this))))
            .mul(YveCrv.balanceOf(address(this)))
            .div(1e18);
        return claimable.mul(1e18).add(claimableToAdd);
    }

    function swap(address token_in, address token_out, uint amount_in) internal {
        bool is_weth = token_in == weth || token_out == weth;
        address[] memory path = new address[](is_weth ? 2 : 3);
        path[0] = token_in;
        if (is_weth) {
            path[1] = token_out;
        } else {
            path[1] = weth;
            path[2] = token_out;
        }
        Swap(sushiswap).swapExactTokensForTokens(
            amount_in,
            0,
            path,
            address(this),
            now
        );
    }

    function deposityveCRV() internal {
        IyveCRV(address(want)).depositAll();
    }

    function setBuffer(uint256 _newBuffer) external {
        require(msg.sender == governance(), "!Governance");
        require(_newBuffer < DENOMINATOR, "!TooHigh");
        vaultBuffer = _newBuffer;
    }

    // internal helpers
    function protectedTokens()
        internal
        view
        override
        returns (address[] memory)
    {
        address[] memory protected = new address[](3);
        protected[0] = address(want);
        protected[1] = crv3;
        protected[2] = usdc;
        return protected;
    }
}
