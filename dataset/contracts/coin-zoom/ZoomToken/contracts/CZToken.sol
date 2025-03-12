pragma solidity 0.4.24;

import "openzeppelin-solidity/contracts/token/ERC20/ERC20Detailed.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Pausable.sol";
import "openzeppelin-solidity/contracts/ownership/Ownable.sol";
import "openzeppelin-solidity/contracts/token/ERC20/ERC20Burnable.sol";



contract CZToken is ERC20Detailed,ERC20Pausable,Ownable,ERC20Burnable {

  uint256 public INITIAL_SUPPLY = 1000000000 * 10**18; // initial quantity of total_token supply
  /**

    * @dev Constructor that gives all existing tokens to the sender.

    */

    constructor () public ERC20Detailed("CoinZoom", "ZOOM", 18) {

        _mint(msg.sender, INITIAL_SUPPLY);

    }

}
