//SPDX-License-Identifier: MIT
pragma solidity ^0.6.12;

import "../PancakeSwap/IPancakeV2Factory.sol";
import "../PancakeSwap/IPancakeV2Pair.sol";
import "../PancakeSwap/IPancakeV2Router01.sol";
import "../PancakeSwap/IPancakeV2Router02.sol";

import "@openzeppelin/contracts/math/SafeMath.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

contract ICOContract is Ownable {
    using SafeMath for uint;

    IERC20 frxToken;
    IPancakeV2Router02 public pancakeV2Router;
    address public pancakeV2Pair;

    uint public price = 1 * (10**17); // 0.1 BNB per token as of now
    uint public constant MIN_PURCHASE = 1 * (10**8); // Minimum purchase 1 coin

    constructor (address _frxToken) public {
        frxToken = IERC20(_frxToken);

        // IPancakeV2Router02 _pancakeV2Router = IPancakeV2Router02(0x05fF2B0DB69458A0750badebc4f9e13aDd608C7F); // Mainnet
        IPancakeV2Router02 _pancakeV2Router = IPancakeV2Router02(0xD99D1c33F9fC3444f8101754aBC46c52416550D1); // testnet // https://twitter.com/PancakeSwap/status/1369547285160370182

        // Create a uniswap pair for frxToken
        pancakeV2Pair = IPancakeV2Factory(_pancakeV2Router.factory())
        .createPair(_frxToken, _pancakeV2Router.WETH());

        // set the rest of the contract variables
        pancakeV2Router = _pancakeV2Router;
    }

    function addLiquidity(uint256 tokenAmount, uint256 ethAmount) private {
        // approve token transfer to cover all possible scenarios
        frxToken.approve(address(pancakeV2Router), tokenAmount);

        // add the liquidity
        pancakeV2Router.addLiquidityETH{value: ethAmount}(
            address(this),
            tokenAmount,
            0, // slippage is unavoidable
            0, // slippage is unavoidable
            address(this),
            block.timestamp
        );
    }

    function updatePrice(uint _newPrice) onlyOwner public {
        price = _newPrice;
    }

    function purchase() public payable {
        require(msg.value > 0);
        uint coinAmount = msg.value.div(price);
        require(coinAmount >= MIN_PURCHASE);
        require(frxToken.balanceOf(address(this)) >= coinAmount.mul(2)); // need to send equivalent amount for liquidity too

        frxToken.transfer(msg.sender, coinAmount); // send coins to user
        addLiquidity(coinAmount, msg.value); // add liquidity to pool
    }

    function recoverTokens(address _tokenAddress, address payable recipient) onlyOwner public {
        if (_tokenAddress == address(0)) {
            recipient.transfer(address(this).balance);
        } else {
            IERC20 token = IERC20(_tokenAddress);
            token.transfer(recipient, token.balanceOf(address(this)));
        }
    }
}
