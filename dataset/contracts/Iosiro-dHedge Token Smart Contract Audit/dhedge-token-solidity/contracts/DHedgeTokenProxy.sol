pragma solidity ^0.6.0;

import "./AdminUpgradeabilityProxy.sol";

// ---------------------------------------------------------------------
// dHedge DAO Token Proxy - https://dhedge.org
//
// Notes          : This contract is a proxy to the dHedge DAO Token.
//                  It allows upgradeability using CALLDELEGATE pattern (code courtesy of https://openzeppelin.org/).
//                  This address should be accessed with the ABI of the current token delegate contract.
//
// ---------------------------------------------------------------------

contract DHedgeTokenProxy is AdminUpgradeabilityProxy {
    constructor(address _implementation, bytes memory _data)
        public
        payable
        AdminUpgradeabilityProxy(_implementation, msg.sender, _data)
    {}
}
