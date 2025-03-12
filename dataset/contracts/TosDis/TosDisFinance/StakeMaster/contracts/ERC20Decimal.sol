pragma solidity 0.6.12;
import "@openzeppelin/contracts/token/ERC20/ERC20.sol";

contract ERC20Decimal is ERC20 {
    constructor( uint256 totalSupply,
        string memory name,
        string memory symbol,
        uint8 decimal) public ERC20(name, symbol) {
        _setupDecimals(decimal);
        _mint(msg.sender, totalSupply);
    }
}
