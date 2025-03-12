// SPDX-License-Identifier: MIT
pragma solidity 0.6.12;
import "./SafeMath.sol";

library Timer{
    using SafeMath for uint256;
    struct Expire{
        uint256 popTotal;
        uint256 pushTotal;
    }

    struct Timing{
        uint256 from;
        uint256 to;
        uint256 finish;
    }

    function push(Expire storage timer,uint256 quantity) internal{
        timer.pushTotal = timer.pushTotal.add(quantity);
    }

    function pop(Expire storage timer,Timing memory timing,uint256 quantity,uint256 tsp) internal returns(uint256 last){
        last = quantity;
        uint256 balance = expected(timer,timing,tsp);
        if(quantity>0&&balance>0){
            if(quantity>=balance){
                timer.popTotal = timer.popTotal.add(balance);
                last = quantity.sub(balance);
            }else{
                timer.popTotal = timer.popTotal.add(quantity);
                last = 0;
            }
        }
    }

    function expected(Expire storage timer,Timing memory timing,uint256 tsp)internal view returns(uint256){
        uint256 balance = 0;
        if(timer.pushTotal > timer.popTotal && timing.from > 0 && tsp > timing.from){
            if(tsp>timing.to){
                balance = timer.pushTotal.sub(timer.popTotal);
            }else{
                balance = timer.pushTotal.mul(tsp.sub(timing.from)).div(timing.to.sub(timing.from));
                if(timer.popTotal>=balance){
                    balance = 0;
                }else{
                    balance = balance.sub(timer.popTotal);
                }
            }
        }
        return balance;
    }
}