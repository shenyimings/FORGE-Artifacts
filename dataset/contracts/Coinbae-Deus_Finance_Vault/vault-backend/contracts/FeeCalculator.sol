//Be name khoda

pragma solidity >=0.6.0 <0.8.0;

import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/math/SafeMath.sol";
import "https://github.com/OpenZeppelin/openzeppelin-contracts/blob/master/contracts/access/Ownable.sol";

contract FeeCalculator is Ownable{

	using SafeMath for uint256;

	uint256 public coefficient;
	uint256 public scale = 1e18;
	uint256 public constantFee;
	mapping (address => bool) public zeroFeeAddresses;

	constructor(uint256 _coefficient, uint256 _constantFee) public{
		coefficient = _coefficient;
		constantFee = _constantFee;
	}

	function setAddressFeeState(address _address, bool feeState) public onlyOwner{
		zeroFeeAddresses[_address] = feeState;
	}

	function changeFee (uint256 _coefficient, uint256 _constantFee, address stakingAddress) public onlyOwner{
        coefficient = _coefficient;
		constantFee = _constantFee;
		zeroFeeAddresses[stakingAddress] = true;
    }

	function calculateFee(address token, address to, address from, uint256 amount) public view returns (uint256){
		if(zeroFeeAddresses[from] || zeroFeeAddresses[to]){
			return 0;
		}
		return coefficient.mul(amount).div(scale).add(constantFee);
	}

	function calculateTransferFromFee(address token, address to, address from, uint256 amount, address spender) public view returns (uint256){
		if(zeroFeeAddresses[from] || zeroFeeAddresses[to]){
			return 0;
		}
		return coefficient.mul(amount).div(scale).add(constantFee);
	}
}


//Dar panah khoda
