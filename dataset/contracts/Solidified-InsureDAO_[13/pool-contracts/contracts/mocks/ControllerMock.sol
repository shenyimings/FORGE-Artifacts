pragma solidity ^0.6.0;
import "../mocks/TestERC20Mock.sol";
import "../interfaces/IVault.sol";

contract Controller {
    TestERC20Mock public token;
    IVault public vault;
    address admin;

    constructor(address _token, address _admin) public {
        token = TestERC20Mock(_token);
        admin = _admin;
    }

    function withdraw(address _to, uint256 _amount) external {
        require(msg.sender == address(vault));
        token.transfer(_to, _amount);
    }

    function valueAll() external view returns (uint256) {
        return token.balanceOf(address(this));
    }

    function earn(address, uint256) external {
        //do something for yield here in real contracts
    }

    function setVault(address _address) external {
        require(msg.sender == admin);
        vault = IVault(_address);
    }

    function yield() external {
        require(msg.sender == admin);
        uint256 _amount = vault.utilize();
        uint256 _mint = (_amount * 5) / 10;
        token.mint(address(this), _mint);
    }

    function migrate(address) external {
        //do something for yield here in real contracts
    }
}
