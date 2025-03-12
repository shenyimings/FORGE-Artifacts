//Be name khoda

pragma solidity >=0.6.0 <0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

interface BalancerPool {
	function gulp (address token) external;
}

contract TransferController is Ownable{

	address public token;
	address public balancerPool;
	constructor(address _token, address _balancerPool) public{
		token = _token;
		balancerPool = BalancerPool(_balancerPool);
	}

	function afterTokenTransfer(address from, address to, uint256 value) public{
		if (from == balancerPool){
			balancerPool.gulp(token);
		}
		if (to == balancerPool){
			balancerPool.gulp(token);
		}
	}
}

//Dar panah khoda
