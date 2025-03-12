pragma solidity 0.5.16;

import "../interfaces/IERC20Token.sol";

/**
This is just a mockup for the Liquidity Mining contract in the Sovryn-smart-contracts repository
 */
contract LiquidityMining{
    address rewardToken;
    
    mapping( address => mapping(address => uint)) public userLPBalance;

    constructor(address rewardTokenAddress) public{
        rewardToken = rewardTokenAddress;
    }
    /**
	 * @notice deposits pool tokens
	 * @param _poolToken the address of pool token
	 * @param _amount the amount of pool tokens
	 * @param _user the address of user, tokens will be deposited to it or to msg.sender
	 */
	function deposit(address _poolToken, uint256 _amount, address _user) public {
        IERC20Token(_poolToken).transferFrom(address(msg.sender), address(this), _amount);
        userLPBalance[_user][_poolToken] += _amount;
    }

    /**
	 * @notice withdraws pool tokens and transfers reward tokens
	 * @param _poolToken the address of pool token
	 * @param _amount the amount of pool tokens
	 */
	function withdraw(address _poolToken, uint256 _amount, address _user) public {
        require(userLPBalance[_user][_poolToken] >= _amount, "insufficient LP balance");
        userLPBalance[_user][_poolToken] -= _amount;
        IERC20Token(_poolToken).transfer(address(msg.sender), _amount);
        IERC20Token(rewardToken).transfer(address(_user), _amount);
    }
}