// SPDX-License-Identifier: MIT
pragma solidity >=0.8.16;

import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "./uniswapv2/interfaces/IUniswapV2ERC20.sol";
import "./uniswapv2/interfaces/IUniswapV2Pair.sol";
import "./uniswapv2/interfaces/IUniswapV2Factory.sol";

interface IWETH {
    function deposit() external payable;

    function transfer(address to, uint256 value) external returns (bool);

    function withdraw(uint256) external;
}

contract NftBuyer {
    using SafeERC20 for IERC20;

    IUniswapV2Factory public factory;
    address public immutable nftStaking;
    address public immutable nft;
    address public immutable weth;
    uint256 public constant MAX_PERCENT = 10000; // 10000 = 100%

    constructor(
        IUniswapV2Factory _factory,
        address _nftStake,
        address _nft,
        address _weth
    ) {
        require(address(_factory) != address(0));
        require(_nftStake != address(0));
        require(_nft != address(0));
        require(_weth != address(0));

        factory = _factory;
        nft = _nft;
        nftStaking = _nftStake;
        weth = _weth;
    }

    // important to receive ETH
    receive() external payable {}

    function isContract(address account) internal view returns (bool) {
        // This method relies on extcodesize, which returns 0 for contracts in
        // construction, since the code is only stored at the end of the
        // constructor execution.

        uint256 size;
        assembly {
            size := extcodesize(account)
        }
        return size > 0;
    }

    // converts erc20 to WETH -> NFT token
    function convert(address erc20) public {
        require(!isContract(msg.sender), "do not convert from contract");
        if (erc20 == nft) {
            // split proceeds
            _transfer(nft, nftStaking, IERC20(nft).balanceOf(address(this)));
        } else {
            uint256 wethAmount = _toWETH(erc20);
            // Then we convert the WETH to Nft
            _toNFT(wethAmount);
        }
    }

    function convertETH() public {
        IWETH(weth).deposit{ value: address(this).balance }();
    }

    // Converts token passed as an argument to WETH
    function _toWETH(address token) internal returns (uint256) {
        // If the passed token is Nft, don't convert anything
        if (token == nft) {
            uint256 amount = IERC20(token).balanceOf(address(this));
            _transfer(token, nftStaking, amount);
            return 0;
        }
        // If the passed token is WETH, don't convert anything
        if (token == weth) {
            uint256 amount = IERC20(token).balanceOf(address(this));
            _transfer(token, factory.getPair(weth, nft), amount);
            return amount;
        }
        // If the target pair doesn't exist, don't convert anything
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(token, weth));
        if (address(pair) == address(0)) {
            return 0;
        }
        // Choose the correct reserve to swap from
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        address token0 = pair.token0();
        (uint256 reserveIn, uint256 reserveOut) = token0 == token ? (reserve0, reserve1) : (reserve1, reserve0);
        // Calculate information required to swap
        uint256 amountIn = IERC20(token).balanceOf(address(this));
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;
        (uint256 amount0Out, uint256 amount1Out) = token0 == token ? (uint256(0), amountOut) : (amountOut, uint256(0));
        // Swap the token for WETH
        _transfer(token, address(pair), amountIn);
        pair.swap(amount0Out, amount1Out, factory.getPair(weth, nft), new bytes(0));
        return amountOut;
    }

    // Converts WETH to Nft
    function _toNFT(uint256 amountIn) internal {
        IUniswapV2Pair pair = IUniswapV2Pair(factory.getPair(weth, nft));

        // Choose WETH as input token
        (uint256 reserve0, uint256 reserve1, ) = pair.getReserves();
        address token0 = pair.token0();
        (uint256 reserveIn, uint256 reserveOut) = token0 == weth ? (reserve0, reserve1) : (reserve1, reserve0);
        // Calculate information required to swap
        uint256 amountInWithFee = amountIn * 997;
        uint256 numerator = amountInWithFee * reserveOut;
        uint256 denominator = (reserveIn * 1000) + amountInWithFee;
        uint256 amountOut = numerator / denominator;
        (uint256 amount0Out, uint256 amount1Out) = token0 == weth ? (uint256(0), amountOut) : (amountOut, uint256(0));
        // Swap WETH for Nft
        pair.swap(amount0Out, amount1Out, address(this), new bytes(0));

        // split proceeds
        _transfer(nft, nftStaking, IERC20(nft).balanceOf(address(this)));
    }

    function _transfer(
        address token,
        address to,
        uint256 amount
    ) internal {
        IERC20(token).safeTransfer(to, amount);
    }
}
