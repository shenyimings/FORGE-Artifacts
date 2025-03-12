pragma solidity 0.6.12;

import "./libs/IBEP20.sol";
import "./libs/SafeBEP20.sol";
import "./libs/TimeLock.sol";

contract TropicalSwap11 is TimeLock {

    using SafeMath for uint256;
    
    using SafeBEP20 for IBEP20;

    IBEP20 tropicalToken1;
    IBEP20 tropicalToken2;

    function setTropicals(IBEP20 _t1, IBEP20 _t2) public onlyOwner {
        tropicalToken1 = _t1;
        tropicalToken2 = _t2;
    }

    function claim() public {
        uint amount = tropicalToken1.balanceOf(address(msg.sender));
        require(amount >= 0, "Tropical::error: You don't have enough funds");
        tropicalToken1.safeTransferFrom(address(msg.sender), address(this), amount);
        tropicalToken2.safeTransfer(address(msg.sender), amount);
    }

    function balance1() public view returns(uint) {
        return tropicalToken1.balanceOf(address(msg.sender));
    }
} 