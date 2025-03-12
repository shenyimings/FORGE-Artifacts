// SPDX-License-Identifier: MIT

pragma solidity >=0.8.0;

import "@openzeppelin/contracts/token/ERC20/extensions/ERC20Burnable.sol";
import "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";

interface IMinterDAO {
    function isMinter(address account, address token) external view returns (bool);
}

contract CrosschainERC20V2 is ERC20Burnable {
    using SafeERC20 for IERC20;

    uint8 private decimals_;
    IMinterDAO public minterDAO;

    constructor(
        address _minterDAO,
        string memory _name,
        string memory _symbol,
        uint8 _decimals
    ) ERC20(_name, _symbol) {
        minterDAO = IMinterDAO(_minterDAO);
        decimals_  = _decimals;
    }

    function decimals() public view virtual override returns (uint8) {
        return decimals_;
    }

    function mint(address _to, uint256 _amount) public returns (bool) {
        require(minterDAO.isMinter(msg.sender, address(this)), "not the minter");
        require(_amount != 0, "amount is 0");
        _mint(_to, _amount);
        return true;
    }
}
