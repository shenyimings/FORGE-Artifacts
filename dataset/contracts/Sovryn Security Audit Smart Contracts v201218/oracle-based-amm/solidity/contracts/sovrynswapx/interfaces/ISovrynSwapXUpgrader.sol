pragma solidity 0.4.26;

/*
    SovrynSwap X Upgrader interface
*/
contract ISovrynSwapXUpgrader {
	function upgrade(uint16 _version, address[] _reporters) public;
}
