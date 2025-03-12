// SPDX-License-Identifier: MIT

pragma solidity ^0.8.0;

import '@openzeppelin/contracts/utils/Context.sol';
import './IUniswapV2Factory.sol';
import './IUniswapV2Pair.sol';
import './IUniswapV2Router02.sol';

abstract contract SwapAndLiquify is Context {
    IUniswapV2Router02 public immutable uniswapV2Router;
    address public immutable uniswapV2Pair;

    bool private _isInSwapAndLiquify = false;
    bool public isSwapAndLiquifyEnabled = true;

    address payable public swapLeftoversReceiver;

    event SwapAndLiquifySwitched(bool enabled);
    event SwappedAndLiquidated(uint256 tokensSwapped, uint256 ethReceived, uint256 tokensIntoLiquidity);

    modifier lockTheSwap {
        _isInSwapAndLiquify = true;
        _;
        _isInSwapAndLiquify = false;
    }

    constructor(address routerAddress_, address swapLeftoversReceiver_) {
        // Create a Uniswap pair for this new token
        IUniswapV2Router02 _uniswapV2Router = IUniswapV2Router02(routerAddress_);
        uniswapV2Pair = IUniswapV2Factory(_uniswapV2Router.factory()).createPair(
            address(this),
            _uniswapV2Router.WETH()
        );
        uniswapV2Router = _uniswapV2Router;

        // Set given address to be able to receive swap leftovers
        swapLeftoversReceiver = payable(swapLeftoversReceiver_);
    }

    receive() external payable {}

    function isInSwapAndLiquify() internal view returns (bool) {
        return _isInSwapAndLiquify;
    }

    function withdrawSwapLeftovers() external {
        require(_msgSender() == swapLeftoversReceiver, 'Caller is not able to receive swap leftovers');
        swapLeftoversReceiver.transfer(address(this).balance);
    }

    function _switchSwapAndLiquify() internal {
        isSwapAndLiquifyEnabled = !isSwapAndLiquifyEnabled;
        emit SwapAndLiquifySwitched(isSwapAndLiquifyEnabled);
    }

    function _swapAndLiquify(uint256 tokenAmount) internal lockTheSwap {
        uint256 firstHalf = tokenAmount / 2;
        uint256 otherHalf = tokenAmount - firstHalf;

        uint256 balance = address(this).balance;
        _swapTokensForETH(firstHalf);
        uint256 newBalance = address(this).balance;

        _addLiquidity(otherHalf, newBalance - balance);
        emit SwappedAndLiquidated(firstHalf, newBalance, otherHalf);
    }

    function _swapTokensForETH(uint256 tokenAmount) private {
        // generate the Uniswap pair path of token -> weth
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();

        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0, // accept any amount of ETH
            path,
            address(this),
            block.timestamp
        );
    }

    function _addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        uniswapV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }
}
