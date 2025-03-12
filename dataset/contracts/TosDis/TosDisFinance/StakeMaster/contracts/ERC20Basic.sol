pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Basic is ERC20 {
    constructor(uint256 total) public ERC20("ERC20Basic", "BSC") {
        _mint(msg.sender, total);
    }
}
