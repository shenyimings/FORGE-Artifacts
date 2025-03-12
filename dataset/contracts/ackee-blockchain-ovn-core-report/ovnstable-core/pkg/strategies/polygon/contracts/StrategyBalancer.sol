// SPDX-License-Identifier: MIT
pragma solidity >=0.8.0 <0.9.0;

import "@overnight-contracts/core/contracts/Strategy.sol";
import "@overnight-contracts/connectors/contracts/stuff/Balancer.sol";
import "@overnight-contracts/connectors/contracts/stuff/UniswapV2.sol";
import "@overnight-contracts/common/contracts/libraries/OvnMath.sol";

contract StrategyBalancer is Strategy, BalancerExchange, UniswapV2Exchange {

    IERC20 public usdcToken;
    IERC20 public bpspTUsdToken;
    IERC20 public balToken;
    IERC20 public wmaticToken;
    IERC20 public tusdToken;

    uint256 public usdcTokenDenominator;
    uint256 public bpspTUsdTokenDenominator;
    uint256 public balTokenDenominator;
    uint256 public wmaticTokenDenominator;
    uint256 public tusdTokenDenominator;

    IVault public balancerVault;

    bytes32 public balancerPoolId1;
    bytes32 public balancerPoolId2;

    MerkleOrchard public merkleOrchard;

    address public distributorBal;
    address public distributorWMatic;
    address public distributorTUsd;

    // Not using
    uint256 public distributionId;

    uint256 public distributionIdBal;
    uint256 public distributionIdWMatic;
    uint256 public distributionIdTUsd;

    uint256 public claimedBalanceBal;
    uint256 public claimedBalanceWMatic;
    uint256 public claimedBalanceTUsd;

    bytes32[] public merkleProofBal;
    bytes32[] public merkleProofWMatic;
    bytes32[] public merkleProofTUsd;


    // --- events

    event StrategyBalancerUpdatedTokens(address usdcToken, address bpspTUsdToken, address balToken, address wmaticToken,
        address tusdToken, uint256 usdcTokenDenominator, uint256 bpspTUsdTokenDenominator,uint256 balTokenDenominator,
        uint256 wmaticTokenDenominator, uint256 tusdTokenDenominator);

    event StrategyBalancerUpdatedParams(address balancerVault, address uniswapRouter, bytes32 balancerPoolId1,
        bytes32 balancerPoolId2, address merkleOrchard);

    event StrategyBalancerClaimingParamsUpdated(
        address distributorBal, address distributorWMatic, address distributorTUsd,
        uint256 distributionIdBal, uint256 distributionIdWMatic, uint256 distributionIdTUsd,
        uint256 claimedBalanceBal, uint256 claimedBalanceWMatic, uint256 claimedBalanceTUsd,
        bytes32[] merkleProofBal, bytes32[] merkleProofWMatic, bytes32[] merkleProofTUsd);


    /// @custom:oz-upgrades-unsafe-allow constructor
    constructor() initializer {}

    function initialize() initializer public {
        __Strategy_init();
    }


    // --- Setters

    function setTokens(
        address _usdcToken,
        address _bpspTUsdToken,
        address _balToken,
        address _wmaticToken,
        address _tusdToken
    ) external onlyAdmin {

        require(_usdcToken != address(0), "Zero address not allowed");
        require(_bpspTUsdToken != address(0), "Zero address not allowed");
        require(_balToken != address(0), "Zero address not allowed");
        require(_wmaticToken != address(0), "Zero address not allowed");
        require(_tusdToken != address(0), "Zero address not allowed");

        usdcToken = IERC20(_usdcToken);
        bpspTUsdToken = IERC20(_bpspTUsdToken);
        balToken = IERC20(_balToken);
        wmaticToken = IERC20(_wmaticToken);
        tusdToken = IERC20(_tusdToken);

        usdcTokenDenominator = 10 ** IERC20Metadata(_usdcToken).decimals();
        bpspTUsdTokenDenominator = 10 ** IERC20Metadata(_bpspTUsdToken).decimals();
        balTokenDenominator = 10 ** IERC20Metadata(_balToken).decimals();
        wmaticTokenDenominator = 10 ** IERC20Metadata(_wmaticToken).decimals();
        tusdTokenDenominator = 10 ** IERC20Metadata(_tusdToken).decimals();

        emit StrategyBalancerUpdatedTokens(_usdcToken, _bpspTUsdToken, _balToken, _wmaticToken, _tusdToken,
            usdcTokenDenominator, bpspTUsdTokenDenominator, balTokenDenominator, wmaticTokenDenominator, tusdTokenDenominator);
    }

    function setParams(
        address _balancerVault,
        address _uniswapRouter,
        bytes32 _balancerPoolId1,
        bytes32 _balancerPoolId2,
        address _merkleOrchard
    ) external onlyAdmin {

        require(_balancerVault != address(0), "Zero address not allowed");
        require(_uniswapRouter != address(0), "Zero address not allowed");
        require(_balancerPoolId1 != "", "Empty pool id not allowed");
        require(_balancerPoolId2 != "", "Empty pool id not allowed");
        require(_merkleOrchard != address(0), "Zero address not allowed");

        setBalancerVault(_balancerVault);
        _setUniswapRouter(_uniswapRouter);

        balancerVault = IVault(_balancerVault);
        balancerPoolId1 = _balancerPoolId1;
        balancerPoolId2 = _balancerPoolId2;
        merkleOrchard = MerkleOrchard(_merkleOrchard);

        emit StrategyBalancerUpdatedParams(_balancerVault, _uniswapRouter, _balancerPoolId1, _balancerPoolId2, _merkleOrchard);
    }

    function setClaimingParams(
        address _distributorBal,
        address _distributorWMatic,
        address _distributorTUsd,
        uint256 _distributionIdBal,
        uint256 _distributionIdWMatic,
        uint256 _distributionIdTUsd,
        uint256 _claimedBalanceBal,
        uint256 _claimedBalanceWMatic,
        uint256 _claimedBalanceTUsd,
        bytes32[] memory _merkleProofBal,
        bytes32[] memory _merkleProofWMatic,
        bytes32[] memory _merkleProofTUsd
    ) external onlyAdmin {

        distributorBal = _distributorBal;
        distributorWMatic = _distributorWMatic;
        distributorTUsd = _distributorTUsd;
        distributionIdBal = _distributionIdBal;
        distributionIdWMatic = _distributionIdWMatic;
        distributionIdTUsd = _distributionIdTUsd;
        claimedBalanceBal = _claimedBalanceBal;
        claimedBalanceWMatic = _claimedBalanceWMatic;
        claimedBalanceTUsd = _claimedBalanceTUsd;
        merkleProofBal = _merkleProofBal;
        merkleProofWMatic = _merkleProofWMatic;
        merkleProofTUsd = _merkleProofTUsd;

        emit StrategyBalancerClaimingParamsUpdated(
            _distributorBal, _distributorWMatic, _distributorTUsd,
            _distributionIdBal, _distributionIdWMatic, _distributionIdTUsd,
            _claimedBalanceBal, _claimedBalanceWMatic, _claimedBalanceTUsd,
            _merkleProofBal, _merkleProofWMatic, _merkleProofTUsd);
    }


    // --- logic

    function _stake(
        address _asset,
        uint256 _amount
    ) internal override {

        require(_asset == address(usdcToken), "Some token not compatible");

        usdcToken.approve(address(balancerVault), _amount);

        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balancerVault.getPoolTokens(balancerPoolId1);

        IAsset[] memory assets = new IAsset[](4);
        uint256[] memory maxAmountsIn = new uint256[](4);
        uint256[] memory amountsIn = new uint256[](4);
        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
            if (tokens[i] == usdcToken) {
                maxAmountsIn[i] = _amount;
                amountsIn[i] = _amount;
            } else {
                maxAmountsIn[i] = 0;
                amountsIn[i] = 0;
            }
        }

        uint256 joinKind = 1;
        uint256 minimumBPT = 0;
        bytes memory userData = abi.encode(joinKind, amountsIn, minimumBPT);

        IVault.JoinPoolRequest memory request = IVault.JoinPoolRequest(assets, maxAmountsIn, userData, false);

        balancerVault.joinPool(balancerPoolId1, address(this), address(this), request);
    }

    function _unstake(
        address _asset,
        uint256 _amount,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balancerVault.getPoolTokens(balancerPoolId1);

        IAsset[] memory assets = new IAsset[](4);
        uint256[] memory minAmountsOut = new uint256[](4);
        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
            if (tokens[i] == usdcToken) {
                //TODO: Balancer. FIX if big slippage
                minAmountsOut[i] = _amount * 99 / 100;
            } else {
                minAmountsOut[i] = 0;
            }
        }

        uint256 exitKind = 0;
        uint256 exitTokenIndex = 0;
        // 18 = 18 + 6 - 6
        uint256 amountBpspTUsd = bpspTUsdTokenDenominator * _amount / _getBpspTUsdSellPrice(bpspTUsdTokenDenominator);
        bytes memory userData = abi.encode(exitKind, amountBpspTUsd, exitTokenIndex);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        balancerVault.exitPool(balancerPoolId1, address(this), payable(address(this)), request);

        return usdcToken.balanceOf(address(this));
    }

    function _unstakeFull(
        address _asset,
        address _beneficiary
    ) internal override returns (uint256) {

        require(_asset == address(usdcToken), "Some token not compatible");

        uint256 amountBpspTUsd = bpspTUsdToken.balanceOf(address(this));
        uint256 amountUsdc = _getBpspTUsdSellPrice(amountBpspTUsd);

        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balancerVault.getPoolTokens(balancerPoolId1);

        IAsset[] memory assets = new IAsset[](4);
        uint256[] memory minAmountsOut = new uint256[](4);
        for (uint256 i; i < tokens.length; i++) {
            assets[i] = IAsset(address(tokens[i]));
            if (tokens[i] == usdcToken) {
                //TODO: Balancer. FIX if big slippage
                minAmountsOut[i] = amountUsdc * 99 / 100;
            } else {
                minAmountsOut[i] = 0;
            }
        }

        uint256 exitKind = 0;
        uint256 exitTokenIndex = 0;
        bytes memory userData = abi.encode(exitKind, amountBpspTUsd, exitTokenIndex);

        IVault.ExitPoolRequest memory request = IVault.ExitPoolRequest(assets, minAmountsOut, userData, false);

        balancerVault.exitPool(balancerPoolId1, address(this), payable(address(this)), request);

        return usdcToken.balanceOf(address(this));
    }

    function netAssetValue() external override view returns (uint256) {
        uint256 balance = bpspTUsdToken.balanceOf(address(this));
        if (balance == 0) {
            return 0;
        }
        return _getBpspTUsdBuyPrice(balance);
    }

    function liquidationValue() external override view returns (uint256) {
        uint256 balance = bpspTUsdToken.balanceOf(address(this));
        if (balance == 0) {
            return 0;
        }
        return _getBpspTUsdSellPrice(balance);
    }

    function _getBpspTUsdBuyPrice(uint256 balanceBpspTUsd) internal view returns (uint256) {
        uint256 totalSupply = bpspTUsdToken.totalSupply();

        uint256 totalBalanceUsdc;
        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balancerVault.getPoolTokens(balancerPoolId1);
        for (uint256 i; i < tokens.length; i++) {
            uint256 tokenBalance = balances[i] * balanceBpspTUsd / totalSupply;
            if (tokens[i] != usdcToken) {
                totalBalanceUsdc += onSwap(balancerPoolId1, IVault.SwapKind.GIVEN_OUT, usdcToken, tokens[i], tokenBalance);
            } else {
                totalBalanceUsdc += tokenBalance;
            }
        }

        return totalBalanceUsdc;
    }

    function _getBpspTUsdSellPrice(uint256 balanceBpspTUsd) internal view returns (uint256) {
        uint256 totalSupply = bpspTUsdToken.totalSupply();

        uint256 totalBalanceUsdc;
        (IERC20[] memory tokens, uint256[] memory balances, uint256 lastChangeBlock) = balancerVault.getPoolTokens(balancerPoolId1);
        for (uint256 i; i < tokens.length; i++) {
            uint256 tokenBalance = balances[i] * balanceBpspTUsd / totalSupply;
            if (tokens[i] != usdcToken) {
                totalBalanceUsdc += onSwap(balancerPoolId1, IVault.SwapKind.GIVEN_IN, tokens[i], usdcToken, tokenBalance);
            } else {
                totalBalanceUsdc += tokenBalance;
            }
        }

        return totalBalanceUsdc;
    }

    //TODO: Make call once week. Maybe make call with setting new params for claiming
    function _claimRewards(address _to) internal override returns (uint256) {

        _claimRewardsBalancer();

        uint256 totalUsdc;

        uint256 balBalance = balToken.balanceOf(address(this));
        if (balBalance > 0) {
            uint256 balUsdc = swap(balancerPoolId2, IVault.SwapKind.GIVEN_IN, IAsset(address(balToken)),
                IAsset(address(usdcToken)), address(this), address(this), balBalance);
            totalUsdc += balUsdc;
        }

        uint256 wmaticBalance = wmaticToken.balanceOf(address(this));
        if (wmaticBalance > 0) {
            uint256 wmaticUsdc = swap(balancerPoolId2, IVault.SwapKind.GIVEN_IN, IAsset(address(wmaticToken)),
                IAsset(address(usdcToken)), address(this), address(this), wmaticBalance);
            totalUsdc += wmaticUsdc;
        }

        uint256 tusdBalance = tusdToken.balanceOf(address(this));
        if (tusdBalance > 0) {
            uint256 tusdUsdc = swap(balancerPoolId1, IVault.SwapKind.GIVEN_IN, IAsset(address(tusdToken)),
                IAsset(address(usdcToken)), address(this), address(this), tusdBalance);
            totalUsdc += tusdUsdc;
        }

        usdcToken.transfer(_to, usdcToken.balanceOf(address(this)));

        return totalUsdc;
    }

    function _claimRewardsBalancer() internal {

        uint8 size;
        if (claimedBalanceBal > 0) {
            size++;
        }
        if (claimedBalanceWMatic > 0) {
            size++;
        }
        if (claimedBalanceTUsd > 0) {
            size++;
        }

        if (size == 0) {
            return;
        }

        uint8 i;
        MerkleOrchard.Claim[] memory claims = new MerkleOrchard.Claim[](size);
        IERC20[] memory tokens = new IERC20[](size);

        if (claimedBalanceBal > 0) {
            MerkleOrchard.Claim memory claimBal = MerkleOrchard.Claim(
                distributionIdBal,
                claimedBalanceBal,
                distributorBal,
                i,
                merkleProofBal);
            claims[i] = claimBal;
            tokens[i] = balToken;
            i++;
        }

        if (claimedBalanceWMatic > 0) {
            MerkleOrchard.Claim memory claimWMatic = MerkleOrchard.Claim(
                distributionIdWMatic,
                claimedBalanceWMatic,
                distributorWMatic,
                i,
                merkleProofWMatic);
            claims[i] = claimWMatic;
            tokens[i] = wmaticToken;
            i++;
        }

        if (claimedBalanceTUsd > 0) {
            MerkleOrchard.Claim memory claimTUsd = MerkleOrchard.Claim(
                distributionIdTUsd,
                claimedBalanceTUsd,
                distributorTUsd,
                i,
                merkleProofTUsd);
            claims[i] = claimTUsd;
            tokens[i] = tusdToken;
        }

        merkleOrchard.claimDistributions(address(this), claims, tokens);

        // set 0 for not spamming claiming
        claimedBalanceBal = 0;
        claimedBalanceWMatic = 0;
        claimedBalanceTUsd = 0;

    }

}
