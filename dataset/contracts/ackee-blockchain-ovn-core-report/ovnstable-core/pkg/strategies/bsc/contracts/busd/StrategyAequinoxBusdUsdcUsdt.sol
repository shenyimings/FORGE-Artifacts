// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Aequinox.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";


contract StrategyAequinoxBusdUsdcUsdt is Strategy {

    // --- structs

    struct StrategyParams {
        address busdToken;
        address usdcToken;
        address usdtToken;
        address wBnbToken;
        address aeqToken;
        address lpToken;
        address vault;
        address gauge;
        bytes32 poolIdBusdUsdcUsdt;
        bytes32 poolIdAeqWBnb;
        bytes32 poolIdWBnbBusd;
        address rewardWallet;
        uint256 rewardWalletPercent;
        address balancerMinter;
    }

    // --- params

    IERC20 public busdToken;
    IERC20 public usdcToken;
    IERC20 public usdtToken;
    IERC20 public wBnbToken;
    IERC20 public aeqToken;
    IERC20 public lpToken;

    IVault public vault;
    IGauge public gauge;

    bytes32 public poolIdBusdUsdcUsdt;
    bytes32 public poolIdAeqWBnb;
    bytes32 public poolIdWBnbBusd;

    address public rewardWallet;
    uint256 public rewardWalletPercent;

    uint256 public busdTokenDenominator;
    uint256 public usdcTokenDenominator;
    uint256 public usdtTokenDenominator;
    uint256 public lpTokenDenominator;

    IBalancerMinter public balancerMinter;

    // --- events

    event StrategyUpdatedParams();

    // ---  constructor

    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }

    // --- Setters

    function setParams(StrategyParams calldata params) external onlyAdmin {

        busdToken = IERC20(params.busdToken);
        usdcToken = IERC20(params.usdcToken);
        usdtToken = IERC20(params.usdtToken);
        wBnbToken = IERC20(params.wBnbToken);
        aeqToken = IERC20(params.aeqToken);
        lpToken = IERC20(params.lpToken);

        vault = IVault(params.vault);
        gauge = IGauge(params.gauge);

        poolIdBusdUsdcUsdt = params.poolIdBusdUsdcUsdt;
        poolIdAeqWBnb = params.poolIdAeqWBnb;
        poolIdWBnbBusd = params.poolIdWBnbBusd;

        rewardWallet = params.rewardWallet;
        rewardWalletPercent = params.rewardWalletPercent;

        busdTokenDenominator = 10 ** IERC20Metadata(params.busdToken).decimals();
        usdcTokenDenominator = 10 ** IERC20Metadata(params.usdcToken).decimals();
        usdtTokenDenominator = 10 ** IERC20Metadata(params.usdtToken).decimals();
        lpTokenDenominator = 10 ** IERC20Metadata(params.lpToken).decimals();

        balancerMinter = IBalancerMinter(params.balancerMinter);

        emit StrategyUpdatedParams();
    }

    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(busdToken), "Some token not compatible");

        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = vault.getPoolTokens(poolIdBusdUsdcUsdt);

        IAsset[] memory assets = new IAsset[](3);
        uint256[] memory maxAmountsIn = new uint256[](3);
        uint256[] memory amountsIn = new uint256[](3);
        for (uint256 i; i < 3; i++) {
            assets[i] = IAsset(address(tokens[i]));
            if (tokens[i] == busdToken) {
                maxAmountsIn[i] = _amount;
                amountsIn[i] = _amount;
            } else {
                maxAmountsIn[i] = 0;
                amountsIn[i] = 0;
            }
        }

        // Exact Tokens Join (EXACT_TOKENS_IN_FOR_BPT_OUT) spend all _amount
        uint256 joinKind = 1;
        // minimum LP tokens to receive
        uint256 minimumBPT = 0;
        bytes memory userData = abi.encode(joinKind, amountsIn, minimumBPT);

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest(assets, maxAmountsIn, userData, false);

        // join pool
        busdToken.approve(address(vault), _amount);
        vault.joinPool(poolIdBusdUsdcUsdt, address(this), address(this), request);

        // stake lp
        uint256 lpBalance = lpToken.balanceOf(address(this));
        lpToken.approve(address(gauge), lpBalance);
        gauge.deposit(lpBalance);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busdToken), "Some token not compatible");

        // get amount lp to unstake
        uint256 amountLp = OvnMath.addBasisPoints(_amount, 4) * lpTokenDenominator / _getBusdByLp(lpTokenDenominator);

        // unstake lp
        gauge.withdraw(amountLp);

        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = vault.getPoolTokens(poolIdBusdUsdcUsdt);

        IAsset[] memory assets = new IAsset[](3);
        uint256[] memory minAmountsOut = new uint256[](3);
        for (uint256 i; i < 3; i++) {
            assets[i] = IAsset(address(tokens[i]));
            if (tokens[i] == busdToken) {
                minAmountsOut[i] = _amount;
            } else {
                minAmountsOut[i] = 0;
            }
        }

        // Custom Exit (BPT_IN_FOR_EXACT_TOKENS_OUT) spend all _amount
        uint256 exitKind = 2;
        // maximum LP tokens to spend
        uint256 maxBPTAmountIn = amountLp;
        bytes memory userData = abi.encode(exitKind, minAmountsOut, maxBPTAmountIn);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        // exit pool
        vault.exitPool(poolIdBusdUsdcUsdt, address(this), payable(address(this)), request);

        // stake unused lp back
        uint256 lpBalance = lpToken.balanceOf(address(this));
        lpToken.approve(address(gauge), lpBalance);
        gauge.deposit(lpBalance);

        return busdToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(busdToken), "Some token not compatible");

        // get amount lp to unstake
        uint256 amountLp = gauge.balanceOf(address(this));

        // unstake lp
        gauge.withdraw(amountLp);

        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = vault.getPoolTokens(poolIdBusdUsdcUsdt);

        IAsset[] memory assets = new IAsset[](3);
        uint256[] memory minAmountsOut = new uint256[](3);
        for (uint256 i; i < 3; i++) {
            assets[i] = IAsset(address(tokens[i]));
            if (tokens[i] == busdToken) {
                minAmountsOut[i] = OvnMath.subBasisPoints(_getBusdByLp(amountLp), 4);
            } else {
                minAmountsOut[i] = 0;
            }
        }

        // Single Asset Exit (EXACT_BPT_IN_FOR_ONE_TOKEN_OUT) spend all LP tokens
        uint256 exitKind = 0;
        // BUSD index in pool
        uint256 exitTokenIndex = 2;
        bytes memory userData = abi.encode(exitKind, amountLp, exitTokenIndex);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        // exit pool
        vault.exitPool(poolIdBusdUsdcUsdt, address(this), payable(address(this)), request);

        return busdToken.balanceOf(address(this));
    }

    function netAssetValue() external view override returns (uint256) {
        return _totalValue();
    }

    function liquidationValue() external view override returns (uint256) {
        return _totalValue();
    }

    function _totalValue() internal view returns (uint256) {
        return 0;
    }

    function _claimRewards(address _to) internal override returns (uint256) {

        // claim rewards
        uint256 lpBalance = gauge.balanceOf(address(this));
        if (lpBalance > 0) {
            balancerMinter.mint(address(gauge));
        }

        // sell rewards
        uint256 totalBusd;

        uint256 aeqBalance = aeqToken.balanceOf(address(this));
        if (aeqBalance > 0) {
            // transfer to rewardWallet
            uint256 rewardBalance = aeqBalance * rewardWalletPercent / 1e4;
            aeqToken.transfer(rewardWallet, rewardBalance);

            // sell rest tokens
            uint256 toBalance = aeqBalance - rewardBalance;
            uint256 aeqBusd = AequinoxLibrary.batchSwap(
                vault,
                IVault.SwapKind.GIVEN_IN,
                aeqToken,
                wBnbToken,
                busdToken,
                poolIdAeqWBnb,
                poolIdWBnbBusd,
                toBalance,
                address(this),
                address(this)
            );

            totalBusd += aeqBusd;
        }

        if (totalBusd > 0) {
            busdToken.transfer(_to, totalBusd);
        }

        return totalBusd;
    }

    function _getBusdByLp(uint256 lpBalance) internal returns (uint256) {
        uint256 lpTotalSupply = lpToken.totalSupply();
        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = vault.getPoolTokens(poolIdBusdUsdcUsdt);

        uint256 totalBalanceBusd;
        for (uint256 i; i < 3; i++) {
            uint256 tokenBalance = balances[i] * lpBalance / lpTotalSupply;
            if (tokens[i] == usdtToken) {
                totalBalanceBusd += AequinoxLibrary.queryBatchSwap(
                    vault,
                    IVault.SwapKind.GIVEN_IN,
                    tokens[i],
                    busdToken,
                    poolIdBusdUsdcUsdt,
                    tokenBalance,
                    address(this),
                    address(this)
                );
            } else if (tokens[i] == usdcToken) {
                totalBalanceBusd += AequinoxLibrary.queryBatchSwap(
                    vault,
                    IVault.SwapKind.GIVEN_IN,
                    tokens[i],
                    busdToken,
                    poolIdBusdUsdcUsdt,
                    tokenBalance,
                    address(this),
                    address(this)
                );
            } else if (tokens[i] == busdToken) {
                totalBalanceBusd += tokenBalance;
            }
        }

        return totalBalanceBusd;
    }

}
