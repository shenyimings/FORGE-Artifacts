pragma solidity 0.6.6;

// SPDX-License-Identifier: Unlicensed

import "@openzeppelin/contracts/proxy/TransparentUpgradeableProxy.sol";

contract HProxy is TransparentUpgradeableProxy {
    
    /***************************************************************************************
     * An encoded function call can optionally be passed as _data. 
     * For example, the implementation contract init() functions can be called to 
     * initialized the HodlDex and TokenReserve in a constructor-like way.
     * 
     * HodlDex: function init(ITokenReserve _tokenReserve, IERC20 _token, IOracle _oracle)
     * TokenReserve: function init(address dexContract)
     ***************************************************************************************/
    
    constructor(address _logic, address _admin, bytes memory _data) 
        TransparentUpgradeableProxy(_logic, _admin, _data)
        internal 
        payable 
    {
        
    }
}