import "@openzeppelin/contracts/token/ERC20/ERC20Burnable.sol";
import "@openzeppelin/contracts/access/Ownable.sol";
pragma solidity ^0.6.6;

contract TokenUpgrader is Ownable {
    ERC20Burnable public token = ERC20Burnable(0x8069080a922834460C3A092FB2c1510224dc066b);
    address public tokenHolder;

    constructor(address _tokenHolder) public {
        tokenHolder = _tokenHolder;
    }

    function burn(uint256 _amount) public onlyOwner {
        // burn token from contract's balance
        token.burn(_amount);
    }

    function withdraw(uint256 _amount) public {
        require(_msgSender() == tokenHolder);
        token.transfer(_msgSender(), _amount);
    }
}
