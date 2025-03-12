pragma solidity 0.8.7;

import "@openzeppelin/contracts/access/Ownable.sol";

/**
 * @dev This contract will recieve MATIC tokens from bridge, in case shuttle will be cancelled on root chain. 
 *      Matic tokens can't be send directly to child pool as bridge contract uses `transfer` function to send MATIC and that has gas limit of 2300. 
 *      This contract will temporarily hold funds and on shuttle arrival child pool will withdrawFunds from this contract. During withdrawals, 
 *      `call` is used so funds can be transferred without out of gas issue.  
 *    
 */
contract FundsCollector is Ownable {
    address public childPool;

    modifier onlyPool() {
        require(msg.sender == childPool, "Caller must be child pool");
        _;
    }

    /**
     * @dev This function will be called by child pool on shuttle arrival during root cancellation. 
     *   
     * @param _amount Amount of matic token that will be transferred to child Pool. 
     */
    function withdrawFunds(uint256 _amount) external onlyPool {
        require(_amount > 0, "!amount");

        uint256 balance = address(this).balance;

        require(balance >= _amount, "!enough funds");

        // solium-disable-next-line security/no-call-value
        (bool sent, ) = childPool.call{value: _amount}("");

        require(sent, "Failed to send Ether");
    }

    /**
     * @dev Setter for child Pool address.
     * 
     * @param _childPool Address of child Pool contract. 
     */
    function setChildPool(address _childPool) public onlyOwner {
        childPool = _childPool;
    }

    receive() external payable {}

    fallback() external payable {}
}
