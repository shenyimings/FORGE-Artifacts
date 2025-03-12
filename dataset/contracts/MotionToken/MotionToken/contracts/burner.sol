//SPDX-License-Identifier: UNLICENSED

pragma solidity ^0.8.0;

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/proxy/utils/Initializable.sol";
import "./mock_router/interfaces/IUniswapV2Router02.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
import "hardhat/console.sol";

contract Burner is Ownable{
   IERC20 saitaToken;
   IERC20 motionToken;
   IERC20 usdt;
   IUniswapV2Router02 router;
   address dead = 0x000000000000000000000000000000000000dEaD;
   
   function initialize(IUniswapV2Router02 _router, IERC20 _saitaToken, IERC20 _motionToken, IERC20 _usdt) public {
      router = _router; 
      saitaToken = _saitaToken;
      motionToken = _motionToken;
      usdt = _usdt;
   }
   
   modifier onlyMotion(){
      require(msg.sender==address(motionToken),"Action needed by Motion");
      _;
   }

   function burnSaita() external onlyMotion{
      address[] memory path1 = new address[](2);
            path1[0] = address(motionToken);
            path1[1] = address(saitaToken);
      motionToken.approve(address(router), ~uint(0));
      address[] memory path2 = new address[](2);
      path2[0] = address(usdt);
      path2[1] = address(saitaToken);
      uint balance = motionToken.balanceOf(address(this));
      uint[] memory amountOut = router.getAmountsOut(1000000000,path2);
      console.log("AmountsOut",amountOut[1]);
      console.log("Burner Balance before swap",balance);
      console.log("saita balance before swap ",saitaToken.balanceOf(address(this))); 

      router.swapExactTokensForTokens(balance,0,path1,address(this),block.timestamp+3600);
      // motionToken.transfer(dead,balance);
      console.log("burner balance after swap",motionToken.balanceOf(address(this))); 
      console.log("saita balance after swap",saitaToken.balanceOf(address(this))); 
      uint saitaBalanceBurner = saitaToken.balanceOf(address(this));
      if(balance<amountOut[1]) saitaToken.transfer(dead,saitaBalanceBurner);
      console.log("Burned Saita Amount after motion transaction",saitaToken.balanceOf(dead));
            console.log("saita balance after swap and burn",saitaToken.balanceOf(address(this))); 

   }
   
}