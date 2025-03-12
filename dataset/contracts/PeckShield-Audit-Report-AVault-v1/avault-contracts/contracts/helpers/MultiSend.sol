// SPDX-License-Identifier: MIT

pragma solidity 0.8.4;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/token/ERC20/IERC20.sol";

contract MultiSend is Ownable{

    function withdraw(address token) external onlyOwner {
        if (token == address(0)) {
            payable(owner()).transfer(address(this).balance);
            return;
        }

        IERC20(token).transfer(owner(), IERC20(token).balanceOf(address(this)));
    }
    
    //onlyOwner, so no need to worry about constructer and reentrancy attack.
    function multiSending(address payable[] calldata addrs, uint amnt) payable external onlyOwner{
        require(addrs.length * amnt <= msg.value, "not enough value");
        
        for (uint i=0; i < addrs.length; i++) {
            if(!isContract(addrs[i])){
                // send the specified amount to the recipient
                payable(addrs[i]).transfer(amnt);
            }
        }
    }
    
    function isContract(address addr) private view returns (bool) {
        uint size;
        assembly { size := extcodesize(addr) }
        return size > 0;
    }
}