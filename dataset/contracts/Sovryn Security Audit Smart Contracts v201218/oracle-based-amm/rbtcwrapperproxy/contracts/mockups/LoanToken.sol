pragma solidity 0.5.16;

import "../interfaces/IERC20Token.sol";

/**
This is just a mockup for the Loan Token contract in the Sovryn-smart-contracts repository
 */
contract LoanToken{
    address public loanTokenAddress;
    
    mapping( address  => uint) public balanceOf;
	mapping( address => mapping( address => uint)) public allowance;

    constructor(address loanToken) public{
        loanTokenAddress = loanToken;
    }
    /**
	 * @notice lend to the pool
	 * @param _amount the amount of underlying tokens
	 * @param _user the address of user, tokens will be deposited to it or to msg.sender
	 */
	function mint(address _user, uint256 _amount) public returns (uint256 mintAmount){
        IERC20Token(loanTokenAddress).transferFrom(address(msg.sender), address(this), _amount);
        balanceOf[_user] += _amount;
        return _amount;
    }

    /**
	 * @notice burns pool tokens and transfers underlying tokens
	 * @param _receiver the address of the receiver
	 * @param _amount the amount of pool tokens
	 */
	function burn(address _receiver, uint256 _amount) public returns (uint256 redeemedAmount){
        require(balanceOf[msg.sender] >= _amount, "insufficient balance");
        balanceOf[msg.sender] -= _amount;
        IERC20Token(loanTokenAddress).transfer(address(_receiver), _amount);
        return _amount;
    }

	/**
	 * @dev allows another account/contract to transfers tokens on behalf of the caller
	 * throws on any error rather then return a false flag to minimize user errors
	 *
	 * also, to minimize the risk of the approve/transferFrom attack vector
	 * (see https://docs.google.com/document/d/1YLPtQxZu1UAvO9cZ1O2RPXBbT0mooh4DYKjA_jp-RLM/), approve has to be called twice
	 * in 2 separate transactions - once to change the allowance to 0 and secondly to change it to the new allowance value
	 *
	 * @param _spender approved address
	 * @param _value   allowance amount
	 *
	 * @return true if the approval was successful, false if it wasn't
	 */
	function approve(address _spender, uint256 _value) public returns (bool success) {
		allowance[msg.sender][_spender] = _value;
		return true;
	}

	/**
	 * @dev transfers tokens to a given address on behalf of another address
	 * throws on any error rather then return a false flag to minimize user errors
	 *
	 * @param _from    source address
	 * @param _to      target address
	 * @param _value   transfer amount
	 *
	 * @return true if the transfer was successful, false if it wasn't
	 */
	function transferFrom(
		address _from,
		address _to,
		uint256 _value
	) public returns (bool success) {
		require(allowance[_from][msg.sender] >= _value);
		allowance[_from][msg.sender] = allowance[_from][msg.sender] - _value;
		balanceOf[_from] = balanceOf[_from] - _value;
		balanceOf[_to] = balanceOf[_to] + _value;
		return true;
	}

	/**
	 * @dev transfers tokens to a given address
	 * throws on any error rather then return a false flag to minimize user errors
	 *
	 * @param _to      target address
	 * @param _value   transfer amount
	 *
	 * @return true if the transfer was successful, false if it wasn't
	 */
	function transfer(address _to, uint256 _value) public returns (bool success) {
		balanceOf[msg.sender] = balanceOf[msg.sender] - _value;
		balanceOf[_to] = balanceOf[_to] + _value;
		return true;
	}
}