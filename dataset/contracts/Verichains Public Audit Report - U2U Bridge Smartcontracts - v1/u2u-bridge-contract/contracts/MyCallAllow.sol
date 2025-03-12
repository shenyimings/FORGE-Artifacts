// SPDX-License-Identifier: UNLICENSED
pragma solidity ^0.8.9;

// Uncomment this line to use console.log
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import "@openzeppelin/contracts/access/Ownable.sol";

interface Bridge{
   
    function setTokenAllow(address token, bool flag) external;

    function setTokenMod(address token,address account,bool flag ) external;
}

contract MyCallAllow is Ownable  {

    

    function callAllow(address[] memory token, address[] memory modAdd ,address bridgeLock,bool flag)  external onlyOwner {

        Bridge bridge = Bridge(bridgeLock);

        for(uint i=0;i<token.length;i++){

                    bridge.setTokenAllow(token[i],flag);

            for(uint j=0;j< modAdd.length;j++){
                
                /** */               

                    bridge.setTokenMod(token[i],modAdd[j],flag);
                    

                /** */
            }
        }
        

    }

}