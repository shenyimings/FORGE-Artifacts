// SPDX-License-Identifier: MIT
pragma solidity 0.8.19;

import "./DustRefunder.sol";
import "./BNum.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

import {Initializable} from "@openzeppelin/contracts-upgradeable/proxy/utils/Initializable.sol";
import {OwnableUpgradeable} from "@openzeppelin/contracts-upgradeable/access/OwnableUpgradeable.sol";

import "../../interfaces/IWETH.sol";
import "../../interfaces/balancer/IWeightedPoolFactory.sol";
import "../../interfaces/radiant/IPoolHelper.sol";

/// @title Balance Pool Helper Contract
/// @author Radpie, completely forked from Radiant
contract DlpBalPoolHelper is IBalancerPoolHelper, Initializable, OwnableUpgradeable, BNum, DustRefunder {
	using SafeERC20 for IERC20;
	using SafeMath for uint256;

	address public inTokenAddr;
	address public outTokenAddr;
	address public wethAddr;
	address public override lpTokenAddr;
	address public vaultAddr;
	bytes32 public poolId;
	IWeightedPoolFactory public poolFactory;
	address public mDLP;

	function __DlpBalPoolHelper_init(
		address _inTokenAddr,
		address _outTokenAddr,
		address _wethAddr,
		address _vault,
		IWeightedPoolFactory _poolFactory,
		address _lpTokenAddr,
		bytes32 _poolId,
		address _mDLP
	) external initializer {
		__Ownable_init();
		inTokenAddr = _inTokenAddr;
		outTokenAddr = _outTokenAddr;
		wethAddr = _wethAddr;
		vaultAddr = _vault;
		poolFactory = _poolFactory;
		lpTokenAddr = _lpTokenAddr;
		poolId = _poolId;
		mDLP = _mDLP;
	}

	function initializePool(string calldata _tokenName, string calldata _tokenSymbol) public {
		require(lpTokenAddr == address(0), "Already initialized");

		(address token0, address token1) = sortTokens(inTokenAddr, outTokenAddr);

		IERC20[] memory tokens = new IERC20[](2);
		tokens[0] = IERC20(token0);
		tokens[1] = IERC20(token1);

		address[] memory rateProviders = new address[](2);
		rateProviders[0] = 0x0000000000000000000000000000000000000000;
		rateProviders[1] = 0x0000000000000000000000000000000000000000;

		uint256 swapFeePercentage = 1000000000000000;

		uint256[] memory weights = new uint256[](2);

		if (token0 == outTokenAddr) {
			weights[0] = 800000000000000000;
			weights[1] = 200000000000000000;
		} else {
			weights[0] = 200000000000000000;
			weights[1] = 800000000000000000;
		}

		lpTokenAddr = poolFactory.create(
			_tokenName,
			_tokenSymbol,
			tokens,
			weights,
			rateProviders,
			swapFeePercentage,
			address(this)
		);

		poolId = IWeightedPool(lpTokenAddr).getPoolId();

		IERC20 outToken = IERC20(outTokenAddr);
		IERC20 inToken = IERC20(inTokenAddr);
		IERC20 lp = IERC20(lpTokenAddr);
		IERC20 weth = IERC20(wethAddr);

		outToken.safeApprove(vaultAddr, type(uint256).max);
		inToken.safeApprove(vaultAddr, type(uint256).max);
		weth.approve(vaultAddr, type(uint256).max);

		IAsset[] memory assets = new IAsset[](2);
		assets[0] = IAsset(token0);
		assets[1] = IAsset(token1);

		uint256 inTokenAmt = inToken.balanceOf(address(this));
		uint256 outTokenAmt = outToken.balanceOf(address(this));

		uint256[] memory maxAmountsIn = new uint256[](2);
		if (token0 == inTokenAddr) {
			maxAmountsIn[0] = inTokenAmt;
			maxAmountsIn[1] = outTokenAmt;
		} else {
			maxAmountsIn[0] = outTokenAmt;
			maxAmountsIn[1] = inTokenAmt;
		}

		IVault.JoinPoolRequest memory inRequest = IVault.JoinPoolRequest(
			assets,
			maxAmountsIn,
			abi.encode(0, maxAmountsIn),
			false
		);
		IVault(vaultAddr).joinPool(poolId, address(this), address(this), inRequest);
		uint256 liquidity = lp.balanceOf(address(this));
		lp.safeTransfer(msg.sender, liquidity);
	}

	/// @dev Return fair reserve amounts given spot reserves, weights, and fair prices.
	/// @param resA Reserve of the first asset
	/// @param resB Reserve of the second asset
	/// @param wA Weight of the first asset
	/// @param wB Weight of the second asset
	/// @param pxA Fair price of the first asset
	/// @param pxB Fair price of the second asset
	function computeFairReserves(
		uint256 resA,
		uint256 resB,
		uint256 wA,
		uint256 wB,
		uint256 pxA,
		uint256 pxB
	) internal pure returns (uint256 fairResA, uint256 fairResB) {
		// NOTE: wA + wB = 1 (normalize weights)
		// constant product = resA^wA * resB^wB
		// constraints:
		// - fairResA^wA * fairResB^wB = constant product
		// - fairResA * pxA / wA = fairResB * pxB / wB
		// Solving equations:
		// --> fairResA^wA * (fairResA * (pxA * wB) / (wA * pxB))^wB = constant product
		// --> fairResA / r1^wB = constant product
		// --> fairResA = resA^wA * resB^wB * r1^wB
		// --> fairResA = resA * (resB/resA)^wB * r1^wB = resA * (r1/r0)^wB
		uint256 r0 = bdiv(resA, resB);
		uint256 r1 = bdiv(bmul(wA, pxB), bmul(wB, pxA));
		// fairResA = resA * (r1 / r0) ^ wB
		// fairResB = resB * (r0 / r1) ^ wA
		if (r0 > r1) {
			uint256 ratio = bdiv(r1, r0);
			fairResA = bmul(resA, bpow(ratio, wB));
			fairResB = bdiv(resB, bpow(ratio, wA));
		} else {
			uint256 ratio = bdiv(r0, r1);
			fairResA = bdiv(resA, bpow(ratio, wB));
			fairResB = bmul(resB, bpow(ratio, wA));
		}
	}

	function getLpPrice(uint256 rdntPriceInEth) public view override returns (uint256 priceInEth) {
		IWeightedPool pool = IWeightedPool(lpTokenAddr);
		(address token0, ) = sortTokens(inTokenAddr, outTokenAddr);
		(uint256 rdntBalance, uint256 wethBalance, ) = getReserves();
		uint256[] memory weights = pool.getNormalizedWeights();

		uint256 rdntWeight;
		uint256 wethWeight;

		if (token0 == outTokenAddr) {
			rdntWeight = weights[0];
			wethWeight = weights[1];
		} else {
			rdntWeight = weights[1];
			wethWeight = weights[0];
		}

		// RDNT in eth, 8 decis
		uint256 pxA = rdntPriceInEth;
		// ETH in eth, 8 decis
		uint256 pxB = 100000000;

		(uint256 fairResA, uint256 fairResB) = computeFairReserves(
			rdntBalance,
			wethBalance,
			rdntWeight,
			wethWeight,
			pxA,
			pxB
		);
		// use fairReserveA and fairReserveB to compute LP token price
		// LP price = (fairResA * pxA + fairResB * pxB) / totalLPSupply
		priceInEth = fairResA.mul(pxA).add(fairResB.mul(pxB)).div(pool.totalSupply());
	}

	function getPrice() public view returns (uint256 priceInEth) {
		(IERC20[] memory tokens, uint256[] memory balances, ) = IVault(vaultAddr).getPoolTokens(poolId);
		uint256 rdntBalance = address(tokens[0]) == outTokenAddr ? balances[0] : balances[1];
		uint256 wethBalance = address(tokens[0]) == outTokenAddr ? balances[1] : balances[0];

		uint256 poolWeight = 4;

		return wethBalance.mul(1e8).div(rdntBalance.div(poolWeight));
	}

	function getReserves() public view override returns (uint256 rdnt, uint256 weth, uint256 lpTokenSupply) {
		IERC20 lpToken = IERC20(lpTokenAddr);

		(IERC20[] memory tokens, uint256[] memory balances, ) = IVault(vaultAddr).getPoolTokens(poolId);

		rdnt = address(tokens[0]) == outTokenAddr ? balances[0] : balances[1];
		weth = address(tokens[0]) == outTokenAddr ? balances[1] : balances[0];

		lpTokenSupply = lpToken.totalSupply().div(1e18);
	}

	function joinPool(uint256 _wethAmt, uint256 _rdntAmt) internal returns (uint256 liquidity) {
		(address token0, address token1) = sortTokens(outTokenAddr, inTokenAddr);
		IAsset[] memory assets = new IAsset[](2);
		assets[0] = IAsset(token0);
		assets[1] = IAsset(token1);

		uint256[] memory maxAmountsIn = new uint256[](2);
		if (token0 == inTokenAddr) {
			maxAmountsIn[0] = _wethAmt;
			maxAmountsIn[1] = _rdntAmt;
		} else {
			maxAmountsIn[0] = _rdntAmt;
			maxAmountsIn[1] = _wethAmt;
		}

		bytes memory userDataEncoded = abi.encode(IWeightedPool.JoinKind.EXACT_TOKENS_IN_FOR_BPT_OUT, maxAmountsIn, 0);
		IVault.JoinPoolRequest memory inRequest = IVault.JoinPoolRequest(assets, maxAmountsIn, userDataEncoded, false);
		IERC20(wethAddr).safeApprove(vaultAddr, _wethAmt);
		IERC20(outTokenAddr).safeApprove(vaultAddr, _rdntAmt);
		IVault(vaultAddr).joinPool(poolId, address(this), address(this), inRequest);

		IERC20 lp = IERC20(lpTokenAddr);
		liquidity = lp.balanceOf(address(this));
	}

	function zapWETH(uint256 amount) public override returns (uint256 liquidity) {
		require(msg.sender == mDLP, "!mDLP");
		IWETH(wethAddr).transferFrom(msg.sender, address(this), amount);
		liquidity = joinPool(amount, 0);
		IERC20 lp = IERC20(lpTokenAddr);
		lp.safeTransfer(msg.sender, liquidity);
		refundDust(outTokenAddr, wethAddr, msg.sender);
	}

	function zapTokens(uint256 _wethAmt, uint256 _rdntAmt) public override returns (uint256 liquidity) {
		require(msg.sender == mDLP, "!mDLP");
		IWETH(wethAddr).transferFrom(msg.sender, address(this), _wethAmt);
		IERC20(outTokenAddr).safeTransferFrom(msg.sender, address(this), _rdntAmt);

		liquidity = joinPool(_wethAmt, _rdntAmt);
		IERC20 lp = IERC20(lpTokenAddr);
		lp.safeTransfer(msg.sender, liquidity);

		refundDust(outTokenAddr, wethAddr, msg.sender);
	}

	function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
		require(tokenA != tokenB, "BalancerZap: IDENTICAL_ADDRESSES");
		(token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
		require(token0 != address(0), "BalancerZap: ZERO_ADDRESS");
	}

	function quoteFromToken(uint256 tokenAmount) public view override returns (uint256 optimalWETHAmount) {
		uint256 rdntPriceInEth = getPrice();
		uint256 p1 = rdntPriceInEth.mul(1e10);
		uint256 ethRequiredBeforeWeight = tokenAmount.mul(p1).div(1e18);
		optimalWETHAmount = ethRequiredBeforeWeight.div(4);
	}

	function swap(
		uint256 _amount,
		address _tokenInAddress,
		address _tokenOutAddress,
		address _lpAddr
	) internal returns (uint256 amountOut) {
		IAsset tokenInAddress = IAsset(_tokenInAddress);
		IAsset tokenOutAddress = IAsset(_tokenOutAddress);

		bytes32 _poolId = IWeightedPool(_lpAddr).getPoolId();

		bytes memory userDataEncoded = abi.encode(); //https://dev.balancer.fi/helpers/encoding
		IVault.SingleSwap memory singleSwapRequest = IVault.SingleSwap(
			_poolId,
			IVault.SwapKind.GIVEN_IN,
			tokenInAddress,
			tokenOutAddress,
			_amount,
			userDataEncoded
		);
		IVault.FundManagement memory fundManagementRequest = IVault.FundManagement(
			address(this),
			false,
			payable(address(this)),
			false
		);

		uint256 limit = 0;

		amountOut = IVault(vaultAddr).swap(
			singleSwapRequest,
			fundManagementRequest,
			limit,
			(block.timestamp + 3 minutes)
		);
	}

	function setmDLP(address _mDLP) external onlyOwner {
		mDLP = _mDLP;
	}

	function getSwapFeePercentage() public onlyOwner returns (uint256 fee) {
		IWeightedPool pool = IWeightedPool(lpTokenAddr);
		fee = pool.getSwapFeePercentage();
	}

	function setSwapFeePercentage(uint256 _fee) public onlyOwner {
		IWeightedPool pool = IWeightedPool(lpTokenAddr);
		pool.setSwapFeePercentage(_fee);
	}
}