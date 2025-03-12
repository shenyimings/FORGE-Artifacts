pragma solidity 0.5.16;

import "./IERC20Token.sol";

/**
This is just a mockup for the Loan Token contract in the Sovryn-smart-contracts repository
 */
contract LoanToken is IERC20Token{
    address public loanTokenAddress;

    /**
	 * @notice lend to the pool
	 * @param _amount the amount of underlying tokens
	 * @param _user the address of user, tokens will be deposited to it or to msg.sender
	 */
	function mint(address _user, uint256 _amount) public  returns (uint256 mintAmount){

    }

    /**
	 * @notice burns pool tokens and transfers underlying tokens
	 * @param _user the address of the receiver
	 * @param _amount the amount of pool tokens
	 */
	function burn(address _user, uint256 _amount) public  returns (uint256 redeemedAmount){

    }
}